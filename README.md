# Hermes Agent — Portable & Cross-Platform

Run a fully self-contained Hermes Agent from a single folder or USB drive. No global install, no host pollution — all configs, conversations, memories, and skills stay inside the folder.

## Features

- **Zero host dependencies** — Python, Node.js, uv, and ripgrep are downloaded locally; nothing is required pre-installed.
- **100% portable** — copy the folder to a USB drive or SSD and run it on any Windows, macOS, or Linux machine.
- **Self-updating** — each launch checks for the newest Hermes Agent commit and updates in place; offline-safe and non-blocking.
- **Verified runtimes** — every downloaded runtime binary is checked against a known SHA256 before use.
- **Private & isolated** — API keys, sessions, memory, and skills live only inside the folder.

## Quick Start

First run downloads ~600 MB of runtime files.

**Windows 11** — double-click `launch.bat` (a thin shim that hands off to the PowerShell launcher `launch.ps1`). You can also run `launch.ps1` directly.

**macOS & Linux**
```bash
chmod +x launch.sh
./launch.sh
```
On macOS, rename `launch.sh` to `launch.command` for Finder double-click support.

## How It Works

- The launcher sets `HERMES_HOME` to the local `data/` folder, so config and data never touch `~/.hermes`.
- Portable runtimes download into `.cache/runtimes/<platform>` and are prepended to `PATH`; each is SHA256-verified before use.
- On every launch it checks GitHub for the latest `main` commit and, if newer, downloads it and refreshes dependencies. Offline or on error it keeps the current version and never blocks startup.
- No registry, environment, or host packages are modified.

## Directory Structure

```text
hermes-portable/
├── launch.ps1              # Windows launcher (PowerShell)
├── launch.bat              # Windows shim → launch.ps1
├── launch.sh               # macOS & Linux launcher
├── scripts/
│   ├── setup-windows.ps1   # Windows first-run setup
│   ├── setup-unix.sh       # macOS/Linux first-run setup
│   ├── lib-portable.sh     # Shared helpers (hashing, checksum, update check)
│   ├── reset-windows.ps1   # Reset to a clean state
│   └── reset-unix.sh
├── data/                   # ⚠️ BACKUP THIS — your private files
│   ├── .env                # API keys
│   ├── config.yaml         # Provider/model settings
│   ├── sessions/           # Chat history
│   ├── memories/           # Persistent memory
│   └── skills/             # Custom skills
├── src/hermes-agent/       # Downloaded Hermes Agent source
└── .cache/runtimes/        # Per-platform portable interpreters
```

## Profiles

Run separate agents (e.g. dev / project-manager / test) from one folder via menu
`[4] Profiles` — switch, create, rename, delete, export, import. Each profile has
its own config, keys, sessions, memory, and skills under `data/profiles/<name>`;
the active one is shown on the status panel and remembered in `data/.active-profile`.

## API Keys

Out of the box, a fresh install defaults to a free Nous model (`openrouter/owl-alpha`), so you can start chatting without a key. Paid models and other providers need credits or your own key.

Edit `data/.env`:
```env
OPENROUTER_API_KEY=...
OPENAI_API_KEY=...
ANTHROPIC_API_KEY=...
```
Or use menu option **[2] Setup / Reconfigure** to configure providers interactively.

## Supported Platforms

| OS | Architecture |
| :--- | :--- |
| Windows 11 | x86_64 |
| macOS 13+ | Apple Silicon (ARM64) / Intel (x86_64) |
| Linux | x86_64 / ARM64 |

## Footprint

Per-platform runtime is ~600–900 MB (Python, Node, uv, caches); the source is ~50 MB. Running the folder across multiple operating systems stores a separate runtime per platform, so the `.cache/runtimes/` total grows accordingly (~1.8 GB for Windows + macOS).

## Updating

Updates apply automatically on each launch. To update manually: menu **[5] Advanced → [5] Update Hermes**, run `hermes update` in a chat, or delete `.cache/runtimes/<platform>` and `src/hermes-agent` to rebuild from scratch.

## Security

`data/.env` holds raw API keys and `data/sessions/` holds your conversations — anyone with the drive can read them. Encrypt the drive (BitLocker, FileVault, or VeraCrypt) and avoid carrying production keys.

## Troubleshooting

- **Setup fails / times out** — check your connection (~600 MB download); some corporate firewalls block GitHub or Node CDNs; delete `.cache/` and relaunch.
- **macOS "developer cannot be verified"** — open via right-click → Open With → Terminal, or run `xattr -dr com.apple.quarantine /path/to/hermes-portable`.
- **Windows Defender / SmartScreen warning** — false positive from scripts downloading files; click "More info" → "Run anyway". Scripts are readable under `scripts/`.
- **Slow from a flash drive** — use a USB 3.0+ drive or external SSD.
- **Browser/Playwright tools fail** — some systems block browsers running from removable media; copy the folder to a local SSD.

## Credits

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by [Nous Research](https://github.com/NousResearch)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone), [uv](https://github.com/astral-sh/uv)
