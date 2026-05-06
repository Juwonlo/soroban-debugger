#!/usr/bin/env bash
# Two-phase doc consistency check:
#   1. Regenerates man pages into a temp directory and diffs against committed
#      versions.  Exits non-zero if the CLI source has drifted from the .1 files.
#   2. Scans README.md for --option-name references in documentation blocks and
#      verifies that each one exists in a committed man page.  Exits non-zero if
#      README documents options that are not present in the CLI.
#
# Usage: bash scripts/check_manpages.sh
#   or:  make check-man
#   or:  TMPDIR=/custom/tmp bash scripts/check_manpages.sh
#
# Environment variables:
#   TMPDIR  - Custom temp directory (defaults to /tmp if unset or invalid)
#   DEBUG   - Set to 1 for verbose output
#
# Portability notes:
#   - Uses `mktemp -d` with explicit template for BSD/macOS compatibility.
#   - Honours TMPDIR so CI and sandbox environments can control the temp root.
#   - Falls back gracefully with validation and clear error messages.
#   - Detects and reports when temp directories are unwritable.

set -euo pipefail

DEBUG="${DEBUG:-0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMITTED_DIR="$REPO_ROOT/man/man1"

# Function to print debug messages
debug_log() {
    if [[ "$DEBUG" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Function to find a writable temp directory
find_tmpdir() {
    local candidates=()

    # First, try TMPDIR if explicitly set and is a directory
    if [[ -n "${TMPDIR:-}" ]]; then
        # Normalize the path (resolve symlinks)
        local resolved_tmpdir
        resolved_tmpdir=$(cd "$TMPDIR" 2>/dev/null && pwd) || resolved_tmpdir="$TMPDIR"
        if [[ -d "$resolved_tmpdir" && -w "$resolved_tmpdir" ]]; then
            candidates+=("$resolved_tmpdir")
            debug_log "Found TMPDIR: $resolved_tmpdir"
        fi
    fi

    # Add standard fallback locations (platform-portable)
    # On macOS, /tmp is usually a symlink to /private/tmp
    candidates+=("/tmp" "/var/tmp" "$HOME/.tmp")

    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" && -w "$candidate" ]]; then
            echo "$candidate"
            debug_log "Selected temp directory: $candidate"
            return 0
        fi
        debug_log "Temp directory not usable: $candidate (exists=$(test -d "$candidate"; echo $?) writable=$(test -w "$candidate" 2>/dev/null; echo $?))"
    done

    return 1
}

# Find and validate temp directory
TMPDIR_SELECTED=$(find_tmpdir) || {
    echo "ERROR: Could not find a writable temporary directory." >&2
    echo "  Checked: TMPDIR (if set), /tmp, /var/tmp, \$HOME/.tmp" >&2
    echo "  ACTION: Ensure at least one temp directory exists and is writable." >&2
    echo "  HINT: Set TMPDIR=/path/to/writable/dir if default locations are restricted." >&2
    exit 2
}

export TMPDIR="$TMPDIR_SELECTED"
debug_log "Using TMPDIR=$TMPDIR_SELECTED"

# Create temp dir with explicit template for portability (BSD mktemp requires
# the template to contain at least 3 trailing Xs).
TEMP_DIR=$(mktemp -d "${TMPDIR_SELECTED}/check_manpages.XXXXXXXX") || {
    echo "ERROR: Failed to create temporary directory in $TMPDIR_SELECTED" >&2
    exit 2
}

debug_log "Created TEMP_DIR: $TEMP_DIR"

# Always clean up temp dir, even on failure or Ctrl-C
trap 'rm -rf "$TEMP_DIR"' EXIT

TEMP_MAN_DIR="$TEMP_DIR/man/man1"
NORMALIZED_COMMITTED_DIR="$TEMP_DIR/normalized/committed"
NORMALIZED_GENERATED_DIR="$TEMP_DIR/normalized/generated"

normalize_manpage_possible_values() {
    local src_file="$1"
    local dst_file="$2"

    awk '
        BEGIN { in_possible_values_block = 0 }
        {
            if (in_possible_values_block == 1) {
                if ($0 == ".RE") {
                    in_possible_values_block = 0
                    print "[[POSSIBLE_VALUES_BLOCK]]"
                }
                next
            }

            if ($0 == "\\fIPossible values:\\fR") {
                in_possible_values_block = 1
                next
            }

            if ($0 ~ /^\[\\fIpossible values: \\fR.*\]$/) {
                print "[[POSSIBLE_VALUES_BLOCK]]"
                next
            }

            print
        }
    ' "$src_file" > "$dst_file"
}

normalize_manpage_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    mkdir -p "$dst_dir"

    local src_file
    for src_file in "$src_dir"/*.1; do
        [ -e "$src_file" ] || continue
        normalize_manpage_possible_values "$src_file" "$dst_dir/$(basename "$src_file")"
    done
}

echo "Generating fresh man pages into $TEMP_DIR..."
debug_log "TMPDIR source: $TMPDIR_SELECTED"

# MAN_OUT_DIR is read by build.rs to redirect man page output to a temp directory.
# This avoids touching the committed man/man1/ during the diff check.
# The build script (which generates man pages) runs before the main crate is compiled,
# so we tolerate main-crate compilation failures with || true — man pages are still produced.
MAN_OUT_DIR="$TEMP_MAN_DIR" cargo build --quiet 2>/dev/null || true

if [ ! -d "$TEMP_MAN_DIR" ]; then
    echo "ERROR: Man page generation failed: $TEMP_MAN_DIR was not created." >&2
    exit 2
fi

if [ ! -d "$COMMITTED_DIR" ]; then
    echo "ERROR: Committed man page directory not found: $COMMITTED_DIR"
    echo "   Run 'make regen-man' to generate and commit man pages."
    exit 1
fi

echo "Diffing against committed man pages in $COMMITTED_DIR..."

normalize_manpage_dir "$COMMITTED_DIR" "$NORMALIZED_COMMITTED_DIR"
normalize_manpage_dir "$TEMP_MAN_DIR" "$NORMALIZED_GENERATED_DIR"

diff_output=$(diff -r "$NORMALIZED_COMMITTED_DIR" "$NORMALIZED_GENERATED_DIR" 2>&1) || diff_status=$?
diff_status=${diff_status:-0}

if [ "$diff_status" -eq 0 ]; then
    echo "OK: Man pages are in sync."
    # Fall through to README option drift check below.
elif [ "$diff_status" -eq 1 ]; then
    echo ""
    echo "ERROR: Drift detected between committed man pages and current CLI source."
    echo "   Run 'make regen-man' and commit the updated .1 files."
    echo ""
    echo "--- diff output ---"
    echo "$diff_output"
    exit 1
else
    echo "ERROR: diff exited with error (status $diff_status)."
    echo "$diff_output"
    exit 2
fi

# ── README option drift check ────────────────────────────────────────────────
# Verifies that every --option-name documented in README.md also exists in a
# committed man page.  Only lines with two or more leading spaces are scanned —
# these are option-table entries ("  --opt  desc") and shell-continuation args
# ("  --opt" in multi-line soroban-debug examples).  Lines starting at column 0
# (cargo, docker, git invocations) are intentionally excluded.
echo ""
echo "Checking README.md option references against committed man pages..."

README="$REPO_ROOT/README.md"

if [ ! -f "$README" ]; then
    echo "WARNING: README.md not found, skipping option drift check."
    exit 0
fi

# Step 1: extract --option-name patterns from indented README lines.
readme_opts=$(grep -E '^[[:space:]]{2,}' "$README" \
    | grep -oE '\-\-[a-z][a-z0-9-]+' \
    | sort -u) || true

if [ -z "$readme_opts" ]; then
    echo "OK: No --option references found in README.md documentation blocks."
    exit 0
fi

# Step 2: extract --option-name patterns from committed man pages.
# In roff, long options are encoded as \fB\-\-option\-name\fR where each
# hyphen is escaped as \-.  The alternation ([a-z0-9]|\\-) matches letters,
# digits, and escaped hyphens but stops cleanly before \fR/\fI/etc.
man_opts=$(grep -hEo '\\-\\-([a-z0-9]|\\-)+' "$COMMITTED_DIR"/*.1 2>/dev/null \
    | sed 's/\\-/-/g' \
    | grep '^--' \
    | sort -u) || true

if [ -z "$man_opts" ]; then
    echo "ERROR: No options extracted from committed man pages at $COMMITTED_DIR." >&2
    echo "   Run 'make regen-man' to generate and commit man pages first." >&2
    exit 2
fi

# Step 3: report any README options absent from every man page.
unknown=()
while IFS= read -r opt; do
    if ! printf '%s\n' "$man_opts" | grep -qxF -- "$opt"; then
        unknown+=("$opt")
    fi
done <<< "$readme_opts"

if [ "${#unknown[@]}" -eq 0 ]; then
    echo "OK: All README option references match the CLI man pages."
    exit 0
fi

echo "" >&2
echo "ERROR: README.md references options not found in any CLI man page:" >&2
for opt in "${unknown[@]}"; do
    echo "   $opt" >&2
done
echo "" >&2
echo "Either remove the option from README.md or add it to the CLI source" >&2
echo "and run 'make regen-man' to regenerate man pages." >&2
exit 1
