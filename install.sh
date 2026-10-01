#!/usr/bin/env bash
# install.sh — OpenCode Forge installer for Linux and macOS (Intel + Apple Silicon).
# Reliable bootstrap: detect -> install (if missing) -> verify -> next step.
# A step counts only if its verification passes. Idempotent (backup first).
# Usage: ./install.sh [--profile NAME] [--yes] [--no-models] [--check] [--repair] [--dry-run] [--help]
set -uo pipefail

FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE=""; YES=0; NO_MODELS=0; CHECK=0; REPAIR=0; DRY_RUN=0
STATE_HOME="$HOME/.opencode-forge"
CONFIG_DIR="$HOME/.config/opencode"
OV_DIR="$HOME/.openviking"
STEP_I=0; STEP_N=0; STEP_FAIL=0
declare -a STEP_NAMES=() STEP_STATUS=()

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] $*"; else "$@"; fi; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]
  --profile NAME   minimal|recommended|minecraft|gamedev|complete|custom (default: ask)
  --yes            skip confirmation prompt (plan is still displayed)
  --no-models      skip Ollama model downloads (CI friendly)
  --check          verify only, change nothing (exit 0 if healthy)
  --repair         verify, fix only broken/missing components, retest
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
    --repair) REPAIR=1; shift;;
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

# --- step framework: a step passes ONLY if its verification passes ---
step_begin() { STEP_I=$((STEP_I + 1)); log ""; log "[$STEP_I/$STEP_N] $1"; }
step_pass() { log "  test: PASS"; STEP_NAMES+=("$1"); STEP_STATUS+=("PASS"); }
step_fail() { log "  test: FAIL -- $2"; STEP_NAMES+=("$1"); STEP_STATUS+=("FAIL"); STEP_FAIL=1; }
step_skip() { log "  skipped (not in profile scope)"; STEP_NAMES+=("$1"); STEP_STATUS+=("SKIP"); }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  if [ "$STEP_N" -gt 0 ] && [ "$STEP_FAIL" -eq 0 ]; then STEP_FAIL=1; print_summary >/dev/null 2>&1 || true; fi
  exit 1
}
print_summary() {
  log ""; log "================================"
  log "OpenCode Forge Installation"; log "================================"
  local i
  for i in "${!STEP_NAMES[@]}"; do printf '%-16s %s\n' "${STEP_NAMES[$i]}" "${STEP_STATUS[$i]}"; done
  if [ "$STEP_FAIL" -eq 0 ]; then log ""; log "Result: SUCCESS"; return 0
  else log ""; log "Result: FAILURE (see FAIL rows above)"; return 1; fi
}

refresh_path() {
  for d in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.opencode/bin" /opt/homebrew/bin /usr/local/bin; do
    if [ -d "$d" ]; then case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH"; log "  path+: $d";; esac; fi
  done
  hash -r 2>/dev/null || true
}

# verify a command: exists + runs + exit 0 + prints something
verify_cmd() {
  local name="$1"; shift
  local out
  if ! have "$name"; then log "  detected: no"; return 1; fi
  out="$("$name" "$@" 2>/dev/null | head -n1)" || return 1
  [ -n "$out" ] || return 1
  log "  detected: yes"; log "  version: $out"; return 0
}
verify_git()    { verify_cmd git --version; }
verify_node()   { verify_cmd node --version; }
verify_npm()    { verify_cmd npm --version; }
verify_opencode() { verify_cmd opencode --version; }
verify_ollama() { verify_cmd ollama --version && ollama list >/dev/null 2>&1; }
verify_uv()     { verify_cmd uv --version; }
verify_tsx()    { verify_cmd tsx --version; }
verify_python() { verify_cmd python3 --version; }

install_git_sh() {
  if verify_git >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"; log "  installing..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install git"; return 0; fi
  case "$PM" in
    brew) "$BREW" install git;;
    apt) if need_sudo; then sudo apt-get update && sudo apt-get install -y git; else apt-get update && apt-get install -y git; fi;;
    dnf) if need_sudo; then sudo dnf install -y git; else dnf install -y git; fi;;
    pacman) if need_sudo; then sudo pacman -Sy --noconfirm git; else pacman -Sy --noconfirm git; fi;;
    *) die "Git missing and no package manager. macOS: install Homebrew (https://brew.sh) or Xcode tools (xcode-select --install). Linux: install git with your distro package manager, then re-run.";;
  esac
  refresh_path; verify_git || die "Git install reported success but 'git --version' still fails. Install git manually, then re-run."
}

