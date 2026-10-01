# Skills

Generic skill stubs. The installer copies only the skills required by the chosen profile.

| Skill | Profile | Needs |
|---|---|---|
| `project-thinking` | recommended+ | none (included, full method) |
| `minecraft-paper-dev` | minecraft | Paper server, Java |
| `minecraft-fabric-dev` | minecraft | Fabric, Java |
| `minecraft-neoforge-dev` | minecraft | NeoForge, Java |
| `minecraft-resourcepack-datapack-dev` | minecraft | none |
| `minecraft-server-debug` | minecraft | server access |
| `blender-game-assets` | gamedev | Blender + Blender MCP |
| `unity-development` | gamedev | Unity + KitWright MCP |
| `unreal-development` | gamedev | Unreal Engine 5.8+ MCP |

Each skill is a folder with a `SKILL.md` file.
Only `project-thinking` ships its full content in V1.
Other skills are installed as documented stubs: the installer creates the folder
and a `SKILL.md` header so OpenCode detects them, without copying any
machine-specific content.
