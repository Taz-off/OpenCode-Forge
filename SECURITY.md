# Security Policy

## Never committed

- tokens, API keys, Bearer values, passwords
- real `.env` files (only `.env.example` ships)
- private IPs, home-assistant URLs with secrets
- `service.json`, absolute user paths (`C:\Users\...`)
- backups containing any of the above

## Rules

1. Templates only. Real values go in environment variables
   (ex: `HOMEASSISTANT_TOKEN`), never in a file.
2. One config source: `opencode.jsonc`. No second `opencode.json`.
3. Backup before every change to an existing install.
4. No backup of `node_modules`, Ollama models or caches.
5. Run `tests/secret-scan.ps1` before every commit and every push.
   If it fails: STOP, fix first, never push.

## Reporting

Open a GitHub issue with `[security]` in the title, without including any
secret value. Describe the file and the pattern, not the value.
