#!/usr/bin/env bash
# ============================================================================
# Shared helpers for the Hermes portable launcher and setup (macOS / Linux).
# Source this file (`. scripts/lib-portable.sh`); do NOT execute it.
# Kept bash 3.2 compatible (macOS /bin/bash).
# ============================================================================

# Produce a short, stable 8-char id for a string (used to namespace per-drive
# temp dirs). macOS has no `md5sum`, so prefer sha256sum/shasum and fall back to
# the POSIX `cksum`. This replaces the old md5sum call that silently failed on
# macOS and made every drive share one venv path.
path_hash() {
    local input="$1" h
    if command -v sha256sum >/dev/null 2>&1; then
        h="$(printf '%s' "$input" | sha256sum | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        h="$(printf '%s' "$input" | shasum -a 256 | awk '{print $1}')"
    else
        h="$(printf '%s' "$input" | cksum | awk '{print $1}')"
    fi
    printf '%s' "${h:0:8}"
}

# Print the bare lowercase SHA256 hex digest of a file. Non-zero if no tool.
ph_sha256_of() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        return 1
    fi
}

# Verify a file matches an expected SHA256. Empty expected => skip (return 0).
# On mismatch: print details, delete the file, return 1.
ph_verify_checksum() {
    local file="$1" expected="$2" actual
    [ -z "$expected" ] && return 0
    actual="$(ph_sha256_of "$file")" || {
        echo "[ERROR] No SHA256 tool (sha256sum/shasum) to verify $(basename "$file")"
        return 1
    }
    expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
    actual="$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')"
    if [ "$actual" != "$expected" ]; then
        echo "[ERROR] Checksum mismatch for $(basename "$file")"
        echo "        expected: $expected"
        echo "        actual:   $actual"
        rm -f "$file"
        return 1
    fi
    return 0
}

# Fetch the latest commit SHA of a GitHub branch; print the bare 40-char hex.
# Prints nothing and returns non-zero on any failure (offline, timeout, non-SHA
# body) so callers can degrade gracefully. Bounded to ~8s.
ph_fetch_remote_sha() {
    local repo="$1" branch="${2:-main}" sha
    sha="$(curl -fsSL --connect-timeout 5 --max-time 8 \
        -H "Accept: application/vnd.github.sha" \
        "https://api.github.com/repos/${repo}/commits/${branch}" 2>/dev/null)" || return 1
    if printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
        printf '%s' "$sha"
        return 0
    fi
    return 1
}
