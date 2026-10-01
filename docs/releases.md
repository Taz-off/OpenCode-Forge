# Releases

- SemVer, starting at `0.1.0`. Version lives in `manifest.json`.
- Channels: `stable` (default), `beta`, `dev` (planned; V1 ships stable only).
- `bootstrap.ps1` reads `releases/latest`, downloads the zip, runs install.
- When releases are live, install must NOT track `main` directly.
- `update.ps1`: fetch remote manifest -> compare versions -> backup configs ->
  apply the delta -> test (doctor) -> save state.
- Tag + GitHub release per version, zip attached for bootstrap.
