#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCHMARK_THRESHOLD="${BENCHMARK_THRESHOLD:-10}"
CURRENT_BASELINE_NAME="${CURRENT_BASELINE_NAME:-new}"
BASELINE_NAME="${BASELINE_NAME:-base}"

log() {
    printf '[bench-regression] %s\n' "$*"
}

log_worktree_state() {
    log "worktree state"
    git -C "$REPO_ROOT" worktree list --porcelain || log "unable to read worktree list"
}

if [ -z "${BASELINE_REF:-}" ]; then
    if git -C "$REPO_ROOT" rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
        BASELINE_REF="origin/main"
    else
        BASELINE_REF="main"
    fi
fi

TEMP_DIR="$(mktemp -d)"
WORKTREE_DIR="$TEMP_DIR/baseline-worktree"
BENCH_TARGET_DIR="$TEMP_DIR/cargo-target"
CRITCMP_ROOT="$TEMP_DIR/critcmp-root"
WORKTREE_ADDED=0

cleanup() {
    local cleanup_failed=0

    log "cleanup start"
    log "temp dir: $TEMP_DIR"
    log "worktree path: $WORKTREE_DIR"
    log_worktree_state

    if [ "$WORKTREE_ADDED" -eq 1 ]; then
        if git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR"; then
            log "worktree remove succeeded"
        else
            log "worktree remove failed; running fallback prune/remove"
            git -C "$REPO_ROOT" worktree prune --expire now || cleanup_failed=1
            if [ -d "$WORKTREE_DIR" ]; then
                rm -rf "$WORKTREE_DIR" || cleanup_failed=1
            fi
        fi
    else
        log "worktree add was not completed"
    fi

    rm -rf "$TEMP_DIR" || cleanup_failed=1
    log_worktree_state

    if [ "$cleanup_failed" -eq 0 ]; then
        log "cleanup complete"
    else
        log "cleanup complete with fallback errors"
    fi
}

trap cleanup EXIT

if ! command -v critcmp >/dev/null 2>&1; then
    echo "critcmp is required but was not found on PATH."
    echo "Install it with: cargo install critcmp --version 0.1.7"
    exit 2
fi

log "baseline ref: $BASELINE_REF"
log "adding detached worktree"
git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_DIR" "$BASELINE_REF"
WORKTREE_ADDED=1
log_worktree_state

log "running benchmarks for current checkout"
(
    cd "$REPO_ROOT"
    CARGO_TARGET_DIR="$BENCH_TARGET_DIR" cargo bench -- --save-baseline "$CURRENT_BASELINE_NAME" --noplot
)

log "running benchmarks for baseline checkout"
(
    cd "$WORKTREE_DIR"
    CARGO_TARGET_DIR="$BENCH_TARGET_DIR" cargo bench -- --save-baseline "$BASELINE_NAME" --noplot
)

mkdir -p "$CRITCMP_ROOT/target"

if [ ! -d "$BENCH_TARGET_DIR/criterion" ]; then
    echo "Criterion output was not produced under $BENCH_TARGET_DIR/criterion."
    exit 2
fi

cp -R "$BENCH_TARGET_DIR/criterion" "$CRITCMP_ROOT/target/criterion"

log "comparing baselines with critcmp (threshold: ${BENCHMARK_THRESHOLD}%)"
(
    cd "$CRITCMP_ROOT"

    set +e
    output="$(critcmp "$BASELINE_NAME" "$CURRENT_BASELINE_NAME" --threshold "$BENCHMARK_THRESHOLD" 2>&1)"
    status=$?
    set -e

    echo "$output"

    if [ "$status" -eq 0 ]; then
        exit 0
    fi

    if echo "$output" | grep -Fq "no benchmark comparisons to show"; then
        echo "No overlapping benchmark IDs between '$BASELINE_NAME' and '$CURRENT_BASELINE_NAME'; skipping regression gate."
        exit 0
    fi

    exit "$status"
)