install_brew() {
  [ "$OS" = "macos" ] || return 1
  log "  Homebrew missing, installing (official script, may ask for sudo once)..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install homebrew"; return 0; fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ "$ARCH" = "arm64" ] && [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew; fi
  refresh_path; PM="brew"
  have brew || die "Homebrew install did not produce a working 'brew'. Install from https://brew.sh, then re-run."
}

install_node() {
  if verify_node >/dev/null 2>&1 && verify_npm >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"; log "  installing..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install nodejs"; return 0; fi
  case "$PM" in
    brew) "$BREW" install node;;
    apt) if need_sudo; then sudo apt-get update && sudo apt-get install -y nodejs npm; else apt-get update && apt-get install -y nodejs npm; fi;;
    dnf) if need_sudo; then sudo dnf install -y nodejs npm; else dnf install -y nodejs npm; fi;;
    pacman) if need_sudo; then sudo pacman -Sy --noconfirm nodejs npm; else pacman -Sy --noconfirm nodejs npm; fi;;
    *) die "Node.js missing and no package manager found. Install Node 20+ from https://nodejs.org then re-run.";;
  esac
  refresh_path
  (verify_node && verify_npm) || die "Node.js install reported success but 'node --version' still fails. Install Node 20+ manually, then re-run."
}

install_opencode() {
  if verify_opencode >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install opencode (curl official)"; return 0; fi
  log "  installing... (official curl installer: https://opencode.ai/v2/install)"
  if curl -fsSL https://opencode.ai/v2/install | bash; then
    refresh_path
    verify_opencode >/dev/null 2>&1 && { log "  installed: yes (curl)"; return 0; }
    log "  curl installer did not yield a working binary, trying next method..."
  fi
  if [ "$PM" = "brew" ]; then
    log "  installing... (brew official tap: anomalyco/tap/opencode-v2)"
    if "$BREW" install anomalyco/tap/opencode-v2; then
      refresh_path
      verify_opencode >/dev/null 2>&1 && { log "  installed: yes (brew)"; return 0; }
    fi
  fi
  log "  installing... (npm @opencode/cli, needs Node)"
  install_node
  if npm install -g @opencode/cli; then
    refresh_path
    verify_opencode >/dev/null 2>&1 && { log "  installed: yes (npm)"; return 0; }
  fi
  die "OpenCode install failed via curl, brew and npm. See https://opencode.ai, install manually, then re-run."
}

install_ollama() {
  if verify_ollama >/dev/null 2>&1; then log "  detected: yes (+ service)"; return 0; fi
  if have ollama; then log "  detected: yes (binary), checking service...";
  else
    log "  detected: no"; log "  installing..."
    if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install ollama"; return 0; fi
    if [ "$OS" = "macos" ]; then
      [ -n "$PM" ] || die "Ollama missing and no Homebrew. Install from https://ollama.com then re-run."
      "$BREW" install ollama || die "brew install ollama failed."
    else
      curl -fsSL https://ollama.com/install.sh | sh || die "Ollama installer script failed."
    fi
    refresh_path
  fi
  verify_cmd ollama --version >/dev/null || die "Ollama installed but 'ollama --version' fails."
  log "  installed: yes"
  if ollama list >/dev/null 2>&1; then log "  service: running"; return 0; fi
  log "  service: starting..."
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] start ollama service"; return 0; fi
  if [ "$OS" = "macos" ] && [ -n "$PM" ]; then "$BREW" services start ollama 2>/dev/null || true; fi
  if ! ollama list >/dev/null 2>&1; then
    nohup ollama serve >/tmp/ollama.log 2>&1 &
    local i; for i in $(seq 1 15); do sleep 2; ollama list >/dev/null 2>&1 && break; done
  fi
  ollama list >/dev/null 2>&1 || die "Ollama installed but the service does not answer ('ollama list' fails). Start it manually, then re-run."
  log "  service: running"
}

