#!/bin/bash
# ============================================================================
# Hermes Portable - Unix Runtime Setup (macOS / Linux)
# ============================================================================
# Downloads and installs portable Python, Node.js, uv, ripgrep,
# clones Hermes source, creates venv, and installs dependencies.
# ============================================================================

set -e
. "$(cd "$(dirname "$0")" && pwd)/lib-portable.sh"

PORTABLE_ROOT="$1"
if [ -z "$PORTABLE_ROOT" ]; then
    echo "Usage: $0 <portable-root>"
    exit 1
fi

CACHE_DIR="$PORTABLE_ROOT/.cache"
SRC_DIR="$PORTABLE_ROOT/src"

# ---------------------------------------------------------------------------
# Detect platform
# ---------------------------------------------------------------------------
OS_RAW="$(uname -s)"
ARCH_RAW="$(uname -m)"

case "$OS_RAW" in
    Linux*)     PLATFORM="linux" ;;
    Darwin*)    PLATFORM="macos" ;;
    *)
        echo "[ERROR] Unsupported OS: $OS_RAW"
        exit 1
        ;;
esac

case "$ARCH_RAW" in
    x86_64|amd64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "[ERROR] Unsupported architecture: $ARCH_RAW"
        exit 1
        ;;
esac

RUNTIME_DIR="$CACHE_DIR/runtimes/${PLATFORM}-${ARCH}"
BIN_DIR="$RUNTIME_DIR/bin"
TMP_DIR="$RUNTIME_DIR/_tmp"

mkdir -p "$RUNTIME_DIR" "$SRC_DIR" "$BIN_DIR" "$TMP_DIR"

# ---------------------------------------------------------------------------
# Health check: if ready.flag exists but core files are missing, start fresh
# ---------------------------------------------------------------------------
if [ -f "$RUNTIME_DIR/ready.flag" ]; then
    if [ ! -x "$RUNTIME_DIR/python/bin/python3" ] || [ ! -x "$RUNTIME_DIR/uv/uv" ] || [ ! -x "$RUNTIME_DIR/venv/bin/hermes" ]; then
        warn "ready.flag exists but core files are missing — restarting setup ..."
        rm -f "$RUNTIME_DIR/ready.flag"
    fi
fi

# ---------------------------------------------------------------------------
# URL builders based on platform+arch
# ---------------------------------------------------------------------------
# python-build-standalone uses "aarch64" while macOS uname -m reports "arm64"
case "$ARCH_RAW" in
    arm64) PYTHON_ARCH="aarch64" ;;
    *)     PYTHON_ARCH="$ARCH_RAW" ;;
esac

if [ "$PLATFORM" = "macos" ]; then
    PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-${PYTHON_ARCH}-apple-darwin-install_only.tar.gz"
    NODE_URL="https://nodejs.org/dist/v22.14.0/node-v22.14.0-darwin-${ARCH}.tar.gz"
    UV_URL="https://github.com/astral-sh/uv/releases/download/0.7.8/uv-${PYTHON_ARCH}-apple-darwin.tar.gz"
    RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-${PYTHON_ARCH}-apple-darwin.tar.gz"
else
    PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20260510/cpython-3.11.15+20260510-${ARCH_RAW}-unknown-linux-gnu-install_only.tar.gz"
    NODE_URL="https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-${ARCH}.tar.xz"
    UV_URL="https://github.com/astral-sh/uv/releases/download/0.7.8/uv-${ARCH_RAW}-unknown-linux-gnu.tar.gz"
    if [ "$ARCH" = "arm64" ]; then
        RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-${PYTHON_ARCH}-unknown-linux-gnu.tar.gz"
    else
        RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-${ARCH_RAW}-unknown-linux-musl.tar.gz"
    fi
fi

