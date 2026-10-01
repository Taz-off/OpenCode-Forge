# Models

Selection is data, not code: `hardware/model-rules.json` maps a tier to an
embedding model and a memory model.

- Tier comes from RAM + VRAM (see `modules/Models.psm1`).
- Embedding is always `nomic-embed-text` (dim 768, OpenViking default).
- Memory model: small (low tier) -> `qwen3:8b` (medium) ->
  `qwen3.5:9b` (high / very-high).
- The optional code model (`qwen3-coder:30b`, ~18 GB) is proposed only with
  explicit confirmation, never auto-downloaded.
- The installer always asks before any `ollama pull`.
