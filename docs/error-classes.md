# Runtime Error Classes

The Soroban Debugger categorizes execution failures into four distinct classes. This makes it easier to determine whether a failure is a bug in the contract, a misconfiguration in the environment, or an internal problem.

## Error Classes

### 1. Contract Panic (`ContractPanic`)
**What it is:** The contract explicitly aborted execution or triggered a runtime panic due to logic errors.
**Common Causes:**
- `panic!` macros in Rust.
- Unwrapping `None` or `Err`.
- Out-of-bounds array access.
- User-defined errors returned by the contract.
**Resolution:** Fix the contract logic. Check the debugger trace or backtrace to find the exact line causing the panic.

### 2. Host Error (`HostError`)
**What it is:** The Soroban host environment rejected an operation performed by the contract.
**Common Causes:**
- Exceeding CPU or memory budgets.
- Missing authorization (`require_auth` failure).
- Invalid storage access.
- Cryptographic operation failures.
**Resolution:** Review the host constraints and ensure the contract interacts with the environment correctly. Inspect the specific `ScErrorType` for more details.

### 3. Environment Setup (`EnvironmentSetup`)
**What it is:** The debugger failed to initialize the execution environment before running the contract.
**Common Causes:**
- Missing or malformed snapshot file.
- Missing ledger sequence or network configuration.
- Host context state setup issues.
**Resolution:** Ensure your `snapshot.json` and network configurations are valid and correctly loaded.

### 4. Parser Problem (`ParserProblem`)
**What it is:** The debugger failed to parse arguments, WASM bytes, or other inputs.
**Common Causes:**
- Invalid argument format (e.g., malformed JSON).
- Corrupted or incompatible WASM artifact.
- Unrecognized CLI flags.
**Resolution:** Verify that the arguments match the expected types and that the WASM file is compiled correctly for the `wasm32-unknown-unknown` target.

## Summary

By distinguishing between these classes, the debugger helps you focus your troubleshooting efforts on the right layer: the contract code (`ContractPanic`), the interaction with the blockchain (`HostError`), the testing setup (`EnvironmentSetup`), or the input data (`ParserProblem`).