# Contributing

## V1 rules

1. Work inside `projects/OpenCode-Forge/` only.
2. Generic templates only — never copy a personal config value.
3. Dynamic paths only (`$HOME`, `%USERPROFILE%`, `%APPDATA%`).
4. Every script must be idempotent: re-running changes nothing when done.
5. Backup before modifying an existing install (see `modules/Backup.psm1`).
6. Update or add a test in `tests/` with every change:
   `syntax-check.ps1` and `secret-scan.ps1` must pass.
7. Short commit messages, ex: `feat: add doctor check for port 1933`.

## Release process

1. Bump `manifest.json` version + `CHANGELOG.md`.
2. Run both tests, plus `doctor.ps1` on a clean profile if possible.
3. Commit, tag `vX.Y.Z`, push, create the GitHub release with the zip.
4. `bootstrap.ps1` picks the latest stable release automatically.
