#!/usr/bin/env bash
# install.sh — OpenCode Forge installer for Linux and macOS (Intel + Apple Silicon).
# Idempotent: re-running never breaks an existing install (backup first).
# Usage: ./install.sh [--profile NAME] [--yes] [--no-models] [--check] [--dry-run] [--help]
set -uo pipefail

FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=""; YES=0; NO_MODELS=0; CHECK=0; DRY_RUN=0
STATE_HOME="$HOME/.opencode-forge"
CONFIG_DIR="$HOME/.config/opencode"
OV_DIR="$HOME/.openviking"

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] $*"; else "$@"; fi; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]
  --profile NAME   minimal|recommended|minecraft|gamedev|complete|custom (default: ask)
  --yes            skip confirmation prompt (plan is still displayed)
  --no-models      skip Ollama model downloads (CI friendly)
  --check          verify only, change nothing (exit 0 if healthy)
  --dry-run        show what would be done, change nothing
  --help           this message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2;;
    --yes) YES=1; shift;;
    --no-models) NO_MODELS=1; shift;;
    --check) CHECK=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    --help|-h) usage; exit 0;;
    *) die "unknown option: $1 (see --help)";;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  if [ -n "${FORGE_FAKE_OS:-}" ]; then OS="$FORGE_FAKE_OS"; else
  case "$(uname -s)" in
    Linux) OS="linux";;
    Darwin) OS="macos";;
    *) die "unsupported OS: $(uname -s) (Linux and macOS only; Windows uses install.ps1)";;
  esac
  fi
  if [ -n "${FORGE_FAKE_ARCH:-}" ]; then ARCH="$FORGE_FAKE_ARCH"; else
  case "$(uname -m)" in
    x86_64|amd64) ARCH="x86_64";;
    arm64|aarch64) ARCH="arm64";;
    *) ARCH="$(uname -m)"; warn "unusual architecture ${ARCH}, continuing";;
  esac
  fi
}

detect_pm() {
  PM=""
  if [ -n "${FORGE_FAKE_PM:-}" ]; then PM="$FORGE_FAKE_PM"; return 0; fi
  if [ "$OS" = "macos" ]; then
    if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew
    elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew
    elif have brew; then BREW=brew
    else BREW=""
    fi
    [ -n "$BREW" ] && PM="brew"
  else
    if have apt-get; then PM="apt"
    elif have dnf; then PM="dnf"
    elif have pacman; then PM="pacman"
    fi
  fi
}

# --- dependency checks (before installing anything) ---
check_deps() {
  log "=== OpenCode Forge — detection ($OS/$ARCH) ==="
  for t in git node npm opencode ollama python3 uv tsx; do
    if have "$t"; then log "  $t: $($t --version 2>/dev/null | head -n1)"
    else log "  $t: missing"; fi
  done
  if [ "$OS" = "macos" ] && [ -z "$PM" ]; then
    warn "Homebrew not found. Install from https://brew.sh if a dependency is missing,"
    warn "or install tools manually. The script continues with what exists."
  fi
}

need_sudo() { [ "$(id -u)" -ne 0 ] && have sudo; }

install_node() {
  have node && return 0
  log "Installing Node.js (official packages)..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install nodejs"; return 0; fi
  case "$PM" in
    brew) "$BREW" install node;;
    apt) if need_sudo; then sudo apt-get update && sudo apt-get install -y nodejs npm; else apt-get update && apt-get install -y nodejs npm; fi;;
    dnf) if need_sudo; then sudo dnf install -y nodejs npm; else dnf install -y nodejs npm; fi;;
    pacman) if need_sudo; then sudo pacman -Sy --noconfirm nodejs npm; else pacman -Sy --noconfirm nodejs npm; fi;;
    *) die "Node.js missing and no package manager found. Install Node 20+ from https://nodejs.org then re-run.";;
  esac
  have node || die "Node.js install failed. Install Node 20+ manually, then re-run."
}

