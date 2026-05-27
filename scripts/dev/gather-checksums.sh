#!/bin/bash
# scripts/dev/gather-checksums.sh
# Dev tool: fetch/compute SHA256 for the pinned runtime assets and print
# ready-to-paste constant blocks for setup-unix.sh and setup-windows.ps1.
#
# Strategy per asset: try "<url>.sha256" (published by astral / python-build-
# standalone) or the Node SHASUMS file; if unavailable, download the asset and
# compute the hash locally (trust-on-first-use, marked "[TOFU]").
#
# Usage: bash scripts/dev/gather-checksums.sh
set -u
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sha_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# Resolve a published .sha256 sidecar, else download+compute.
resolve() {  # resolve <label> <url>
    local label="$1" url="$2" side val
    side="$(curl -fsSL --max-time 30 "${url}.sha256" 2>/dev/null | awk '{print $1}')"
    if printf '%s' "$side" | grep -Eq '^[0-9a-f]{64}$'; then
        printf '%s  %s  (published)\n' "$side" "$label"
        return
    fi
    curl -fsSL --max-time 600 "$url" -o "$TMP/asset" 2>/dev/null || {
        printf 'ERROR-DOWNLOAD  %s  %s\n' "$label" "$url"; return; }
    val="$(sha_of "$TMP/asset")"
    printf '%s  %s  [TOFU]\n' "$val" "$label"
}

NODE_VER="v22.14.0"
echo "# Node SHASUMS (authoritative, all arches):"
curl -fsSL "https://nodejs.org/dist/${NODE_VER}/SHASUMS256.txt" \
  | grep -E "node-${NODE_VER}-(darwin-(x64|arm64)\.tar\.gz|linux-(x64|arm64)\.tar\.xz|win-x64\.zip)"

echo ""
echo "# Python / uv / ripgrep / git (resolve per URL):"
# macos-arm64
resolve "PY  macos-arm64"  "https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-aarch64-apple-darwin-install_only.tar.gz"
resolve "UV  macos-arm64"  "https://github.com/astral-sh/uv/releases/download/0.7.8/uv-aarch64-apple-darwin.tar.gz"
resolve "RG  macos-arm64"  "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-apple-darwin.tar.gz"
# macos-x64
resolve "PY  macos-x64"    "https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-x86_64-apple-darwin-install_only.tar.gz"
resolve "UV  macos-x64"    "https://github.com/astral-sh/uv/releases/download/0.7.8/uv-x86_64-apple-darwin.tar.gz"
resolve "RG  macos-x64"    "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-apple-darwin.tar.gz"
# linux-x64
resolve "PY  linux-x64"    "https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-x86_64-unknown-linux-gnu-install_only.tar.gz"
resolve "UV  linux-x64"    "https://github.com/astral-sh/uv/releases/download/0.7.8/uv-x86_64-unknown-linux-gnu.tar.gz"
resolve "RG  linux-x64"    "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz"
# linux-arm64
resolve "PY  linux-arm64"  "https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-aarch64-unknown-linux-gnu-install_only.tar.gz"
resolve "UV  linux-arm64"  "https://github.com/astral-sh/uv/releases/download/0.7.8/uv-aarch64-unknown-linux-gnu.tar.gz"
resolve "RG  linux-arm64"  "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-aarch64-unknown-linux-gnu.tar.gz"
# windows-x64 (for setup-windows.ps1)
resolve "PY  windows-x64"  "https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-x86_64-pc-windows-msvc-install_only.tar.gz"
resolve "UV  windows-x64"  "https://github.com/astral-sh/uv/releases/download/0.6.8/uv-x86_64-pc-windows-msvc.zip"
resolve "RG  windows-x64"  "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-pc-windows-msvc.zip"
resolve "GIT windows-x64"  "https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.1/MinGit-2.53.0-64-bit.zip"