install_uv() {
  if verify_uv >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"; log "  installing... (official Astral installer: https://astral.sh/uv/install.sh)"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install uv"; return 0; fi
  if [ "$PM" = "brew" ]; then
    if "$BREW" install uv; then
      refresh_path
      verify_uv >/dev/null 2>&1 && { log "  installed: yes (brew)"; return 0; }
    fi
    log "  brew install uv failed, trying official curl installer..."
  fi
  curl -LsSf https://astral.sh/uv/install.sh | sh || true
  refresh_path
  verify_uv || die "uv install did not produce a working 'uv'. Install from https://docs.astral.sh/uv/, ensure \$HOME/.local/bin is on PATH, then re-run."
  log "  installed: yes"
}

install_python_sh() {
  if verify_python >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"; log "  installing... (python3)"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install python3"; return 0; fi
  case "$PM" in
    brew) "$BREW" install python3;;
    apt) if need_sudo; then sudo apt-get update && sudo apt-get install -y python3; else apt-get update && apt-get install -y python3; fi;;
    dnf) if need_sudo; then sudo dnf install -y python3; else dnf install -y python3; fi;;
    pacman) if need_sudo; then sudo pacman -Sy --noconfirm python; else pacman -Sy --noconfirm python; fi;;
    *) die "Python3 missing and no package manager found. Install Python 3.10+ from https://www.python.org then re-run.";;
  esac
  refresh_path
  verify_python || die "Python3 install reported success but 'python3 --version' still fails."
  log "  installed: yes"
}

install_tsx() {
  if verify_tsx >/dev/null 2>&1; then log "  detected: yes"; return 0; fi
  log "  detected: no"; log "  installing... (npm tsx)"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] npm install -g tsx"; return 0; fi
  install_node
  npm install -g tsx || die "npm install -g tsx failed."
  refresh_path
  verify_tsx || die "tsx installed but 'tsx --version' fails."
  log "  installed: yes"
}

# run a command with a portable timeout (no GNU timeout on macOS)
run_with_timeout() {
  local secs="$1"; shift
  "$@" >/tmp/forge-out.log 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local code=$?
  kill "$watcher" 2>/dev/null
  return $code
}

install_memory() {
  if have openviking-server; then log "  detected: yes (openviking-server)"; return 0; fi
  log "  detected: no"; log "  installing... (uv tool install openviking)"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] uv tool install openviking"; return 0; fi
  install_uv
  uv tool install openviking || die "uv tool install openviking failed."
  refresh_path
  have openviking-server || die "OpenViking installed but 'openviking-server' not on PATH."
  log "  installed: yes"
}

verify_memory() {
  [ -f "$OV_DIR/ov.conf" ] || { log "  config: missing ($OV_DIR/ov.conf)"; return 1; }
  log "  config: present"
  have openviking-server || { log "  server binary: missing"; return 1; }
  if curl -sf --max-time 5 http://127.0.0.1:1933/health >/dev/null 2>&1; then
    log "  server: already running"; log "  health: ok"; return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] start + healthcheck memory server"; return 0; fi
  log "  server: starting test instance..."
  nohup openviking-server --config "$OV_DIR/ov.conf" >/tmp/openviking-test.log 2>&1 &
  local i ok=0
  for i in $(seq 1 30); do
    sleep 2
    if curl -sf --max-time 3 http://127.0.0.1:1933/health >/dev/null 2>&1; then ok=1; break; fi
  done
  if [ "$ok" -eq 1 ]; then log "  health: ok (test instance left running)"; return 0; fi
  return 1
}

install_models() {
  local m present
  for m in "$EMBED" "$MEM"; do
    if ollama list 2>/dev/null | grep -q "$m"; then log "  model present: $m"; present=1
    else
      present=0
      if [ "$NO_MODELS" -eq 1 ]; then log "  model skipped (--no-models): $m"; continue; fi
      if [ "$YES" -eq 0 ]; then
        printf 'Download model %s? (yes/no): ' "$m"; read -r a
        [ "$a" = "yes" ] || { log "  model skipped: $m"; continue; }
      fi
      log "  pulling $m (large download, confirmed)..."
      if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] ollama pull $m"; continue; fi
      ollama pull "$m" || die "ollama pull $m failed."
      ollama list 2>/dev/null | grep -q "$m" || die "ollama pull $m reported success but '$m' is not in 'ollama list'."
      log "  model downloaded + listed: $m"
    fi
  done
}