install_opencode() {
  have opencode && return 0
  install_node
  log "Installing OpenCode (npm, official registry)..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] npm install -g opencode"; return 0; fi
  if [ -w "$(npm root -g 2>/dev/null || echo /nonexistent)" ]; then npm install -g opencode
  elif need_sudo; then sudo npm install -g opencode
  else npm install -g opencode
  fi
  have opencode || die "OpenCode install failed. See https://opencode.ai then re-run."
}

install_ollama() {
  have ollama && return 0
  log "Installing Ollama (official installer)..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install ollama"; return 0; fi
  if [ "$OS" = "macos" ]; then
    [ -n "$PM" ] || die "Ollama missing and no Homebrew. Install from https://ollama.com then re-run."
    "$BREW" install ollama
  else
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  have ollama || die "Ollama install failed. See https://ollama.com then re-run."
}

install_uv() {
  have uv && return 0
  log "Installing uv (official Astral installer)..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install uv"; return 0; fi
  if [ "$OS" = "macos" ] && [ -n "$PM" ]; then "$BREW" install uv
  else curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  have uv || warn "uv not on PATH yet. Add \$HOME/.local/bin to PATH, then re-run for OpenViking."
}

# --- hardware + model plan (shared rule file, python3 preferred) ---
hardware_plan() {
  RAM_GB=0; VRAM_GB=0; CPU=""; GPU=""
  if [ "$OS" = "macos" ]; then
    CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple/Intel Mac")"
    RAM_GB=$(python3 -c "print(round($(sysctl -n hw.memsize 2>/dev/null || echo 0)/1073741824,1))" 2>/dev/null || echo 0)
    GPU="$(system_profiler SPDisplaysDataType 2>/dev/null | grep -m1 'Chipset Model' | cut -d: -f2 | xargs || true)"
  else
    CPU="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo unknown)"
    RAM_GB=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
    if have nvidia-smi; then
      GPU="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)"
      VRAM_GB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | awk '{printf "%.1f", $1/1024}')
    fi
  fi
  RULES="$FORGE_ROOT/hardware/model-rules.json"
  if have python3 && [ -f "$RULES" ]; then
    read -r TIER EMBED MEM CODE < <(python3 - "$RULES" "$RAM_GB" "$VRAM_GB" <<'EOF'
import json, sys
rules = json.load(open(sys.argv[1])); ram = float(sys.argv[2] or 0); vram = float(sys.argv[3] or 0)
tier = rules["tiers"][-1]
for t in rules["tiers"]:
    tier = t
    if ram <= t["when"]["ramGbMax"] and vram <= t["when"]["vramGbMax"]:
        break
print(tier["tier"], rules["embeddingModel"], tier["memoryModel"], tier.get("codeModel") or "-")
EOF
)
  else
    warn "python3 or model-rules.json unavailable, using safe medium defaults"
    TIER=medium; EMBED=nomic-embed-text; MEM="qwen3:8b"; CODE="-"
  fi
  log "CPU: $CPU | RAM: ${RAM_GB}G | GPU: ${GPU:-n/a} | VRAM: ${VRAM_GB}G"
  log "Tier: $TIER (memory $MEM, embedding $EMBED)"
}

profile_components() {
  local f="$FORGE_ROOT/profiles/$1.json"
  [ -f "$f" ] || die "unknown profile: $1"
  local comps=""
  if have python3; then comps="$(python3 - "$f" <<'EOF' 2>/dev/null
import json, sys
print(' '.join(json.load(open(sys.argv[1]))['components']))
EOF
)" || comps=""; fi
  if [ -z "$comps" ]; then comps="$(grep -o '"[a-zA-Z]*"' "$f" | tr -d '"' | tr '\n' ' ')"; fi
  printf '%s' "$comps"
}

backup() {
  [ -e "$1" ] || return 0
  local d="$STATE_HOME/backups/$(date +%Y%m%d-%H%M%S)-$2"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] backup $1 -> $d"; return 0; fi
  mkdir -p "$d"; cp -r "$1" "$d/"; log "Backed up: $1"
}

