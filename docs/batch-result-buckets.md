# Batch Result Buckets

When running a large number of test cases using the batch execution feature, it's important to quickly understand the outcomes. The Soroban Debugger categorizes batch results into distinct buckets to provide a clear, at-a-glance summary.

## Result Buckets

Each test case in a batch run is classified into one of the following buckets:

- **Passed**: The execution completed successfully, and the result matched the `expected` value (if provided).
- **Failed**: The execution completed successfully, but the result did **not** match the `expected` value.
- **Panicked**: The contract execution was aborted due to a panic (e.g., `panic!`, `require!` failure, or a trap).
- **TimedOut**: The execution for this test case exceeded the configured timeout.
- **Skipped**: The test case was not run, typically because a preceding setup step failed.
- **Error**: The debugger encountered an error before or during execution that was not a contract panic (e.g., argument parsing error, setup failure).

## Summary Output

The pass/fail summary at the end of a batch run now includes counts for each of these buckets, allowing for rapid triaging.

### Example Summary

```
================================================================================
  Summary
================================================================================
  Total:      100
  Passed:     95
  Failed:     2
  Panicked:   1
  TimedOut:   1
  Skipped:    0
  Errors:     1
  Duration:   1.25s
================================================================================
```

This enhanced summary immediately tells you not just *that* failures occurred, but *what kind* of failures they were, helping you focus your debugging efforts more effectively.