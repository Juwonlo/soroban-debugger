# Scenario Step Tags and Annotations

## Overview

Large scenario files can sometimes become hard to reason about as steps accumulate. To add lightweight categorization and ownership metadata, `soroban-debugger` allows you to annotate scenario steps with tags and notes. 

This enables you to clearly communicate which steps are meant for `setup`, `validation`, `smoke` testing, or are `expensive` / `release-critical`.

## Syntax

You can add `tags` (an array of strings) and `notes` (a string) to any `[[steps]]` block in your scenario TOML file.

```toml
[[steps]]
name = "Initialize Environment"
function = "init"
tags = ["setup", "core"]
notes = "This step must always run first to set the admin account."

[[steps]]
name = "Expensive Calculation"
function = "compute"
tags = ["expensive", "math"]
notes = "Takes several seconds; excluded during fast CI runs."

[[steps]]
name = "Smoke Test Flow"
function = "verify"
tags = ["smoke"]
```

## Running Tagged Scenarios

The `soroban-debug scenario` command includes two flags to filter the executed steps based on their tags:

- `--tags <TAGS>`: Comma-separated list of tags. If provided, *only* steps containing at least one of these tags will be executed.
- `--exclude-tags <TAGS>`: Comma-separated list of tags. If provided, steps containing *any* of these tags will be skipped.

### Examples

**Only run setup and smoke tests:**
```bash
soroban-debug scenario --scenario my_scenario.toml --contract my_contract.wasm --tags setup,smoke
```

**Run everything except expensive tests:**
```bash
soroban-debug scenario --scenario my_scenario.toml --contract my_contract.wasm --exclude-tags expensive
```

During execution, any skipped steps will be logged as skipped, and the notes and tags of executed steps will be cleanly printed to the console to improve operational visibility.