# ---------------------------------------------------------------------------
# Expected SHA256 of each pinned asset (authenticity check; see download()).
# Node/Python/uv values are from the publishers' checksums; ripgrep is pinned
# trust-on-first-use (no per-asset SHA256 is published upstream).
# Regenerate with: bash scripts/dev/gather-checksums.sh
# When bumping any pinned version above, update the matching value here.
# ---------------------------------------------------------------------------
case "${PLATFORM}-${ARCH}" in
    macos-arm64)
        PY_SHA256="03bcedae9b19a48888d7dc8ba064f73f6efaaf2b13f6a8e1a1bcc062df13e855"
        NODE_SHA256="e9404633bc02a5162c5c573b1e2490f5fb44648345d64a958b17e325729a5e42"
        UV_SHA256="ad6b3825ba277de70b9d0a37055f7d828f3f37416aee1cde65000f330efd4587"
        RG_SHA256="24ad76777745fbff131c8fbc466742b011f925bfa4fffa2ded6def23b5b937be"
        ;;
    macos-x64)
        PY_SHA256="5e388e3db8b59c8487ddd1423330b90fc7f0c6ef7eadec945441a180d0dd4bc4"
        NODE_SHA256="6698587713ab565a94a360e091df9f6d91c8fadda6d00f0cf6526e9b40bed250"
        UV_SHA256="f046249639014eb70b43cbaf83eb6f56aac724ada354f9b9aad65f9960737920"
        RG_SHA256="fc87e78f7cb3fea12d69072e7ef3b21509754717b746368fd40d88963630e2b3"
        ;;
    linux-x64)
        PY_SHA256="14b5843a3492925dab6fdb7cca7d09af83ddf1fe2851f72cf9b1edc8ed2b1db7"
        NODE_SHA256="69b09dba5c8dcb05c4e4273a4340db1005abeafe3927efda2bc5b249e80437ec"
        UV_SHA256="285981409c746508c1fd125f66a1ea654e487bf1e4d9f45371a062338f788adb"
        RG_SHA256="4cf9f2741e6c465ffdb7c26f38056a59e2a2544b51f7cc128ef28337eeae4d8e"
        ;;
    linux-arm64)
        PY_SHA256="0bc1b7acbb888881addf3a1c887a47d510d4300db6e3ad2ba461154b982e456a"
        NODE_SHA256="08bfbf538bad0e8cbb0269f0173cca28d705874a67a22f60b57d99dc99e30050"
        UV_SHA256="da9e1c97f1452b25c8955127c92da7b68be228ad0b43bf50bba4dadb25c8b337"
        RG_SHA256="c827481c4ff4ea10c9dc7a4022c8de5db34a5737cb74484d62eb94a95841ab2f"
        ;;
esac

SOURCE_URL="https://github.com/NousResearch/hermes-agent/archive/refs/heads/main.tar.gz"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
step() {
    echo ""
    echo "[SETUP] $1"
}

done_msg() {
    echo "[OK]    $1"
}

warn() {
    echo "[WARN]  $1"
}

download() {
    local url="$1"
    local out="$2"
    local expected_sha="${3:-}"   # empty => skip checksum (e.g. source tarball)
    local name
    name="$(basename "$url")"

    if [ -f "$out" ]; then
        local size
        size="$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out" 2>/dev/null || echo 0)"
        if [ "$size" -gt 0 ]; then
            local corrupt=0
            if [[ "$name" == *.tar.gz ]]; then
                gzip -t "$out" 2>/dev/null || corrupt=1
            elif [[ "$name" == *.tar.xz ]]; then
                xz -t "$out" 2>/dev/null || corrupt=1
            fi
            if [ "$corrupt" -eq 1 ]; then
                warn "$name is corrupted or incomplete — deleting and re-downloading ..."
                rm -f "$out"
            elif ! ph_verify_checksum "$out" "$expected_sha"; then
                warn "$name failed checksum — deleting and re-downloading ..."
                # ph_verify_checksum already removed the file.
            else
                echo "        $name already cached ($(( size / 1024 / 1024 )) MB)."
                return 0
            fi
        else
            warn "$name exists but is 0 bytes — re-downloading ..."
            rm -f "$out"
        fi
    fi

    echo "        Downloading $name ..."
    echo "        URL: $url"
    if ! curl -fL --progress-bar --retry 3 --connect-timeout 30 --max-time 600 "$url" -o "$out"; then
        rm -f "$out"
        echo "        FAILED to download $name"
        return 1
    fi

    if [ ! -f "$out" ]; then
        echo "        Download succeeded but file not found: $out"
        return 1
    fi
    local dsize
    dsize="$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out" 2>/dev/null || echo 0)"
    if [ "$dsize" -eq 0 ]; then
        rm -f "$out"
        echo "        Downloaded file is 0 bytes: $name"
        return 1
    fi
    if ! ph_verify_checksum "$out" "$expected_sha"; then
        echo "        Refusing to use $name (checksum mismatch)."
        return 1
    fi
    echo "        Download complete ($(( dsize / 1024 / 1024 )) MB)."
}

