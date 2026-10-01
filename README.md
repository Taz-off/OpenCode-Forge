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

- Windows 10/11 (build 19041+)
- PowerShell 5.1 or 7.x
- Node.js 20+ (for OpenCode)
- Internet for the first install

## Install (one command)

```powershell
irm https://github.com/Taz-off/OpenCode-Forge/releases/latest/download/bootstrap.ps1 | iex
```

Local install instead:

```powershell
.\installer\install.ps1
```

The installer detects your PC, shows CPU / RAM / GPU / VRAM / disk /
available tools, proposes a profile, shows the full plan and asks for
confirmation. No big download happens without your `yes`.

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

```powershell
.\installer\install.ps1    # (re-)install, idempotent
.\installer\update.ps1     # update from remote manifest
.\installer\configure.ps1  # refresh config from templates
.\installer\doctor.ps1     # health checks
.\installer\repair.ps1     # repair + verify
.\installer\rollback.ps1   # restore newest backup
```

Planned command name (rename-friendly, see `manifest.json` → `commandName`):
`opencode-forge install | update | configure | status | doctor | repair | rollback`.

## Update

`update.ps1` fetches the remote manifest, compares versions, backs up your
config, applies only what changed, then updates `~/.opencode-forge/state.json`.
It never reinstalls everything.

## Doctor

Checks OpenCode, Git, GitHub CLI, Ollama, OpenViking, port 1933, config file,
DCP and Context7 — with one short hint per failure.

## Uninstall

1. Delete the config: `$env:USERPROFILE\.config\opencode\opencode.jsonc`
   (a timestamped backup is already in `~/.opencode-forge/backups/`).
2. Delete state: `$env:USERPROFILE\.opencode-forge\`.
3. Optionally `ollama rm <model>` for downloaded models.

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

- `doctor.ps1` first, it tells you what to do.
- OpenViking down? `openviking-server --config $env:USERPROFILE/.openviking/ov.conf`,
  OpenCode still starts with a warning.
- `secret-scan.ps1` fails? Stop, fix, never push.
