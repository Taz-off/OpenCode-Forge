# OpenCode Forge

> 🌍 Langue / Language : **Français** (actuel) · **[English](README.md)**
>
> Installateur en une commande pour un environnement OpenCode local complet.
> One-command installer for a complete local OpenCode environment.

## Ce que ça installe

- Config OpenCode (source unique : `opencode.jsonc`, format `plugins` V2)
- Serveur mémoire OpenViking (`127.0.0.1:1933`, local uniquement)
- Ollama + modèle embedding + modèle mémoire adapté à ton PC
- Plugins : DCP, Plannotator, Superpowers (+ OpenViking)
- Commandes : `/discuss` `/plan` `/build` `/explore`
- Skill : `project-thinking` (+ Minecraft / GameDev selon profil)
- MCP optionnels : Context7, Blender, Unity, Minecraft Paper/Fabric

## Prérequis

- Windows 11, Linux (apt/dnf/pacman), ou macOS Intel / Apple Silicon
- Windows : PowerShell 5.1 ou 7.x. Linux/macOS : bash + python3 (pour règles modèles)
- Node.js 20+ (installé automatiquement si absent et gestionnaire présent)
- Internet pour la première installation

## Installation

Clone, puis UNE commande selon ton OS.

Windows PowerShell :

```powershell
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
powershell -ExecutionPolicy Bypass -File .\installer\install.ps1
```

Linux :

```bash
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
chmod +x install.sh
./install.sh
```

macOS (Intel ou Apple Silicon, même commande) :

```bash
git clone https://github.com/Taz-off/OpenCode-Forge.git
cd OpenCode-Forge
chmod +x install.sh
./install.sh
```

Installation distante en une commande (release stable) :

```powershell
irm https://github.com/Taz-off/OpenCode-Forge/releases/latest/download/bootstrap.ps1 | iex
```

L'installateur détecte ta machine (OS, arch CPU, RAM, GPU si visible,
outils installés), propose un profil, montre le plan complet et demande
confirmation. Aucun gros téléchargement sans ton `yes`.

Flags (exact) :

- Linux/macOS : `./install.sh --profile NAME --yes --no-models --check --repair --dry-run --help`
- Windows : `.\installer\install.ps1 [-Profile NAME] [-Yes] [-NoModels] [-Check] [-Repair] [-DryRun] [-Help]`

`-Yes`/`--yes` saute la confirmation (plan toujours affiché). `--no-models`/`-NoModels` saute les pulls Ollama (pratique CI). `--check`/`-Check` et `--dry-run`/`-DryRun` ne changent rien. `--repair`/`-Repair` répare seulement ce qui est cassé/mquant, puis reteste.

### Systèmes supportés

| OS | Installeur | Arch | Gestionnaires |
|---|---|---|---|
| Windows 11 | `installer/install.ps1` | x86_64 | winget/manuel (outils existants réutilisés) |
| Linux | `install.sh` | x86_64, arm64 | apt, dnf, pacman |
| macOS | `install.sh` | Intel, Apple Silicon | Homebrew (`/opt/homebrew` + `/usr/local`) |

### Ce qui est installé / configuré

- OpenCode (officiel `curl https://opencode.ai/v2/install`, fallback `brew anomalyco/tap/opencode-v2`, fallback `npm @opencode/cli`, seulement si absent) + config `opencode.jsonc` (source unique)
- Git, Python3, Node.js, uv, tsx (seulement si absent, via brew/apt/dnf/pacman sur Unix, winget sur Windows)
- Config serveur mémoire OpenViking (`~/.openviking/ov.conf`), serveur sur `127.0.0.1:1933` (via `uv tool install openviking`, healthcheck)
- Ollama (officiel `curl https://ollama.com/install.sh` sur Linux, `brew install ollama` sur macOS, winget `Ollama.Ollama` sur Windows, seulement si absent) + modèle embedding + modèle mémoire selon ton niveau
- Plugins : DCP, Plannotator, Superpowers (+ OpenViking)
- Commandes `/discuss` `/plan` `/build` `/explore`, skill `project-thinking` (+ par profil)
- MCP optionnels : Context7, Blender, Unity, Minecraft Paper/Fabric

Tu n'as PAS besoin d'installer à la main OpenCode, Ollama, uv, mémoire, modèles ou plugins. L'installateur détecte ce qui manque et l'installe automatiquement, puis vérifie chaque élément avec `*--version`, santé service et test inference avant de continuer.

### Si les outils existent déjà

Les outils existants sont réutilisés, jamais réinstallés. Un `opencode.jsonc`
existant est sauvegardé dans `~/.opencode-forge/backups/` avant tout changement ; un
`opencode.json` traînant est mis de côté (règle source unique). Relancer
l'installateur est sans danger (idempotent).

### Emplacement config

- Windows : `%USERPROFILE%\.config\opencode` · Linux/macOS : `$HOME/.config/opencode`
- État : `~/.opencode-forge/` (`state.json`, logs, backups)

### Mémoire (OpenViking)

Pas de service système permanent. Démarre la mémoire avec OpenCode :

- Windows : module `Start-ForgeOpenViking` (instance unique via check port)
- Linux/macOS : `./scripts/openviking-run.sh` (démarre serveur, attend `/health`, lance `opencode`)

