# Hermes Portable

Runs the Hermes Agent from a single folder or USB drive. Runtimes, source, and
data stay inside the folder; the host system is not modified.

## Requirements

- Windows 11, macOS 13+, or Linux — x86_64 or ARM64.
- Internet on first run (downloads ~600 MB of runtime files).

## Run

**Windows** — double-click `launch.bat` (it calls `launch.ps1`).

**macOS / Linux**
```bash
chmod +x launch.sh
./launch.sh
```
On macOS, rename `launch.sh` to `launch.command` for Finder double-click.

First run downloads Python, Node.js, uv, and ripgrep into `.cache/`, checks each
against a known SHA256, downloads the Hermes source, builds a virtual
environment, and sets a free default model. Later runs open the menu directly.

## How it works

- `HERMES_HOME` points to `data/`, so config and data stay in the folder, not `~/.hermes`.
- Runtimes live in `.cache/runtimes/<platform>` and are SHA256-checked before use.
- Each launch checks GitHub for the latest `main` commit and updates if newer; offline, it keeps the current version and does not block startup.
- No registry, environment, or host packages are changed.

## Configure

A free Nous model is set by default, so you can start without a key.

- Menu `[2] Setup` runs the wizard (needs a real terminal).
- Or set directly: `hermes config set model.provider <provider>` and `hermes config set model.default <model>`.
- Keys go in `data/.env`:
  ```env
  OPENROUTER_API_KEY=...
  OPENAI_API_KEY=...
  ANTHROPIC_API_KEY=...
  ```

## Profiles

Run separate agents (e.g. dev / project-manager / test) from one folder via menu
`[4] Profiles` — switch, create, rename, delete, export, import. Each profile has
its own config, keys, sessions, memory, and skills under `data/profiles/<name>`;
the active one shows on the status panel and is stored in `data/.active-profile`.

## Updating

Automatic on each launch. Manual: menu `[5] Advanced → [5] Update`, `hermes update`
in a chat, or delete `.cache/runtimes/<platform>` and `src/hermes-agent` to rebuild.

## Layout

```text
launch.sh / launch.bat / launch.ps1   launchers
scripts/                              setup, reset, helpers
data/                                 config, keys, sessions, memory, profiles  (private)
src/hermes-agent/                     downloaded source
.cache/runtimes/<platform>/           interpreters + venv
```

`data/`, `.cache/`, and `src/` are not tracked by git; they are rebuilt per machine.

## Data and security

`data/` holds your keys (`.env`), config, sessions, memory, and profiles. Anyone
with the folder can read them — encrypt the drive (BitLocker, FileVault, or
VeraCrypt) and don't carry production keys.

## Footprint

~600–900 MB per platform (interpreters and caches) plus ~50 MB source. Using the
folder on several operating systems stores one runtime per platform.

## Troubleshooting

- **Setup fails / times out** — check the connection; some firewalls block GitHub or Node CDNs; delete `.cache/` and relaunch.
- **macOS "developer cannot be verified"** — open via right-click → Open With → Terminal, or run `xattr -dr com.apple.quarantine <folder>`.
- **Windows SmartScreen warning** — scripts download files; click "More info" → "Run anyway". Sources are under `scripts/`.
- **Slow from a flash drive** — use a USB 3.0+ drive or external SSD.
- **Browser tools fail** — some systems block browsers on removable media; copy the folder to a local SSD.

## Credits

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by [Nous Research](https://github.com/NousResearch)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone), [uv](https://github.com/astral-sh/uv)
