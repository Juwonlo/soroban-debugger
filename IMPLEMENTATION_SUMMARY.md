# Implementation Summary: Storage-Seeded Symbolic Execution

## Issue #523: Symbolic execution: support storage-seeded exploration from snapshots or imported state

### Overview
This implementation adds support for storage-seeded symbolic execution, allowing the symbolic analyzer to start from pre-existing storage states rather than just exploring function input combinations. This addresses a critical gap where many real-world bugs depend on ledger state rather than just argument values.

### Changes Made

#### 1. CLI Arguments (`src/cli/args.rs`)
- **Added**: `storage_seed: Option<PathBuf>` field to `SymbolicArgs` struct
- **Purpose**: Allows users to specify a JSON file containing initial storage state
- **Documentation**: Includes clear help text explaining the feature and expected JSON format

#### 2. Symbolic Analyzer Configuration (`src/analyzer/symbolic.rs`)
- **Added**: `storage_seed: Option<String>` field to `SymbolicConfig` struct
- **Updated**: All config builder methods (`fast()`, `balanced()`, `deep()`) to initialize the new field
- **Modified**: `analyze_with_config()` method to apply storage seed before executing each path
- **Implementation**: Uses existing `ContractExecutor::set_initial_storage()` method to seed state
- **Test**: Added unit test `analyze_with_storage_seed_uses_initial_state()` to verify configuration

#### 3. Command Handler (`src/cli/commands.rs`)
- **Added imports**: `SymbolicConfig` and `SymbolicProfile` to scope
- **Modified**: `symbolic_config_from_args()` function to:
  - Read storage seed file if provided
  - Handle file read errors gracefully with user-friendly error messages
  - Pass storage JSON to config for use by analyzer

#### 4. Integration Tests (`tests/symbolic_storage_seed_tests.rs`)
- **Created**: New test file with comprehensive test coverage
- **Tests included**:
  - `symbolic_execution_with_storage_seed()`: Verifies storage seeding works end-to-end
  - `symbolic_execution_without_storage_seed()`: Ensures backward compatibility
- **Fixture usage**: Uses existing counter contract fixture for realistic testing

#### 5. Documentation (`man/man1/soroban-debug-symbolic.1`)
- **Updated**: SYNOPSIS section to include `--storage-seed` option
- **Added**: Complete option description in OPTIONS section
- **Enhanced**: DESCRIPTION to mention storage state seeding capability

#### 6. Test Script (`test_storage_seed_feature.sh`)
- **Created**: Automated verification script for the feature
- **Checks**: All code changes, tests, and documentation updates
- **Purpose**: Quick validation that all components are present

### Technical Details

#### How It Works
1. User provides a JSON file via `--storage-seed storage.json`
2. CLI reads and parses the file into a JSON string
3. Config is updated with the storage seed
4. For each symbolic execution path:
   - A fresh `ContractExecutor` is created
   - Storage seed is applied via `set_initial_storage()`
   - Function is executed with the generated inputs
   - Results include the effect of both storage state and inputs

#### Storage JSON Format
```json
{
    "key1": "value1",
    "counter": 42,
    "owner": "GABC...DEF"
}
```

The format supports the same typed annotations as the existing `--storage` parameter:
```json
{
    "counter": {"type": "i64", "value": 42},
    "balance": {"type": "u64", "value": 1000000}
}
```

#### Error Handling
- File not found: Clear error message and exit
- Invalid JSON: Propagated from `set_initial_storage()` with context
- Executor errors: Wrapped with descriptive messages

### Acceptance Criteria Met

✅ **Symbolic analysis can start from seeded storage/snapshots**
- Implemented via `--storage-seed` flag
- Storage is applied before each path exploration

✅ **Tests added/updated**
- Unit test in `symbolic.rs`
- Integration tests in `symbolic_storage_seed_tests.rs`

✅ **User-facing docs updated**
- Manpage updated with new option
- Help text in CLI args

### Usage Examples

#### Basic Usage
```bash
soroban-debug symbolic \
  -c my_contract.wasm \
  -f transfer \
  --storage-seed initial_state.json
```

#### With Other Options
```bash
soroban-debug symbolic \
  -c my_contract.wasm \
  -f my_function \
  --storage-seed state.json \
  --profile deep \
  --seed 42 \
  -o report.toml
```

#### Example Storage Seed File
```json
{
  "balances": {
    "user1": 1000,
    "user2": 500
  },
  "total_supply": 1500,
  "paused": false
}
```

### Backward Compatibility
- ✅ No breaking changes to existing API
- ✅ `storage_seed` defaults to `None` (no change in behavior)
- ✅ Existing symbolic execution runs unaffected
- ✅ All existing tests remain valid

### Files Modified
1. `src/cli/args.rs` - Added storage_seed argument
2. `src/analyzer/symbolic.rs` - Added storage seed support to analyzer
3. `src/cli/commands.rs` - Added storage seed loading and passing
4. `man/man1/soroban-debug-symbolic.1` - Updated documentation
5. `tests/symbolic_storage_seed_tests.rs` - New integration tests
6. `test_storage_seed_feature.sh` - Verification script

### Testing Strategy
- **Unit tests**: Verify config accepts and stores storage seed
- **Integration tests**: End-to-end testing with real contracts
- **Manual testing**: Verified with counter contract example
- **Regression testing**: Existing tests ensure no breakage

### Future Enhancements
Potential improvements for future iterations:
- Support for loading storage from snapshot files (NetworkSnapshot format)
- Multiple storage seeds in a single run for batch comparison
- Storage state generation/synthesis for edge cases
- Integration with debugger's storage snapshot/restore features

### Conclusion
This implementation successfully addresses issue #523 by enabling symbolic execution to explore contract behavior under different storage states, uncovering bugs that depend on ledger state rather than just function inputs. The feature is fully tested, documented, and maintains backward compatibility.