Si le serveur est éteint, OpenCode démarre quand même avec un avertissement.

### Mise à jour / désinstallation

- Mise à jour : `installer/update.ps1` (Windows) compare le manifest distant et
  applique seulement ce qui a changé. Sur Linux/macOS : `git pull` puis `./install.sh`.
- Désinstallation : supprime `~/.config/opencode/opencode.jsonc` (backup gardé dans
  `~/.opencode-forge/backups/`), supprime `~/.opencode-forge/`,
  optionnel `ollama rm <modele>`.

### Vérifier sans rien changer

```powershell
.\installer\install.ps1 -Check   # Windows (aussi : .\installer\doctor.ps1)
.\installer\install.ps1 -DryRun  # Windows : montre ce qui serait fait
```

```bash
./install.sh --check             # Linux/macOS (aussi : --help, --dry-run, --repair, --yes, --no-models)
./install.sh --dry-run --yes     # Linux/macOS : montre ce qui serait fait
./install.sh --repair            # Linux/macOS : répare seulement ce qui est cassé, reteste
```

Ça vérifie OS, architecture, Git, Python, Node, OpenCode, Ollama, uv, tsx, config,
serveur mémoire et modèles — et ne change rien. Sortie `PASS` / `MISSING` / `FAIL` par composant.

### Dépannage

- `doctor` / `--check` d'abord, il dit quoi faire.
- `curl: command not found` (Linux minimal) : `sudo apt install curl` (ou équivalent dnf/pacman).
- Homebrew absent (macOS) : installe depuis https://brew.sh, ou installe Node/Ollama à la main puis relance.
- Pas de gestionnaire (Linux) : installe Node 20+, Ollama et uv à la main, puis relance.
- OpenViking éteint ? `openviking-server --config ~/.openviking/ov.conf`.
- `secret-scan.ps1` échoue ? Stop, corrige, jamais push.

## Profils

| Profil | Contenu |
|---|---|
| `minimal` | OpenCode + OpenViking + Ollama + embedding + modèle mémoire |
| `recommended` | minimal + DCP, Plannotator, Superpowers, project-thinking, Context7, 4 commandes |
| `minecraft` | recommended + skills Paper/Fabric/NeoForge/resourcepack, server-debug, MCP Paper/Fabric optionnel |
| `gamedev` | recommended + skills Blender/Unity/Unreal, MCP seulement si pertinent |
| `complete` | tout (MCP optionnels demandent quand même avant) |
| `custom` | composant par composant |

## Commandes

Après install, depuis le dossier projet :

Windows :

```powershell
.\installer\install.ps1    # (ré-)installe, idempotent
.\installer\update.ps1     # met à jour depuis manifest distant
.\installer\configure.ps1  # régénère config depuis templates
.\installer\doctor.ps1     # vérifications santé
.\installer\repair.ps1     # répare + vérifie
.\installer\rollback.ps1   # restaure le backup le plus récent
```

Linux/macOS :

```bash
./install.sh               # (ré-)installe, idempotent
./install.sh --check       # vérifie, ne change rien
./scripts/openviking-run.sh  # serveur mémoire + OpenCode
```

Nom de commande prévu (renommage facile, voir `manifest.json` → `commandName`) :
`opencode-forge install | update | configure | status | doctor | repair | rollback`.

## Mise à jour

Windows `update.ps1` récupère le manifest distant, compare versions, sauvegarde
ta config, applique seulement ce qui a changé, puis met à jour `~/.opencode-forge/state.json`.
Sur Linux/macOS : `git pull` + `./install.sh` (idempotent, même résultat).

## Doctor

Windows `doctor.ps1` (ou `install.ps1 -Check`), Unix `./install.sh --check` :
vérifie OS/arch, Git, Node, OpenCode, Ollama, OpenViking, port 1933, fichier config,
DCP et Context7 — avec une courte aide par échec.

## Sécurité

- Aucun token, clé, mot de passe, `.env` ou IP privée n'est commité. Seul
  `templates/env.example` est fourni.
- Token Home Assistant (si utilisé) passe par la variable d'environnement
  `HOMEASSISTANT_TOKEN`, jamais dans un fichier.
- Tous les chemins sont dynamiques (`$HOME`, `%USERPROFILE%`, `%APPDATA%`).
- Une seule source config : `opencode.jsonc`. Un `opencode.json` traînant est mis
  de côté, jamais fusionné à l'aveugle.
- Backups excluent `node_modules`, fichiers modèles et caches.
- Voir `SECURITY.md`. Lance `tests/secret-scan.ps1` avant chaque push.

## Contribuer

Voir `CONTRIBUTING.md`. Règles V1 : templates génériques uniquement, scripts idempotents,
tests à chaque changement, messages courts français ou anglais.

## Dépannage

- `doctor.ps1` / `./install.sh --check` d'abord, il dit quoi faire.
- OpenViking éteint ? `openviking-server --config ~/.openviking/ov.conf`
  (Windows : `$env:USERPROFILE/.openviking/ov.conf`),
  OpenCode démarre quand même avec un avertissement.
- `secret-scan.ps1` échoue ? Stop, corrige, jamais push.
