# Authorization Visualization

The Soroban Debugger provides an authorization visualization tool that makes it easier to understand the authorization trees required by contracts.

## Viewing the Authorization Tree

You can inspect the authorization requirements of a contract execution using the `--show-auth` or `--inspect-auth` flags:

```bash
soroban-debug run \
  --contract contract.wasm \
  --function transfer \
  --args '["GAAA...", "GBBB...", 100]' \
  --show-auth
```

## Understanding the Output

The authorization tree displays:
- **Contract & Function**: The root of the authorization request.
- **Required Auth**: The address that must authorize the action.
- **Status**: Whether the authorization check was performed and passed (`✓ VERIFIED` or `❌ NOT VERIFIED`).
- **Reason**: Why an authorization check failed (e.g., missing `require_auth()` call).

For more details on debugging authorization errors, see the Debug Auth Errors Tutorial.