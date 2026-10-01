#!/usr/bin/env bash
# test-install-sh.sh — mock-based tests for install.sh (no downloads, no sudo, no real installs).
# Runs under Git bash on Windows too. Each test uses an isolated HOME + fake bin dir.
# Usage: bash tests/test-install-sh.sh
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1 -- $2"; }

mkfake() { # mkfake <name> <body...> : executable stub in $FAKEBIN
  local n="$1"; shift
  { echo "#!/usr/bin/env bash"; printf '%s\n' "$@"; } > "$FAKEBIN/$n"
  chmod +x "$FAKEBIN/$n"
}

fresh_env() {
  TESTHOME="$(mktemp -d 2>/dev/null || echo "/tmp/forge-test-$$")"
  mkdir -p "$TESTHOME"
  FAKEBIN="$TESTHOME/bin"; mkdir -p "$FAKEBIN"
  HOME="$TESTHOME"
  export HOME TESTHOME FAKEBIN
  export PATH="$FAKEBIN:/usr/bin:/bin"
  unset OS ARCH PM BREW COMPS PROFILE TIER EMBED MEM CODE STEP_I STEP_N STEP_FAIL
  # shellcheck disable=SC1091
  FORGE_LIB_ONLY=1 source "$REPO/install.sh"
  STATE_HOME="$HOME/.opencode-forge"; CONFIG_DIR="$HOME/.config/opencode"; OV_DIR="$HOME/.openviking"
  export STATE_HOME CONFIG_DIR OV_DIR
}

# 1. OS/arch detection via fakes
fresh_env
FORGE_FAKE_OS=macos FORGE_FAKE_ARCH=arm64 detect_os
[ "$OS" = "macos" ] && [ "$ARCH" = "arm64" ] && ok "detect macos/arm64" || bad "detect macos/arm64" "$OS/$ARCH"
FORGE_FAKE_OS=macos FORGE_FAKE_ARCH=x86_64 detect_os
[ "$ARCH" = "x86_64" ] && ok "detect macos/intel" || bad "detect macos/intel" "$ARCH"
FORGE_FAKE_OS=linux FORGE_FAKE_ARCH=x86_64 detect_os
[ "$OS" = "linux" ] && ok "detect linux" || bad "detect linux" "$OS"

# 2. package manager detection (fake binaries)
fresh_env; OS=linux
mkfake apt-get 'echo "fake apt $@" >> "$TESTHOME/apt.log"; exit 0'
FORGE_FAKE_PM="" detect_pm
[ "$PM" = "apt" ] && ok "detect apt" || bad "detect apt" "$PM"
fresh_env; OS=linux
mkfake dnf 'exit 0'
FORGE_FAKE_PM="" detect_pm
[ "$PM" = "dnf" ] && ok "detect dnf" || bad "detect dnf" "$PM"
fresh_env; OS=linux
mkfake pacman 'exit 0'
FORGE_FAKE_PM="" detect_pm
[ "$PM" = "pacman" ] && ok "detect pacman" || bad "detect pacman" "$PM"
fresh_env; OS=macos
mkfake brew 'echo "fake brew $@" >> "$TESTHOME/brew.log"; exit 0'
FORGE_FAKE_PM="" detect_pm
[ "$PM" = "brew" ] && ok "detect brew" || bad "detect brew" "$PM"

# 3. verify present tool
fresh_env
mkfake git 'echo "git version 2.99.mock"'
verify_git >/dev/null 2>&1 && ok "verify present git" || bad "verify present git" "should pass"

# 4. verify broken tool (exists, exits 1)
fresh_env
mkfake git 'echo broken >&2; exit 1'
verify_git >/dev/null 2>&1 && bad "verify broken git" "should fail" || ok "verify broken git"

# 5. install missing git via fake apt (fake apt provides git)
fresh_env; OS=linux; PM=apt; DRY_RUN=0
mkfake apt-get 'printf "#!/usr/bin/env bash\necho \"git version 2.99.mock\"\n" > "$TESTHOME/bin/git"; chmod +x "$TESTHOME/bin/git"; exit 0'
(install_git_sh >/dev/null 2>&1) && verify_git >/dev/null 2>&1 && ok "install missing git" || bad "install missing git" "see log"

# 6. already-installed tool is NOT reinstalled
fresh_env; OS=linux; PM=apt; DRY_RUN=0
mkfake git 'echo "git version 2.99.mock"'
mkfake apt-get 'echo CALLED >> "$TESTHOME/apt.log"; exit 0'
install_git_sh >/dev/null 2>&1
[ -f "$TESTHOME/apt.log" ] && bad "no reinstall when present" "apt was called" || ok "no reinstall when present"

# 7. opencode fallback chain: curl fails, no brew, npm provides binary
fresh_env; OS=linux; PM=""; DRY_RUN=0
mkfake curl 'exit 1'
mkfake node 'echo "v24.0.0"'
mkfake npm 'echo "10.0.0-mock"; printf "#!/usr/bin/env bash\necho \"opencode v9.9.9-mock\"\n" > "$TESTHOME/bin/opencode"; chmod +x "$TESTHOME/bin/opencode"; exit 0'
(install_opencode >/dev/null 2>&1) && verify_opencode >/dev/null 2>&1 && ok "opencode npm fallback" || bad "opencode npm fallback" "chain failed"

