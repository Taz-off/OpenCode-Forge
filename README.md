# OpenCode Forge

One-command installer for a complete local OpenCode environment.

## What it installs

- OpenCode config (single source: `opencode.jsonc`, V2 `plugins` format)
- OpenViking memory server (`127.0.0.1:1933`, local only)
- Ollama + embedding model + memory model adapted to your PC
- Plugins: DCP, Plannotator, Superpowers (+ OpenViking)
- Commands: `/discuss` `/plan` `/build` `/explore`
- Skill: `project-thinking` (+ Minecraft / GameDev per profile)
- Optional MCPs: Context7, Blender, Unity, Minecraft Paper/Fabric

## Requirements

- Windows 11, Linux (apt/dnf/pacman), or macOS Intel / Apple Silicon
- Windows: PowerShell 5.1 or 7.x. Linux/macOS: bash + python3 (for model rules)
- Node.js 20+ (installed automatically if missing and a package manager exists)
- Internet for the first install

## Installation

Clone, then run ONE command for your OS.

Windows PowerShell:

```powershell
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
powershell -ExecutionPolicy Bypass -File .\installer\install.ps1
```

Linux:

```bash
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
chmod +x install.sh
./install.sh
```

macOS (Intel or Apple Silicon, same command):

```bash
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
chmod +x install.sh
./install.sh
```

One-command remote install (stable release):

```powershell
irm https://github.com/Taz-off/OpenCode-Forge/releases/latest/download/bootstrap.ps1 | iex
```

The installer detects your machine (OS, CPU arch, RAM, GPU when visible,
installed tools), proposes a profile, shows the full plan and asks for
confirmation. No big download happens without your `yes`.

Flags (exact):

- Linux/macOS: `./install.sh --profile NAME --yes --no-models --check --repair --dry-run --help`
- Windows: `.\installer\install.ps1 [-Profile NAME] [-Yes] [-NoModels] [-Check] [-Repair] [-DryRun] [-Help]`

`-Yes`/`--yes` skips confirmation (plan still shown). `--no-models`/`-NoModels` skips Ollama pulls (CI friendly). `--check`/`-Check` and `--dry-run`/`-DryRun` change nothing. `--repair`/`-Repair` fixes only broken/missing, then retests.

### Supported systems

| OS | Installer | Arch | Package managers |
|---|---|---|---|
| Windows 11 | `installer/install.ps1` | x86_64 | winget/manual (existing tools reused) |
| Linux | `install.sh` | x86_64, arm64 | apt, dnf, pacman |
| macOS | `install.sh` | Intel, Apple Silicon | Homebrew (`/opt/homebrew` + `/usr/local`) |

### What is installed / configured

- OpenCode (official `curl https://opencode.ai/v2/install`, fallback `brew anomalyco/tap/opencode-v2`, fallback `npm @opencode/cli`, only if missing) + config `opencode.jsonc` (single source)
- Git, Python3, Node.js, uv, tsx (only if missing, via brew/apt/dnf/pacman on Unix, winget on Windows)
- OpenViking memory server config (`~/.openviking/ov.conf`), server on `127.0.0.1:1933` (via `uv tool install openviking`, healthchecked)
- Ollama (official `curl https://ollama.com/install.sh` on Linux, `brew install ollama` on macOS, winget `Ollama.Ollama` on Windows, only if missing) + embedding model + memory model for your tier
- Plugins: DCP, Plannotator, Superpowers (+ OpenViking)
- Commands `/discuss` `/plan` `/build` `/explore`, `project-thinking` skill (+ per profile)
- Optional MCPs: Context7, Blender, Unity, Minecraft Paper/Fabric

You do NOT need to manually install OpenCode, Ollama, uv, memory components, models or plugins. The installer detects missing components and installs them automatically, then verifies each with `*_--version`, service health and inference smoke test before continuing.

### If tools already exist

Existing tools are reused, never reinstalled. An existing `opencode.jsonc`
is backed up to `~/.opencode-forge/backups/` before any change; a stray
`opencode.json` is moved aside (single source rule). Re-running the installer
is safe (idempotent).

### Config location

- Windows: `%USERPROFILE%\.config\opencode` · Linux/macOS: `$HOME/.config/opencode`
- State: `~/.opencode-forge/` (`state.json`, logs, backups)

### Memory (OpenViking)

No permanent system service. Start memory with OpenCode:

- Windows: module `Start-ForgeOpenViking` (single instance via port check)
- Linux/macOS: `./scripts/openviking-run.sh` (starts server, waits `/health`, runs `opencode`)

