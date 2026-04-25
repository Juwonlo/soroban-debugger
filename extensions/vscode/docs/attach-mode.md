# Attach Mode: Remote Debugging Guide

The `attach` request type in your `launch.json` allows the VS Code extension to connect to an existing `soroban-debug server` rather than spawning its own local backend. This is particularly useful for debugging contracts running in a CI sandbox, inside a Docker container, or on a remote development machine.

## Configuration Fields

When `request` is set to `"attach"`, the following fields are evaluated:

| Field | Required | Description | Common Fixes |
|-------|----------|-------------|--------------|
| `host` | No | The hostname or IP address of the target server. Defaults to `127.0.0.1`. | If connection refuses, check if the server bound to `0.0.0.0` instead of `127.0.0.1` or if a firewall blocks the port. |
| `port` | Yes | The TCP port the target server is listening on. | Ensure this exactly matches the `--port` flag passed to the server. |
| `token` | No | The authentication token for the server. | If you get a "Protocol/Auth Error", ensure this matches the server's `--token` flag. |
| `contractPath` | Yes | The local path to the compiled WASM contract file. | Must be the exact same WASM file being executed by the server to ensure source maps and breakpoints align. |
| `tlsCert` / `tlsKey` | No | Paths to TLS materials if the server requires mutual TLS. | Ensure both are provided if TLS is enforced by the remote server. |
| `connectTimeoutMs` | No | Maximum time to wait for the connection to establish (default 10000ms). | Increase if connecting to a high-latency remote host. |

## Common Failure Scenarios

### Connection Refused (`ECONNREFUSED`)
**What it means:** The extension couldn't reach the server at the specified `host` and `port`.
**How to fix:**
1. Verify the server is actually running: `netstat -an | grep <port>`.
2. Check if the server is bound to localhost (`127.0.0.1`) but you are trying to reach it from an external IP. Start the server with `--host 0.0.0.0` if you need external access.
3. Ensure no local firewalls are blocking the outbound or inbound traffic.

### Authentication Rejected
**What it means:** The server received the connection but rejected the `token`.
**How to fix:** Check the `token` field in your `launch.json`. It must perfectly match the `--token` argument provided when the server was started.

### Timeouts (`ETIMEDOUT` or Protocol Timeout)
**What it means:** The network dropped the packets, or the server is deadlocked/overloaded.
**How to fix:** Increase `connectTimeoutMs` in your `launch.json`. If it still fails, check the server logs for panics or crashes.

### Breakpoints Not Binding (Unverified)
**What it means:** You are attached, but breakpoints show as gray hollow circles.
**How to fix:** Your local `contractPath` might point to a differently compiled WASM than the server is executing. Ensure you are debugging the exact same build artifact.

## Security Warning
If you are attaching to a server over a public or untrusted network, **always** use TLS (`tlsCert`, `tlsKey`) or tunnel the connection securely through SSH (`ssh -L <local-port>:localhost:<remote-port> user@remote`). The debugging protocol sends contract data and memory state in plaintext unless TLS is configured.