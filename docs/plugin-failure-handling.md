# Plugin Failure Handling

The Soroban debugger treats plugins as extensions, not as part of the trusted
execution core.

## What Counts As A Plugin Incident

The debugger currently escalates these plugin-specific incidents:

- plugin panics,
- plugin invocation timeouts.

Regular plugin-returned errors are still reported, but they do not
automatically count as crash-isolation incidents.

## What Happens On Incident

When a plugin panics or exceeds its execution budget:

1. the incident is captured and classified as a plugin-layer failure,
2. the affected plugin is disabled for the current process/session,
3. the core debugger continues running,
4. a structured incident report is emitted through logging and telemetry.

This is intentionally explicit so users are not misled into thinking that a
plugin crash means the Soroban debugger itself became unstable.

## Session Disablement

Session disablement is intentionally conservative:

- a panicking plugin is disabled immediately,
- a timed-out plugin is disabled immediately,
- subsequent invocations are skipped for the rest of the session.

This keeps the debugger usable while preventing repeated plugin failures from
polluting the debugging experience.

## Incident Report Contents

Each report includes:

- plugin name,
- plugin version when available,
- plugin library path when available,
- invocation kind (`hook`, `command`, or `formatter`),
- incident type (`panic` or `timeout`),
- action taken,
- an explicit statement that the core debugger remains available.

## Why This Matters

Plugins are powerful, but they should never blur the trust boundary.

Clear incident reporting helps users answer two separate questions quickly:

- Did the plugin fail?
- Is the core debugger still trustworthy?

The expected answer after a contained incident is:

- yes, the plugin failed,
- yes, the core debugger is still available.