write_state() {
  local prof="$1" comps="$2"
  if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
  mkdir -p "$STATE_HOME"/logs "$STATE_HOME"/backups
  python3 - "$STATE_HOME/state.json" <<EOF 2>/dev/null || printf '{"version":null,"channel":"stable","profile":"%s","components":[],"models":{},"note":"python3 missing"}\n' "$prof" > "$STATE_HOME/state.json"
import json, sys, datetime
p = sys.argv[1]
try: st = json.load(open(p))
except Exception: st = {}
st.update({"channel": "stable", "profile": "$prof",
           "components": "$comps".split(),
           "models": {"embedding": "$EMBED", "memory": "$MEM", "tier": "$TIER"},
           "lastUpdate": datetime.datetime.now().isoformat(timespec="seconds")})
json.dump(st, open(p, "w"), indent=1)
EOF
}

do_check() {
  local ok=0
  ck() { if eval "$2"; then log "  $1: OK"; else log "  $1: FAIL -- $3"; ok=1; fi; }
  log "=== OpenCode Forge — check ($OS/$ARCH) ==="
  ck "Git" "have git" "install git, then re-open the terminal"
  ck "Node" "have node" "install Node 20+ (brew/apt/dnf/pacman)"
  ck "OpenCode" "have opencode" "run ./install.sh first"
  ck "Ollama" "have ollama" "install from https://ollama.com"
  ck "OpenViking" "curl -sf --max-time 5 http://127.0.0.1:1933/health >/dev/null" "start: openviking-server --config \$HOME/.openviking/ov.conf"
  ck "Config file" "[ -f $CONFIG_DIR/opencode.jsonc ]" "run ./install.sh first"
  ck "DCP" "grep -q opencode-dcp $CONFIG_DIR/opencode.jsonc 2>/dev/null" "re-run install with recommended+"
  ck "Context7" "grep -q context7 $CONFIG_DIR/opencode.jsonc 2>/dev/null" "re-run install with recommended+"
  return $ok
}

