# Changelog

All notable changes to this project will be documented in this file.
Format: Keep a Changelog. Versioning: SemVer (`0.1.0` first).

## [0.2.0] - 2026-10-01

### Added

- `install.sh`: Linux + macOS installer (Intel + Apple Silicon). OS/arch
  detection, apt/dnf/pacman + Homebrew (both prefixes), official installs
  only when missing, sudo only for package commands, `--check`/`--help`/`--dry-run`.
- `scripts/openviking-run.sh`: start memory server, wait `/health`, run OpenCode.
  No permanent system service on any OS.
- `install.ps1`: `-Check` (doctor) and `-Help` flags.

### Changed

- `OpenCode.psm1`: `uvx`/`tsx` command names adapt to the OS (no `.exe`/`.cmd` on Unix).

## [0.1.0] - 2026-10-01

### Added

- `bootstrap.ps1`: one-command remote entry point (stable release first, `main` fallback with warning).
- `installer/`: `install.ps1` (interactive, plan + confirmation, idempotent),
  `doctor.ps1`, `update.ps1`, `configure.ps1`, `repair.ps1`, `rollback.ps1`.
- `modules/`: Hardware, Software, GitHub, Ollama, OpenViking, OpenCode,
  Models, Plugins, MCP, Skills, State, Backup.
- `profiles/`: minimal, recommended, minecraft, gamedev, complete.
- `hardware/model-rules.json`: data-driven model selection (low / medium / high / very-high).
- `templates/`: single-source `opencode.jsonc`, `dcp.jsonc`, OpenViking `ov.conf`,
  `env.example` (no secrets).
- `commands/`: discuss, plan, build, explore.
- `skills/`: project-thinking method + documented stubs.
- `tests/`: PowerShell syntax check, secret scan.
- Local state in `~/.opencode-forge/` (state.json, settings, logs, backups).