verify_models() {
  local m fail=0
  for m in "$EMBED" "$MEM"; do
    ollama list 2>/dev/null | grep -q "$m" || { log "  model missing: $m"; fail=1; continue; }
    log "  model listed: $m"
  done
  [ "$fail" -eq 0 ] || return 1
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] inference smoke test"; return 0; fi
  log "  inference smoke test ($MEM)..."
  if run_with_timeout 240 ollama run "$MEM" "Reply with exactly: OK"; then
    if grep -q . /tmp/forge-out.log 2>/dev/null; then
      log "  inference: ok ($(head -c 80 /tmp/forge-out.log))"
      return 0
    fi
  fi
  log "  inference: no usable response"; return 1
}

validate_config() {
  local fail=0
  if have python3; then
    python3 - "$CONFIG_DIR/opencode.jsonc" <<'EOF' 2>/dev/null || fail=1
import json, re, sys
t = open(sys.argv[1]).read()
t = re.sub(r'(?m)^\s*//.*$', '', t)
json.loads(t)
EOF
    [ "$fail" -eq 0 ] && log "  opencode.jsonc: valid JSON" || { log "  opencode.jsonc: INVALID"; return 1; }
    python3 - "$OV_DIR/ov.conf" <<'EOF' 2>/dev/null || { log "  ov.conf: INVALID"; return 1; }
import json, sys
json.load(open(sys.argv[1]))
EOF
    log "  ov.conf: valid JSON"
  else
    [ -f "$CONFIG_DIR/opencode.jsonc" ] || { log "  opencode.jsonc: missing"; return 1; }
    log "  config files present (python3 missing, deep validation skipped)"
  fi
  local f
  for f in "$CONFIG_DIR"/commands/discuss.md "$CONFIG_DIR"/commands/plan.md "$CONFIG_DIR"/skills/project-thinking/SKILL.md; do
    [ -f "$f" ] || { log "  referenced file missing: $f"; fail=1; }
  done
  [ "$fail" -eq 0 ] || return 1
  log "  referenced files: present"
  return 0
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
  log "=== OpenCode Forge — check ($OS/$ARCH) ==="
  local fails=0
  ck() {
    local label="$1" state="$2" hint="$3"
    printf '%-14s %s\n' "$label" "$state"
    [ "$state" = "FAIL" ] && { log "  -> $hint"; fails=1; }
    [ "$state" = "MISSING" ] && { fails=1; }
  }
  if verify_git >/dev/null 2>&1; then ck "Git" "PASS" ""; else
    if have git; then ck "Git" "FAIL" "git exists but 'git --version' fails"; else ck "Git" "MISSING" "run ./install.sh"; fi; fi
  if verify_python >/dev/null 2>&1; then ck "Python" "PASS" ""; else
    if have python3; then ck "Python" "FAIL" "python3 exists but fails"; else ck "Python" "MISSING" "run ./install.sh"; fi; fi
  if verify_node >/dev/null 2>&1; then ck "Node" "PASS" ""; else
    if have node; then ck "Node" "FAIL" "node exists but fails"; else ck "Node" "MISSING" "run ./install.sh"; fi; fi
  if verify_opencode >/dev/null 2>&1; then ck "OpenCode" "PASS" ""; else
    if have opencode; then ck "OpenCode" "FAIL" "opencode exists but fails"; else ck "OpenCode" "MISSING" "run ./install.sh"; fi; fi
  if verify_ollama >/dev/null 2>&1; then ck "Ollama" "PASS" ""; else
    if have ollama; then ck "Ollama" "FAIL" "binary present but service/version check fails"; else ck "Ollama" "MISSING" "run ./install.sh"; fi; fi
  if verify_uv >/dev/null 2>&1; then ck "uv" "PASS" ""; else
    if have uv; then ck "uv" "FAIL" "uv exists but fails"; else ck "uv" "MISSING" "run ./install.sh"; fi; fi
  if verify_tsx >/dev/null 2>&1; then ck "tsx" "PASS" ""; else
    if have tsx; then ck "tsx" "FAIL" "tsx exists but fails"; else ck "tsx" "MISSING" "run ./install.sh (only needed for minecraftMcp)"; fi; fi
  if curl -sf --max-time 5 http://127.0.0.1:1933/health >/dev/null 2>&1; then ck "Memory" "PASS" ""; else ck "Memory" "FAIL" "start: openviking-server --config \$HOME/.openviking/ov.conf"; fi
  if [ -f "$CONFIG_DIR/opencode.jsonc" ]; then ck "Config" "PASS" ""; else ck "Config" "MISSING" "run ./install.sh"; fi
  for m in "$EMBED" "$MEM"; do
    [ -n "$m" ] || continue
    if ollama list 2>/dev/null | grep -q "$m"; then ck "Model $m" "PASS" ""; else ck "Model $m" "MISSING" "run ./install.sh (or --no-models to skip)"; fi
  done
  return $fails
}