main() {
  detect_os; detect_pm
  if [ "$CHECK" -eq 1 ]; then check_deps; do_check; exit $?; fi
  check_deps
  hardware_plan
  if [ -z "$PROFILE" ]; then
    log "Profiles: minimal / recommended / minecraft / gamedev / complete / custom"
    printf 'Profile [recommended]: '; read -r PROFILE
    PROFILE="${PROFILE:-recommended}"; PROFILE="$(printf '%s' "$PROFILE" | tr '[:upper:]' '[:lower:]')"
  fi
  if [ "$PROFILE" = "custom" ]; then
    COMPS=""
    for c in opencode openviking ollama embeddingModel memoryModel dcp plannotator superpowers projectThinking context7 commands; do
      printf 'Include %s? (y/n) [y]: ' "$c"; read -r a; a="${a:-y}"
      case "$a" in y|Y|yes) COMPS="$COMPS $c";; esac
    done
    COMPS="$(printf '%s' "$COMPS" | xargs)"
  else
    COMPS="$(profile_components "$PROFILE")"
  fi
  log ""; log "=== Install plan (confirmation required) ==="
  log "Profile: $PROFILE"; log "Components: $COMPS"; log "Models: embedding=$EMBED memory=$MEM"
  log "Existing configs will be backed up to ~/.opencode-forge/backups."
  if [ "$YES" -eq 0 ]; then
    printf 'Proceed? (yes/no): '; read -r ok
    [ "$ok" = "yes" ] || { log "Aborted. Nothing changed."; exit 0; }
  fi
  case " $COMPS " in
    *" opencode "*)
      install_opencode
      ;;
  esac
  case " $COMPS " in
    *" openviking "*)
      if ! have openviking-server; then
        install_uv
        if have uv; then
          log "Installing OpenViking (uv tool, isolated)..."
          if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] uv tool install openviking"
          else uv tool install openviking || warn "OpenViking install failed; continuing without memory server."; fi
        else warn "uv unavailable; skipping OpenViking install."; fi
      else log "openviking-server present."; fi
      ;;
  esac
  case " $COMPS " in
    *" opencode "*|*" commands "*)
      backup "$CONFIG_DIR/opencode.jsonc" "opencode-jsonc"
      backup "$OV_DIR/ov.conf" "ov-conf"
      if [ -f "$CONFIG_DIR/opencode.json" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] move legacy opencode.json aside"
        else mv "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.json.disabled-$(date +%Y%m%d)"; fi
        log "Legacy opencode.json moved aside (single source: opencode.jsonc)"
      fi
      if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$CONFIG_DIR" "$OV_DIR" "$CONFIG_DIR/commands"
        UVX_BIN="$(command -v uvx || echo uvx)"; TSX_BIN="$(command -v tsx || echo tsx)"
        sed -e "s|__UVX__|$UVX_BIN|g" -e "s|__TSX__|$TSX_BIN|g" \
          "$FORGE_ROOT/templates/opencode.jsonc" > "$CONFIG_DIR/opencode.jsonc"
        [ -f "$CONFIG_DIR/dcp.jsonc" ] || cp "$FORGE_ROOT/templates/dcp.jsonc" "$CONFIG_DIR/dcp.jsonc"
        sed -e "s|__HOME__|$HOME|g" -e "s|__MEMORY_MODEL__|$MEM|g" \
          "$FORGE_ROOT/templates/openviking/ov.conf.json" > "$OV_DIR/ov.conf"
        cp "$FORGE_ROOT"/commands/*.md "$CONFIG_DIR/commands/"
        log "Config written: $CONFIG_DIR/opencode.jsonc"
      else
        log "[dry-run] write opencode.jsonc, dcp.jsonc, ov.conf, commands"
      fi
      ;;
  esac
  SKILLS=""
  case " $COMPS " in *" projectThinking "*) SKILLS="$SKILLS project-thinking";; esac
  case " $COMPS " in *" minecraftSkills "*) SKILLS="$SKILLS minecraft-paper-dev minecraft-fabric-dev minecraft-neoforge-dev minecraft-resourcepack-datapack-dev minecraft-server-debug";; esac
  case " $COMPS " in *" blender "*) SKILLS="$SKILLS blender-game-assets";; esac
  case " $COMPS " in *" unity "*) SKILLS="$SKILLS unity-development";; esac
  case " $COMPS " in *" unreal "*) SKILLS="$SKILLS unreal-development";; esac
  SKILLS="$(printf '%s' "$SKILLS" | xargs)"
  if [ -n "$SKILLS" ]; then
    if [ "$DRY_RUN" -eq 0 ]; then
      for s in $SKILLS; do
        if [ -f "$FORGE_ROOT/skills/$s/SKILL.md" ]; then
          mkdir -p "$CONFIG_DIR/skills/$s"; cp -r "$FORGE_ROOT/skills/$s/." "$CONFIG_DIR/skills/$s/"
        else
          mkdir -p "$CONFIG_DIR/skills/$s"
          [ -f "$CONFIG_DIR/skills/$s/SKILL.md" ] || printf '# %s\n\nStub installed by OpenCode Forge.\n' "$s" > "$CONFIG_DIR/skills/$s/SKILL.md"
        fi
      done
      log "Skills: $SKILLS"
    else log "[dry-run] install skills: $SKILLS"; fi
  fi
  case " $COMPS " in
    *" ollama "*|*" embeddingModel "*|*" memoryModel "*)
      install_ollama
      if [ "$NO_MODELS" -eq 1 ]; then
        log "Model downloads skipped (--no-models). Re-run without it to pull Ollama models."
      else
        for m in "$EMBED" "$MEM"; do
          if ollama list 2>/dev/null | grep -q "$m"; then log "Model present: $m"
          else
            printf 'Download model %s? (yes/no): ' "$m"; read -r a
            if [ "$a" = "yes" ]; then
              if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] ollama pull $m"; else ollama pull "$m"; fi
            else log "Skipped: $m"; fi
          fi
        done
      fi
      ;;
  esac
  write_state "$PROFILE" "$COMPS"
  if [ "$DRY_RUN" -eq 0 ]; then log "Done. State saved to ~/.opencode-forge/state.json"
  else log "[dry-run] state not written"; fi
  log "Verify with ./install.sh --check, then start OpenCode."
}

main "$@"