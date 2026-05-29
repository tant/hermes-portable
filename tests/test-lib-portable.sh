#!/bin/bash
# Tests for scripts/lib-portable.sh — plain bash, no framework.
# Run: bash tests/test-lib-portable.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/../scripts/lib-portable.sh"

FAILS=0
run() {  # run <description> <fn>
    local desc="$1"; shift
    if "$@"; then
        echo "  ok:   $desc"
    else
        echo "  FAIL: $desc"
        FAILS=$((FAILS + 1))
    fi
}

test_path_hash() {
    local a b c
    a="$(path_hash /Volumes/USB1)"
    b="$(path_hash /Volumes/USB1)"
    c="$(path_hash /Volumes/USB2)"
    [ "$a" = "$b" ] || return 1        # deterministic
    [ "$a" != "$c" ] || return 1       # different inputs differ
    [ "${#a}" -eq 8 ] || return 1      # 8 chars
}
run "path_hash is deterministic, distinct, 8 chars" test_path_hash

test_verify_checksum() {
    local tmp; tmp="$(mktemp)"
    printf 'hello' > "$tmp"
    # Well-known: sha256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
    local good="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    ph_verify_checksum "$tmp" "$good" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
    # Empty expected = skip verification (return 0).
    ph_verify_checksum "$tmp" "" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
    # Wrong hash: must fail AND delete the file.
    printf 'hello' > "$tmp"
    if ph_verify_checksum "$tmp" "$(printf '0%.0s' {1..64})" >/dev/null 2>&1; then
        rm -f "$tmp"; return 1
    fi
    [ ! -f "$tmp" ]   # confirm deleted on mismatch
}
run "verify_checksum passes good, skips empty, deletes on mismatch" test_verify_checksum

test_fetch_sha_ok() (
    # Override curl in this subshell to return a valid 40-hex SHA.
    curl() { printf '0123456789abcdef0123456789abcdef01234567'; }
    local out; out="$(ph_fetch_remote_sha NousResearch/hermes-agent main)"
    [ "$out" = "0123456789abcdef0123456789abcdef01234567" ]
)
run "fetch_remote_sha returns the SHA on success" test_fetch_sha_ok

test_fetch_sha_offline() (
    curl() { return 7; }   # simulate connection failure
    ! ph_fetch_remote_sha NousResearch/hermes-agent main
)
run "fetch_remote_sha fails (non-zero, empty) when offline" test_fetch_sha_offline

test_fetch_sha_garbage() (
    curl() { printf 'Not Found'; }   # non-SHA body
    ! ph_fetch_remote_sha NousResearch/hermes-agent main
)
run "fetch_remote_sha rejects a non-SHA body" test_fetch_sha_garbage

test_profile_dir() {
    local tmp; tmp="$(mktemp -d)"
    mkdir -p "$tmp/profiles/dev"
    [ "$(ph_profile_dir "$tmp" default)" = "$tmp" ] || { rm -rf "$tmp"; return 1; }
    [ "$(ph_profile_dir "$tmp" "")" = "$tmp" ]      || { rm -rf "$tmp"; return 1; }
    [ "$(ph_profile_dir "$tmp" dev)" = "$tmp/profiles/dev" ] || { rm -rf "$tmp"; return 1; }
    [ "$(ph_profile_dir "$tmp" ghost)" = "$tmp" ]   || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
}
run "profile_dir resolves default/named/missing correctly" test_profile_dir

# ---- tests are appended by later tasks ----

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$FAILS test(s) failed."
    exit 1
fi