# --- repair: verify everything, fix only what is broken, retest ---
run_repair() {
  detect_os; detect_pm
  check_deps; hardware_plan
  log ""; log "=== Repair: verifying, fixing only broken components ==="
  local fixed=0
  verify_git >/dev/null 2>&1 || { log "Git broken/missing -> reinstalling"; install_git_sh && fixed=1; }
  verify_python >/dev/null 2>&1 || { log "Python broken/missing -> reinstalling"; install_python_sh && fixed=1; }
  verify_opencode >/dev/null 2>&1 || { log "OpenCode broken/missing -> reinstalling"; install_opencode && fixed=1; }
  verify_ollama >/dev/null 2>&1 || { log "Ollama broken/missing -> reinstalling"; install_ollama && fixed=1; }
  verify_uv >/dev/null 2>&1 || { log "uv broken/missing -> reinstalling"; install_uv && fixed=1; }
  validate_config >/dev/null 2>&1 || { log "Config invalid/missing -> rewriting from templates"; COMPS="opencode commands"; PROFILE="${PROFILE:-recommended}"; write_config_block && fixed=1; }
  curl -sf --max-time 5 http://127.0.0.1:1933/health >/dev/null 2>&1 || { log "Memory server down -> restarting"; verify_memory && fixed=1; }
  log ""; log "=== Repair: retesting ==="
  STEP_I=0; STEP_N=6; STEP_FAIL=0; STEP_NAMES=(); STEP_STATUS=()
  step_begin "Git"; if verify_git; then step_pass "Git"; else step_fail "Git" "still broken"; fi
  step_begin "Python"; if verify_python; then step_pass "Python"; else step_fail "Python" "still broken"; fi
  step_begin "OpenCode"; if verify_opencode; then step_pass "OpenCode"; else step_fail "OpenCode" "still broken"; fi
  step_begin "Ollama"; if verify_ollama; then step_pass "Ollama"; else step_fail "Ollama" "still broken"; fi
  step_begin "uv"; if verify_uv; then step_pass "uv"; else step_fail "uv" "still broken"; fi
  step_begin "Config"; if validate_config; then step_pass "Config"; else step_fail "Config" "still invalid"; fi
  print_summary
}

