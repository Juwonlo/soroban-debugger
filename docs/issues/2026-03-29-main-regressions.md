# Post-Pull Regression Issues (March 29, 2026)

Branch state after pull: `origin/main` at `4b69c9a`.

## Issue 1: `src/plugin/loader.rs` does not compile (unclosed delimiters)

- Severity: `blocker`
- Repro:
  - Run `cargo test --workspace --all-features --no-run`.
  - Compiler fails with `this file contains an unclosed delimiter` at `src/plugin/loader.rs:665`.
- Evidence:
  - `src/plugin/loader.rs` has a duplicated `#[cfg(test)] impl LoadedPlugin` block starting near line 440.
  - The duplicated block is missing closing braces and bleeds into `check_api_version` and test modules.
  - `test_api_version_check` is missing a closing brace and has broken test-module nesting.

### Implementation Plan

1. Repair structure in `src/plugin/loader.rs`:
   - Remove the duplicated `#[cfg(test)] impl LoadedPlugin` block near the file end.
   - Keep a single `from_parts_for_tests` helper (already present earlier in the file).
   - Ensure `check_api_version` is defined at module scope, not inside an unclosed `impl`.
   - Normalize test module nesting:
     - one `#[cfg(test)] mod tests { ... }`
     - optional inner modules only if fully closed.
2. Fix malformed test function blocks:
   - `test_api_version_check` must have proper `#[test]` and closing braces.
3. Validate:
   - `cargo fmt --all`
   - `cargo test --workspace --all-features --no-run`

### Files To Edit

- `src/plugin/loader.rs`

### Acceptance Criteria

- Rust parser/compile errors are gone.
- `cargo test --workspace --all-features --no-run` passes compile stage.
- Plugin loader tests are discovered and run normally.

## Issue 2: Plugin API version mismatch variant drift (`required` vs `expected`)

- Severity: `high`
- Repro (after fixing Issue 1 syntax blockers):
  - Compile plugin loader code path with `check_api_version`.
  - `PluginError::VersionMismatch` in `api.rs` expects:
    - `required: String`
    - `found: String`
  - `loader.rs` currently constructs:
    - `expected: PLUGIN_API_VERSION`
    - `found: plugin_version`
- Evidence:
  - `src/plugin/api.rs:29`
  - `src/plugin/loader.rs:459-462`

### Implementation Plan

1. Align one canonical shape for `PluginError::VersionMismatch`:
   - Option A: keep string payloads (`required`, `found`) and convert numbers in `loader.rs`.
   - Option B: change enum fields to numeric (`expected: u32`, `found: u32`) and update all call sites.
2. If choosing Option B, update error display string accordingly in `src/plugin/api.rs`.
3. Update tests in `src/plugin/loader.rs` to match final field names/types.
4. Validate:
   - `cargo check --workspace --all-features`
   - `cargo test --workspace --all-features --no-run`

### Files To Edit

- `src/plugin/api.rs`
- `src/plugin/loader.rs`

### Acceptance Criteria

- No type/field mismatch for `VersionMismatch`.
- `check_api_version` returns the agreed error shape.
- Existing plugin API tests pass with the same semantics.

## Issue 3: `tests/symbolic_input_tests.rs` is a placeholder and adds no coverage

- Severity: `medium`
- Repro:
  - Open `tests/symbolic_input_tests.rs`: file only contains comments, no executable tests/assertions.
- Evidence:
  - Current file content is commentary on future testing approach.

### Implementation Plan

1. Replace placeholder with real tests.
2. Preferred approach:
   - Add unit tests in `src/analyzer/symbolic.rs` under `#[cfg(test)]` for private helpers.
   - Keep integration tests in `tests/symbolic_input_tests.rs` for public behavior only.
3. Minimum test cases:
   - deterministic shuffle behavior with identical seeds.
   - distinct behavior with different seeds.
   - input-generation cap behavior (`max_input_combinations` truncation metadata).
   - at least one end-to-end symbolic run that exercises `analyze_with_config`.
4. Validate:
   - `cargo test --workspace --all-features symbolic`

### Files To Edit

- `tests/symbolic_input_tests.rs`
- `src/analyzer/symbolic.rs`

### Acceptance Criteria

- `tests/symbolic_input_tests.rs` contains real assertions.
- Symbolic analyzer path/input generation behavior is covered by deterministic tests.
- Coverage meaningfully increases in symbolic analysis code paths.

## Suggested Execution Order

1. Issue 1 (unblocks compilation).
2. Issue 2 (unblocks plugin API type correctness).
3. Issue 3 (test quality/coverage hardening).
