#!/usr/bin/env bash
# Behavioral tests for scripts/check_manpages.sh.
#
# Uses a temporary fake repo and a stub cargo binary to run check_manpages.sh
# in full isolation.  Tests:
#   1. Tmpdir is created inside the controlled $TMPDIR and cleaned up on exit.
#   2. README option drift check passes when all documented options exist in
#      the committed man pages.
#   3. README option drift check exits non-zero when README documents an option
#      absent from every man page.
#
# Mirrors the isolation pattern used by scripts/test_benchmark_regressions.sh.

set -euo pipefail

SOURCE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check_manpages.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/check-manpage-test.XXXXXX")"
REPO_ROOT="$TEST_ROOT/repo"
BIN_DIR="$TEST_ROOT/bin"
CUSTOM_TMPDIR="$TEST_ROOT/tmp"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

mkdir -p "$REPO_ROOT/scripts" "$REPO_ROOT/man/man1" "$BIN_DIR" "$CUSTOM_TMPDIR"
cp "$SOURCE_SCRIPT" "$REPO_ROOT/scripts/check_manpages.sh"
chmod +x "$REPO_ROOT/scripts/check_manpages.sh"

# Minimal roff man page with --contract and --function.
# The \fB\-\-option\fR encoding mirrors what clap_mangen generates.
cat > "$REPO_ROOT/man/man1/soroban-debug-run.1" <<'EOF'
.ie \n(.g .ds Aq \(aq
.el .ds Aq '
.TH run 1
.SH OPTIONS
.TP
\fB\-c\fR, \fB\-\-contract\fR \fI<FILE>\fR
Path to the contract WASM file
.TP
\fB\-f\fR, \fB\-\-function\fR \fI<FUNCTION>\fR
Function name to execute
EOF

# Fake cargo: copies committed man pages into MAN_OUT_DIR, simulating a clean
# build where man page content has not changed.
cat > "$BIN_DIR/cargo" <<FAKECARGO
#!/usr/bin/env bash
set -euo pipefail
if [ -n "\${MAN_OUT_DIR:-}" ]; then
    mkdir -p "\$MAN_OUT_DIR"
    cp "$REPO_ROOT/man/man1/"*.1 "\$MAN_OUT_DIR/"
fi
FAKECARGO
chmod +x "$BIN_DIR/cargo"

export PATH="$BIN_DIR:$PATH"
export TMPDIR="$CUSTOM_TMPDIR"
unset DEBUG 2>/dev/null || true

# ── Test 1: tmpdir is created inside $TMPDIR and cleaned up after exit ───────

cat > "$REPO_ROOT/README.md" <<'EOF'
## Run Command

Options:
  -c, --contract <FILE>   Path to the WASM file
  -f, --function <NAME>   Function name
EOF

bash "$REPO_ROOT/scripts/check_manpages.sh" > /dev/null

leftover=$(find "$CUSTOM_TMPDIR" -mindepth 1 -maxdepth 1 -name 'check_manpages.*' 2>/dev/null \
    | wc -l | tr -d ' ')
if [ "$leftover" -ne 0 ]; then
    echo "FAIL: check_manpages.sh did not clean up its tmpdir after a successful run" >&2
    exit 1
fi

echo "PASS: tmpdir is created in TMPDIR and cleaned up on exit"

# ── Test 2: README with only known options passes ────────────────────────────
# Reuse the README from test 1 — it only contains --contract and --function,
# both of which are in the fake man page above.

bash "$REPO_ROOT/scripts/check_manpages.sh" > /dev/null

echo "PASS: README drift check passes when all options exist in man pages"

# ── Test 3: README with an unknown option causes failure ─────────────────────

cat > "$REPO_ROOT/README.md" <<'EOF'
## Run Command

Options:
  -c, --contract <FILE>   Path to the WASM file
  --watch               Watch the WASM file for changes
EOF

if bash "$REPO_ROOT/scripts/check_manpages.sh" > /dev/null 2>&1; then
    echo "FAIL: expected check_manpages.sh to exit non-zero for --watch drift" >&2
    exit 1
fi

echo "PASS: README drift check exits non-zero when README documents an unknown option"

echo ""
echo "All check_manpages.sh behavioral tests passed."