# config-file block shared by install and repair
write_config_block() {
  backup "$CONFIG_DIR/opencode.jsonc" "opencode-jsonc"
  backup "$OV_DIR/ov.conf" "ov-conf"
  if [ -f "$CONFIG_DIR/opencode.json" ]; then
    mv "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.json.disabled-$(date +%Y%m%d)"
    log "Legacy opencode.json moved aside (single source: opencode.jsonc)"
  fi
  mkdir -p "$CONFIG_DIR" "$OV_DIR" "$CONFIG_DIR/commands"
  local UVX_BIN TSX_BIN
  UVX_BIN="$(command -v uvx || echo uvx)"; TSX_BIN="$(command -v tsx || echo tsx)"
  sed -e "s|__UVX__|$UVX_BIN|g" -e "s|__TSX__|$TSX_BIN|g" \
    "$FORGE_ROOT/templates/opencode.jsonc" > "$CONFIG_DIR/opencode.jsonc"
  [ -f "$CONFIG_DIR/dcp.jsonc" ] || cp "$FORGE_ROOT/templates/dcp.jsonc" "$CONFIG_DIR/dcp.jsonc"
  sed -e "s|__HOME__|$HOME|g" -e "s|__MEMORY_MODEL__|$MEM|g" \
    "$FORGE_ROOT/templates/openviking/ov.conf.json" > "$OV_DIR/ov.conf"
  cp "$FORGE_ROOT"/commands/*.md "$CONFIG_DIR/commands/"
  log "Config written: $CONFIG_DIR/opencode.jsonc"
  validate_config || die "Config written but validation failed. Previous version is in ~/.opencode-forge/backups/."
}

main() {
  detect_os; detect_pm
  if [ "$CHECK" -eq 1 ]; then check_deps; hardware_plan; do_check; exit $?; fi
  if [ "$REPAIR" -eq 1 ]; then run_repair; exit $?; fi
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
  # brew bootstrap on macOS: without it nothing else can be installed
  if [ "$OS" = "macos" ] && [ -z "$PM" ]; then
    if [ "$YES" -eq 0 ]; then
      printf 'Homebrew is missing. Install it now (official script)? (yes/no): '; read -r ok
      [ "$ok" = "yes" ] || die "Homebrew declined. Install it from https://brew.sh (or install tools manually), then re-run."
    fi
    install_brew
  fi
  NEED_TSX=0
  case " $COMPS " in *" minecraftMcp "*) NEED_TSX=1;; esac
  STEP_N=11
  [ "$NEED_TSX" -eq 1 ] && STEP_N=$((STEP_N + 2))
  STEP_I=0
  run_step() {
    local label="$1"; shift
    step_begin "$label"
    if "$@"; then step_pass "$label"; else step_fail "$label" "see messages above"; exit 1; fi
  }
  run_step "Git" install_git_sh
  run_step "Python" install_python_sh
  if [ "$NEED_TSX" -eq 1 ]; then
    run_step "Node" install_node
    run_step "tsx" install_tsx
  fi
  run_step "OpenCode" install_opencode
  run_step "Ollama" install_ollama
  run_step "uv" install_uv
  run_step "OpenViking" install_memory
  step_begin "Config"
  case " $COMPS " in
    *" opencode "*|*" commands "*)
      if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] write + validate config"; step_pass "Config"
      else write_config_block && step_pass "Config" || { step_fail "Config" "write/validation failed"; exit 1; }; fi
      ;;
    *) step_skip "Config";;
  esac
  step_begin "Skills"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] install skills"; step_pass "Skills"
  else install_skills && step_pass "Skills" || { step_fail "Skills" "install failed"; exit 1; }; fi
  step_begin "Memory"
  if verify_memory; then step_pass "Memory"; else step_fail "Memory" "server not healthy"; exit 1; fi
  step_begin "Models"
  if [ "$DRY_RUN" -eq 1 ]; then log "[dry-run] pull + inference test"; step_pass "Models"
  else
    install_models
    if verify_models; then step_pass "Models"; else step_fail "Models" "model missing or inference failed"; exit 1; fi
  fi
  step_begin "Final"
  if verify_opencode >/dev/null 2>&1; then log "  opencode --version: OK"; step_pass "Final"
  else step_fail "Final" "opencode broken after install"; exit 1; fi
  write_state "$PROFILE" "$COMPS"
  if [ "$DRY_RUN" -eq 0 ]; then log "State saved to ~/.opencode-forge/state.json"; fi
  print_summary
}

install_skills() {
  local SKILLS=""
  case " $COMPS " in *" projectThinking "*) SKILLS="$SKILLS project-thinking";; esac
  case " $COMPS " in *" minecraftSkills "*) SKILLS="$SKILLS minecraft-paper-dev minecraft-fabric-dev minecraft-neoforge-dev minecraft-resourcepack-datapack-dev minecraft-server-debug";; esac
  case " $COMPS " in *" blender "*) SKILLS="$SKILLS blender-game-assets";; esac
  case " $COMPS " in *" unity "*) SKILLS="$SKILLS unity-development";; esac
  case " $COMPS " in *" unreal "*) SKILLS="$SKILLS unreal-development";; esac
  SKILLS="$(printf '%s' "$SKILLS" | xargs)"
  [ -n "$SKILLS" ] || { log "  no skills in profile scope"; return 0; }
  if [ "$DRY_RUN" -eq 0 ]; then
    local s
    for s in $SKILLS; do
      if [ -f "$FORGE_ROOT/skills/$s/SKILL.md" ]; then
        mkdir -p "$CONFIG_DIR/skills/$s"; cp -r "$FORGE_ROOT/skills/$s/." "$CONFIG_DIR/skills/$s/"
      else
        mkdir -p "$CONFIG_DIR/skills/$s"
        [ -f "$CONFIG_DIR/skills/$s/SKILL.md" ] || printf '# %s\n\nStub installed by OpenCode Forge.\n' "$s" > "$CONFIG_DIR/skills/$s/SKILL.md"
      fi
    done
    log "  skills: $SKILLS"
  else log "[dry-run] install skills: $SKILLS"; fi
  for s in $SKILLS; do
    [ -d "$CONFIG_DIR/skills/$s" ] || [ "$DRY_RUN" -eq 1 ] || return 1
  done
  return 0
}

if [ -z "${FORGE_LIB_ONLY:-}" ]; then
  main "$@"
fi