---
description: Start or continue a design discussion, no coding.
agent: plan
---

# /discuss

Design discussion only. Do NOT edit, create, or delete code.

- Topic: $ARGUMENTS (if empty, ask one short question).
- Load the `project-thinking` skill method.
- Read `.opencode/project.md` first if present, else README/AGENTS.md.
- One question at a time, max 2-3 options with pros/cons.
- Separate what the user decided from what the AI suggests.
- If stable decisions emerge, propose a short spec but do NOT write files.
- On explicit build request, write the spec then ask for `/build` and stop.
