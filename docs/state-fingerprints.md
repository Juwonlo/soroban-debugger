# State Fingerprints

## Overview

The runtime layer in `soroban-debugger` supports generating a deterministic state fingerprint for any given ledger state. The fingerprint provides a quick and stable way to determine if two states are equivalent without manual diffing.

## Determinism

The state fingerprint uniquely represents a given state and is stable across different runs. It avoids any non-deterministic ordering (such as the insertion order of maps) by sorting its data structures canonically before computing the hash.

## What is Included

The state fingerprint calculates a hash of the following data:

1. **Ledger Metadata**: `sequence`, `timestamp`, and `network_passphrase`.
2. **Accounts**: Each account is sorted alphabetically by `address`. The hash includes the address, balance, sequence, flags, and account data (key-value pairs, which are intrinsically sorted via `BTreeMap`).
3. **Contracts**: Each contract is sorted alphabetically by `contract_id`. The hash includes the contract ID, wasm hash, wasm ref, and the full storage (key-value pairs, which are intrinsically sorted via `BTreeMap`).

## How it is Generated

1. A complete `NetworkSnapshot` copy is normalized by sorting the `accounts` and `contracts` slices.
2. The normalized `NetworkSnapshot` is serialized into a compact, whitespace-insensitive JSON format using `serde_json`.
3. A `SHA-256` hash is calculated over the resulting serialized JSON string.
4. The final fingerprint is represented as a lower-case hex-encoded string.

## How to use it for comparison

You can retrieve the fingerprint of a snapshot by invoking the `fingerprint()` method on a `NetworkSnapshot` instance.

```rust
let snapshot = NetworkSnapshot::new(100, "Test Network", 1234567890);

// Get the fingerprint:
let fingerprint = snapshot.fingerprint();

// Compare two states:
if snapshot1.fingerprint() == snapshot2.fingerprint() {
    println!("The states are identical!");
} else {
    println!("The states have differences.");
}
```

This fingerprint will also automatically be displayed whenever two snapshots are diffed using `SnapshotManager::diff_snapshots` or `SnapshotDiff::format_summary()`.