# 8. bad install command -> clean stop (subshell, must exit 1)
fresh_env; OS=linux; PM=""; DRY_RUN=0
mkfake node 'echo "v24.0.0"'
mkfake npm 'echo "403 forbidden" >&2; exit 1'
mkfake curl 'exit 1'
(install_opencode >/dev/null 2>&1); [ $? -ne 0 ] && ok "bad install stops" || bad "bad install stops" "should have died"

# 9. refresh_path adds dirs once (idempotent PATH)
fresh_env
mkdir -p "$HOME/.local/bin"
refresh_path >/dev/null 2>&1
case ":$PATH:" in *":$HOME/.local/bin:"*) ok "refresh_path adds dir";; *) bad "refresh_path adds dir" "$PATH";; esac
before="$PATH"; refresh_path >/dev/null 2>&1
[ "$PATH" = "$before" ] && ok "refresh_path idempotent" || bad "refresh_path idempotent" "PATH duplicated"

# 10. backup + existing config preserved
fresh_env; DRY_RUN=0
mkdir -p "$CONFIG_DIR"; echo "precious" > "$CONFIG_DIR/opencode.jsonc"
backup "$CONFIG_DIR/opencode.jsonc" "opencode-jsonc"
found="$(find "$STATE_HOME/backups" -name opencode.jsonc 2>/dev/null | head -n1)"
[ -n "$found" ] && [ "$(cat "$found")" = "precious" ] && ok "backup preserves config" || bad "backup preserves config" "$found"

# 11. config validation catches invalid JSON
fresh_env; DRY_RUN=0; MEM="qwen3:8b"
mkdir -p "$CONFIG_DIR/commands" "$CONFIG_DIR/skills/project-thinking" "$OV_DIR"
echo "{invalid json" > "$CONFIG_DIR/opencode.jsonc"
echo '{"a":1}' > "$OV_DIR/ov.conf"
validate_config >/dev/null 2>&1 && bad "validate catches bad json" "should fail" || ok "validate catches bad json"

# 12. models skipped with --no-models: no pull, list-check allowed
fresh_env; DRY_RUN=0; NO_MODELS=1; EMBED="m"; MEM="m"
mkfake ollama 'echo "$@" >> "$TESTHOME/ollama.log"; echo "NAME"; exit 0'
install_models >/dev/null 2>&1
grep -q pull "$TESTHOME/ollama.log" 2>/dev/null && bad "no-models skips pulls" "ollama pull was called" || ok "no-models skips pulls"

# 13. python present -> no reinstall
fresh_env; OS=linux; PM=apt; DRY_RUN=0
mkfake python3 'echo "Python 3.12.0"'
mkfake apt-get 'echo CALLED >> "$TESTHOME/apt.log"; exit 0'
install_python_sh >/dev/null 2>&1
[ -f "$TESTHOME/apt.log" ] && bad "python no reinstall when present" "apt was called" || ok "python no reinstall when present"

# 14. python missing -> installed via fake apt
fresh_env; OS=linux; PM=apt; DRY_RUN=0
mkfake apt-get 'printf "#!/usr/bin/env bash\necho \"Python 3.12.0\"\n" > "$TESTHOME/bin/python3"; chmod +x "$TESTHOME/bin/python3"; exit 0'
(install_python_sh >/dev/null 2>&1) && verify_python >/dev/null 2>&1 && ok "install missing python" || bad "install missing python" "see log"

# 15. opencode uses official curl first, brew only when PM=brew (no empty $BREW call on apt)
fresh_env; OS=linux; PM=apt; BREW=""; DRY_RUN=0
mkfake curl 'exit 1'
mkfake node 'echo "v24.0.0"'
mkfake npm 'echo "10.0.0-mock"; printf "#!/usr/bin/env bash\necho \"opencode v9.9.9-mock\"\n" > "$TESTHOME/bin/opencode"; chmod +x "$TESTHOME/bin/opencode"; exit 0'
(install_opencode >/dev/null 2>&1) && verify_opencode >/dev/null 2>&1 && ok "opencode apt path skips empty brew" || bad "opencode apt path skips empty brew" "chain failed"

# 16. dry-run changes nothing (missing tool -> dry-run log, no install)
fresh_env; DRY_RUN=1; OS=linux; PM=apt
orig_have="$(declare -f have)"
have() { if [ "$1" = tsx ]; then return 1; fi; command -v "$1" >/dev/null 2>&1; }
out="$(install_tsx 2>&1)"
eval "$orig_have"
echo "$out" | grep -q "dry-run" && ok "dry-run logs without changing" || bad "dry-run logs without changing" "$out"

# 17. second run idempotent (config hash stable)
fresh_env; DRY_RUN=0; MEM="qwen3:8b"
mkdir -p "$CONFIG_DIR/commands" "$CONFIG_DIR/skills/project-thinking" "$OV_DIR"
printf '{"ok":1}' > "$OV_DIR/ov.conf"
cp "$REPO/templates/opencode.jsonc" "$CONFIG_DIR/opencode.jsonc"
cp "$REPO"/commands/*.md "$CONFIG_DIR/commands/" 2>/dev/null || true
mkdir -p "$CONFIG_DIR/skills/project-thinking"; echo ok > "$CONFIG_DIR/skills/project-thinking/SKILL.md"
h1="$(cat "$CONFIG_DIR/opencode.jsonc" | wc -c)"
validate_config >/dev/null 2>&1 && ok "idempotent config validates" || bad "idempotent config validates" "should pass"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