If the server is down, OpenCode still starts with a warning.

### Update / uninstall

- Update: `installer/update.ps1` (Windows) compares the remote manifest and
  applies only what changed. On Linux/macOS: `git pull` then re-run `./install.sh`.
- Uninstall: delete `~/.config/opencode/opencode.jsonc` (backup kept in
  `~/.opencode-forge/backups/`), delete `~/.opencode-forge/`,
  optionally `ollama rm <model>`.

### Check without changing anything

```powershell
.\installer\install.ps1 -Check   # Windows (also: .\installer\doctor.ps1)
.\installer\install.ps1 -DryRun  # Windows: show what would be done
```

```bash
./install.sh --check             # Linux/macOS (also: --help, --dry-run, --repair, --yes, --no-models)
./install.sh --dry-run --yes     # Linux/macOS: show what would be done
./install.sh --repair            # Linux/macOS: fix only broken/missing, retest
```

This verifies OS, architecture, Git, Python, Node, OpenCode, Ollama, uv, tsx, config,
memory server and models — and changes nothing. Output is `PASS` / `MISSING` / `FAIL` per component.

### Troubleshooting

- `doctor` / `--check` first, it tells you what to do.
- `curl: command not found` (minimal Linux): `sudo apt install curl` (or dnf/pacman equivalent).
- Homebrew missing (macOS): install from https://brew.sh, or install Node/Ollama manually and re-run.
- No package manager found (Linux): install Node 20+, Ollama and uv manually, then re-run (config-only mode still works).
- OpenViking down? `openviking-server --config ~/.openviking/ov.conf`.
- `secret-scan.ps1` fails? Stop, fix, never push.

## Profiles

| Profile | Content |
|---|---|
| `minimal` | OpenCode + OpenViking + Ollama + embedding + memory model |
| `recommended` | minimal + DCP, Plannotator, Superpowers, project-thinking, Context7, 4 commands |
| `minecraft` | recommended + Paper/Fabric/NeoForge/resourcepack skills, server-debug, optional Paper/Fabric MCP |
| `gamedev` | recommended + Blender/Unity/Unreal skills, MCPs only when relevant |
| `complete` | everything (optional MCPs still ask first) |
| `custom` | component by component |

## Commands

After install, from the project folder:

Windows:

```powershell
.\installer\install.ps1    # (re-)install, idempotent
.\installer\update.ps1     # update from remote manifest
.\installer\configure.ps1  # refresh config from templates
.\installer\doctor.ps1     # health checks
.\installer\repair.ps1     # repair + verify
.\installer\rollback.ps1   # restore newest backup
```

Linux/macOS:

```bash
./install.sh               # (re-)install, idempotent
./install.sh --check       # verify, change nothing
./scripts/openviking-run.sh  # memory server + OpenCode
```

Planned command name (rename-friendly, see `manifest.json` → `commandName`):
`opencode-forge install | update | configure | status | doctor | repair | rollback`.

## Update

Windows `update.ps1` fetches the remote manifest, compares versions, backs up
your config, applies only what changed, then updates `~/.opencode-forge/state.json`.
On Linux/macOS: `git pull` + re-run `./install.sh` (idempotent, same result).

## Doctor

Windows `doctor.ps1` (or `install.ps1 -Check`), Unix `./install.sh --check`:
checks OS/arch, Git, Node, OpenCode, Ollama, OpenViking, port 1933, config file,
DCP and Context7 — with one short hint per failure.

## Security

- No token, key, password, `.env` or private IP is ever committed. Only
  `templates/env.example` ships.
- Home Assistant token (if used) goes through the `HOMEASSISTANT_TOKEN`
  environment variable, never in a file.
- All paths are dynamic (`$HOME`, `%USERPROFILE%`, `%APPDATA%`).
- One config source only: `opencode.jsonc`. A stray `opencode.json` is moved
  aside, never merged blindly.
- Backups exclude `node_modules`, model files and caches.
- See `SECURITY.md`. Run `tests/secret-scan.ps1` before every push.

## Contributing

See `CONTRIBUTING.md`. V1 rules: generic templates only, idempotent scripts,
tests with every change, French or English short messages.

## Troubleshooting

- `doctor.ps1` / `./install.sh --check` first, it tells you what to do.
- OpenViking down? `openviking-server --config ~/.openviking/ov.conf`
  (Windows: `$env:USERPROFILE/.openviking/ov.conf`),
  OpenCode still starts with a warning.
- `secret-scan.ps1` fails? Stop, fix, never push.
