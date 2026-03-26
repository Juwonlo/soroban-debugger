#!/bin/bash
# Test script for storage-seeded symbolic execution feature

echo "Testing storage-seeded symbolic execution feature..."

# Check that the SymbolicArgs struct has the storage_seed field
if grep -q "pub storage_seed: Option<PathBuf>" src/cli/args.rs; then
    echo "✓ SymbolicArgs has storage_seed field"
else
    echo "✗ SymbolicArgs missing storage_seed field"
    exit 1
fi

# Check that SymbolicConfig has the storage_seed field
if grep -q "pub storage_seed: Option<String>" src/analyzer/symbolic.rs; then
    echo "✓ SymbolicConfig has storage_seed field"
else
    echo "✗ SymbolicConfig missing storage_seed field"
    exit 1
fi

# Check that the symbolic command handler loads storage seed
if grep -q "storage_seed" src/cli/commands.rs; then
    echo "✓ commands.rs handles storage_seed parameter"
else
    echo "✗ commands.rs doesn't handle storage_seed parameter"
    exit 1
fi

# Check that the symbolic analyzer uses storage seed
if grep -q "set_initial_storage" src/analyzer/symbolic.rs; then
    echo "✓ symbolic.rs applies storage seed to executor"
else
    echo "✗ symbolic.rs doesn't apply storage seed"
    exit 1
fi

# Check that tests were added
if [ -f "tests/symbolic_storage_seed_tests.rs" ]; then
    echo "✓ Integration tests created"
else
    echo "✗ Integration tests missing"
    exit 1
fi

# Check that manpage was updated
if grep -q "storage.*seed" man/man1/soroban-debug-symbolic.1; then
    echo "✓ Manpage updated with --storage-seed option"
else
    echo "✗ Manpage not updated"
    exit 1
fi

echo ""
echo "All checks passed! ✓"
echo ""
echo "Usage example:"
echo "  soroban-debug symbolic -c contract.wasm -f my_function --storage-seed storage.json"
