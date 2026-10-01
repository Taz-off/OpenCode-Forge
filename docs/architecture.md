# Architecture

```
bootstrap.ps1  ->  latest stable release zip  ->  installer/install.ps1
manifest.json  = source of truth (version, channel, components, profiles)
profiles/*.json -> component lists (minimal ... complete, custom = Q&A)
hardware/model-rules.json -> tier (low/medium/high/very-high) + models
modules/*.psm1 -> Hardware, Software, Models, Ollama, OpenViking, OpenCode,
                  Plugins, MCP, Skills, GitHub, State, Backup
templates/ -> single-source opencode.jsonc, dcp.jsonc, ov.conf, env.example
~/.opencode-forge/ -> state.json, settings.json, logs/, backups/
```

Flow: detect hardware + software, pick tier via model-rules, show the full
plan, ask confirmation, install idempotently with backups, save state.
Update compares the remote manifest version, backs up, applies the delta.
Doctor checks each layer with one hint per failure. Rollback restores the
newest backup. OpenViking is single-instance (port 1933 check); if it fails,
OpenCode still starts with a warning.
