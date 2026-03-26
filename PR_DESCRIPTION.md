# Fix Issue #523: Add Storage-Seeded Symbolic Execution Support

## Description

This PR implements storage-seeded symbolic execution, addressing the gap where many real-world contract bugs depend on ledger state rather than just function input combinations.

### Problem Statement
Current symbolic exploration focuses on function inputs, but many critical bugs depend on pre-existing storage and ledger state. Without the ability to seed storage state, symbolic execution cannot explore important code paths that are only reachable under specific storage conditions.

### Solution
Added `--storage-seed` flag to the `symbolic` command that accepts a JSON file containing initial storage state. This storage is applied before exploring each symbolic path, allowing comprehensive testing of state-dependent behavior.

## Changes

### Core Implementation
- **src/cli/args.rs**: Added `storage_seed` field to `SymbolicArgs`
- **src/analyzer/symbolic.rs**: 
  - Added `storage_seed` field to `SymbolicConfig`
  - Modified `analyze_with_config()` to apply storage seed before path exploration
  - Added unit test for storage seed configuration
- **src/cli/commands.rs**: 
  - Updated imports to include `SymbolicConfig` and `SymbolicProfile`
  - Modified `symbolic_config_from_args()` to load and validate storage seed file

### Testing
- **tests/symbolic_storage_seed_tests.rs**: New integration tests
  - Test with storage seed
  - Test without storage seed (backward compatibility)
- **test_storage_seed_feature.sh**: Automated feature verification script

### Documentation
- **man/man1/soroban-debug-symbolic.1**: Updated manpage with new option
- Help text added to CLI argument parser

## Usage

### Basic Example
```bash
soroban-debug symbolic \
  -c my_contract.wasm \
  -f transfer \
  --storage-seed initial_state.json
```

### Storage Seed File Format
```json
{
  "counter": 41,
  "owner": "GABC...DEF",
  "balances": {
    "user1": 1000,
    "user2": 500
  }
}
```

### Advanced Usage
```bash
soroban-debug symbolic \
  -c contract.wasm \
  -f my_function \
  --storage-seed state.json \
  --profile deep \
  --seed 42 \
  -o report.toml
```

## Acceptance Criteria

✅ Symbolic analysis can start from seeded storage states  
✅ Tests added for new functionality  
✅ User-facing documentation updated  
✅ Backward compatible (no breaking changes)  

## Testing

All verification checks pass:
```bash
./test_storage_seed_feature.sh
```

Output:
```
✓ SymbolicArgs has storage_seed field
✓ SymbolicConfig has storage_seed field
✓ commands.rs handles storage_seed parameter
✓ symbolic.rs applies storage seed to executor
✓ Integration tests created
✓ Manpage updated with --storage-seed option

All checks passed! ✓
```

## Backward Compatibility

- ✅ No breaking changes
- ✅ `storage_seed` defaults to `None`
- ✅ Existing runs unaffected
- ✅ All existing tests remain valid

## Related Issues

Fixes #523

## Files Changed

1. `src/cli/args.rs` - CLI argument definition
2. `src/analyzer/symbolic.rs` - Core symbolic execution logic
3. `src/cli/commands.rs` - Command handler
4. `man/man1/soroban-debug-symbolic.1` - Documentation
5. `tests/symbolic_storage_seed_tests.rs` - Integration tests (new)
6. `test_storage_seed_feature.sh` - Verification script (new)
7. `IMPLEMENTATION_SUMMARY.md` - Detailed implementation notes (new)

## Notes

The implementation leverages the existing `ContractExecutor::set_initial_storage()` method, ensuring consistency with other debugger features like `run` and `replay` that support storage seeding.

Future enhancements could include:
- Support for NetworkSnapshot format
- Multiple storage seeds for batch comparison
- Automatic storage state synthesis for edge cases