extract_tgz() {
    local archive="$1"
    local dest="$2"
    echo "        Extracting $(basename "$archive") ..."
    # Clean up partial extraction from previous failed run
    if [ -d "$dest" ]; then
        rm -rf "$dest"
    fi
    mkdir -p "$dest"
    if ! tar -xzf "$archive" -C "$dest" --strip-components=1; then
        rm -rf "$dest"
        rm -f "$archive"
        echo "        ERROR: tar extraction failed for $(basename "$archive") (corrupted archive deleted)"
        return 1
    fi
}

extract_txz() {
    local archive="$1"
    local dest="$2"
    echo "        Extracting $(basename "$archive") ..."
    # Clean up partial extraction from previous failed run
    if [ -d "$dest" ]; then
        rm -rf "$dest"
    fi
    mkdir -p "$dest"
    if ! tar -xf "$archive" -C "$dest" --strip-components=1; then
        rm -rf "$dest"
        rm -f "$archive"
        echo "        ERROR: tar extraction failed for $(basename "$archive") (corrupted archive deleted)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 1. Portable Python
# ---------------------------------------------------------------------------
step "Installing portable Python 3.11 ..."
PY_ARCHIVE="$RUNTIME_DIR/python.tar.gz"
if ! download "$PYTHON_URL" "$PY_ARCHIVE" "$PY_SHA256"; then
    echo "[ERROR] Failed to download Python. Check your internet connection."
    exit 1
fi
# Bug fix: skip re-extraction if already unpacked (saves ~30s on repeat runs)
if [ ! -d "$RUNTIME_DIR/python/bin" ]; then
    extract_tgz "$PY_ARCHIVE" "$RUNTIME_DIR/python"
else
    echo "        Already extracted — skipping."
fi
done_msg "Python ready"

# ---------------------------------------------------------------------------
# 2. Node.js
# ---------------------------------------------------------------------------
step "Installing Node.js 22 LTS ..."
NODE_ARCHIVE="$RUNTIME_DIR/node.tar.xz"
if [ "$PLATFORM" = "macos" ]; then
    NODE_ARCHIVE="$RUNTIME_DIR/node.tar.gz"
fi
if ! download "$NODE_URL" "$NODE_ARCHIVE" "$NODE_SHA256"; then
    warn "Node.js download failed — web tools may be limited"
else
    # Bug fix: skip re-extraction if already unpacked
    if [ ! -d "$RUNTIME_DIR/node/bin" ]; then
        if [ "$PLATFORM" = "macos" ]; then
            extract_tgz "$NODE_ARCHIVE" "$RUNTIME_DIR/node" || {
                warn "Node.js extraction failed — web tools may be limited"
            }
        else
            extract_txz "$NODE_ARCHIVE" "$RUNTIME_DIR/node" || {
                warn "Node.js extraction failed — web tools may be limited"
            }
        fi
    else
        echo "        Already extracted — skipping."
    fi
    [ -d "$RUNTIME_DIR/node/bin" ] && done_msg "Node.js ready"
fi

# ---------------------------------------------------------------------------
# 3. uv
# ---------------------------------------------------------------------------
step "Installing uv ..."
UV_ARCHIVE="$RUNTIME_DIR/uv.tar.gz"
if ! download "$UV_URL" "$UV_ARCHIVE" "$UV_SHA256"; then
    echo "[ERROR] Failed to download uv. Aborting."
    exit 1
fi
rm -rf "$RUNTIME_DIR/uv"
mkdir -p "$RUNTIME_DIR/uv"
if tar -xzf "$UV_ARCHIVE" -C "$RUNTIME_DIR/uv" --strip-components=1; then
    chmod +x "$RUNTIME_DIR/uv/uv" 2>/dev/null || true
    done_msg "uv ready"
else
    rm -rf "$RUNTIME_DIR/uv"
    echo "[ERROR] Failed to extract uv. Aborting."
    exit 1
fi

# ---------------------------------------------------------------------------
# 4. ripgrep
# ---------------------------------------------------------------------------
step "Installing ripgrep ..."
RG_ARCHIVE="$RUNTIME_DIR/rg.tar.gz"
if download "$RG_URL" "$RG_ARCHIVE" "$RG_SHA256"; then
    mkdir -p "$TMP_DIR/rg"
    tar -xzf "$RG_ARCHIVE" -C "$TMP_DIR/rg" --strip-components=1 2>/dev/null || \
        tar -xzf "$RG_ARCHIVE" -C "$TMP_DIR/rg"
    RG_BIN="$(find "$TMP_DIR/rg" -type f -name rg -print -quit 2>/dev/null)"
    if [ -n "$RG_BIN" ] && [ -f "$RG_BIN" ]; then
        cp "$RG_BIN" "$BIN_DIR/rg"
        chmod +x "$BIN_DIR/rg"
        done_msg "ripgrep ready"
    else
        warn "ripgrep binary not found in archive"
    fi
    rm -rf "$TMP_DIR/rg"
else
    warn "ripgrep not available for ${PLATFORM}-${ARCH} — Hermes will use grep fallback"
fi

# ---------------------------------------------------------------------------
# 5. Hermes source code
# ---------------------------------------------------------------------------
step "Downloading Hermes Agent source code ..."
SRC_ARCHIVE="$RUNTIME_DIR/source.tar.gz"
if ! download "$SOURCE_URL" "$SRC_ARCHIVE"; then
    echo "[ERROR] Failed to download Hermes source. Aborting."
    exit 1
fi
rm -rf "$TMP_DIR/source"
mkdir -p "$TMP_DIR/source"
tar -xzf "$SRC_ARCHIVE" -C "$TMP_DIR/source" --strip-components=1
rm -rf "$SRC_DIR/hermes-agent"
mv "$TMP_DIR/source" "$SRC_DIR/hermes-agent"
done_msg "Source code ready"

# ---------------------------------------------------------------------------
# 6. macOS gatekeeper / permissions cleanup
# ---------------------------------------------------------------------------
if [ "$PLATFORM" = "macos" ]; then
    step "Removing macOS quarantine attributes ..."
    xattr -dr com.apple.quarantine "$RUNTIME_DIR/python" 2>/dev/null || true
    xattr -dr com.apple.quarantine "$RUNTIME_DIR/node" 2>/dev/null || true
    xattr -dr com.apple.quarantine "$RUNTIME_DIR/uv" 2>/dev/null || true
    xattr -dr com.apple.quarantine "$BIN_DIR" 2>/dev/null || true
    done_msg "Gatekeeper attributes cleared"
fi

# Make sure binaries are executable
chmod -R +x "$RUNTIME_DIR/python/bin" 2>/dev/null || true
chmod -R +x "$RUNTIME_DIR/node/bin" 2>/dev/null || true
chmod -R +x "$RUNTIME_DIR/uv" 2>/dev/null || true
chmod -R +x "$BIN_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Create virtual environment
# ---------------------------------------------------------------------------
step "Creating Python virtual environment ..."
PYTHON_EXE="$RUNTIME_DIR/python/bin/python3"
VENV_DIR="$RUNTIME_DIR/venv"
UV_EXE="$RUNTIME_DIR/uv/uv"

if [ ! -x "$PYTHON_EXE" ]; then
    echo "[ERROR] Python executable not found at $PYTHON_EXE"
    exit 1
fi

# Bug fix: bare $? check doesn't work under set -e; use if ! pattern instead
if ! "$UV_EXE" venv "$VENV_DIR" --python "$PYTHON_EXE"; then
    echo "[ERROR] Failed to create virtual environment"
    exit 1
fi
done_msg "Virtual environment ready"

# ---------------------------------------------------------------------------
# 8. Install Hermes dependencies
# ---------------------------------------------------------------------------
step "Installing Hermes Python dependencies ..."
echo "        This may take 3-10 minutes depending on your connection."
VENV_PYTHON="$VENV_DIR/bin/python"

# Try uv first (faster), fall back to pip on unsupported filesystem (e.g. ExFAT)
if ! "$UV_EXE" pip install --python "$VENV_PYTHON" --link-mode=copy -e "$SRC_DIR/hermes-agent[all]" 2>/dev/null; then
    echo "        uv install failed — falling back to pip ..."
    if ! "$VENV_PYTHON" -m ensurepip --upgrade >/dev/null 2>&1; then
        echo "[WARN] Could not install pip in virtual environment"
    fi
    if ! "$VENV_PYTHON" -m pip install -e "$SRC_DIR/hermes-agent[all]"; then
        echo "[ERROR] Failed to install Hermes dependencies"
        exit 1
    fi
fi
done_msg "Dependencies installed"

# ---------------------------------------------------------------------------
# 9. Install messaging dependencies (Telegram, etc.)
# ---------------------------------------------------------------------------
# Hermes [all] intentionally excludes messaging deps for size.
# The lazy-install system is supposed to auto-install on first use,
# but it can fail silently in some environments. Pre-install here
# so Telegram works out of the box.
# ---------------------------------------------------------------------------
step "Installing messaging dependencies (Telegram) ..."
if ! "$UV_EXE" pip install --python "$VENV_PYTHON" --link-mode=copy "python-telegram-bot[webhooks]==22.6" 2>/dev/null; then
    if ! "$VENV_PYTHON" -m pip install "python-telegram-bot[webhooks]==22.6" 2>/dev/null; then
        warn "python-telegram-bot install failed - will retry on first use"
    else
        done_msg "python-telegram-bot ready"
    fi
else
    done_msg "python-telegram-bot ready"
fi

# ---------------------------------------------------------------------------
# 10. Install Playwright browsers (optional)
# ---------------------------------------------------------------------------
step "Installing Playwright browsers (optional) ..."
export PLAYWRIGHT_BROWSERS_PATH="$RUNTIME_DIR/playwright"
if "$VENV_PYTHON" -m playwright install chromium 2>/dev/null; then
    done_msg "Playwright browsers ready"
else
    warn "Playwright browser install failed (web tools may be limited)"
fi

# ---------------------------------------------------------------------------
# 11. Seed a free default model (only on a fresh install)
# ---------------------------------------------------------------------------
# So the agent works out of the box without the interactive wizard, point it at
# the one currently-free Nous model. Skipped if a config already exists, so a
# user's own choices are never overwritten. owl-alpha is a free preview and may
# change upstream; users can re-select any model via the launcher menu.
if [ ! -f "$PORTABLE_ROOT/data/config.yaml" ]; then
    step "Seeding free default model ..."
    mkdir -p "$PORTABLE_ROOT/data"
    HERMES_BIN="$VENV_DIR/bin/hermes"
    if [ -x "$HERMES_BIN" ]; then
        HERMES_HOME="$PORTABLE_ROOT/data" "$HERMES_BIN" config set model.provider nous >/dev/null 2>&1 || true
        HERMES_HOME="$PORTABLE_ROOT/data" "$HERMES_BIN" config set model.default openrouter/owl-alpha >/dev/null 2>&1 || true
        done_msg "Default model set to openrouter/owl-alpha (free)"
    fi
fi

# ---------------------------------------------------------------------------
# 12. Mark ready
# ---------------------------------------------------------------------------
touch "$RUNTIME_DIR/ready.flag"
rm -rf "$TMP_DIR"

echo ""
echo "========================================"
echo "   Setup Complete! Launching Hermes..."
echo "========================================"
sleep 1
