# Plugin Hot-Reload Diff Implementation

## Summary

Implemented a feature to show clear diffs when plugins are hot-reloaded, making it easier for developers to verify reload results during iterative plugin development.

## Changes Made

### 1. Core Implementation (`src/plugin/registry.rs`)

#### New Structures

- **`PluginSnapshot`**: Captures plugin state at a point in time
  - Name, version, capabilities, commands, formatters, dependencies
  
- **`PluginReloadDiff`**: Represents changes detected during reload
  - Version changes (old → new)
  - Capability changes (enabled/disabled)
  - Commands added/removed
  - Formatters added/removed
  - Dependencies added/removed

#### Modified Functions

- **`reload_plugin()`**: Now returns `PluginResult<PluginReloadDiff>` instead of `PluginResult<()>`
  - Captures plugin state before reload
  - Captures plugin state after reload
  - Computes diff between states
  - Emits concise summary to logs

#### Key Features

- **Automatic change detection**: Tracks all plugin metadata changes
- **Sorted output**: All lists (commands, formatters, dependencies) are sorted for consistent output
- **Concise summaries**: Human-readable format showing only what changed
- **No changes detection**: Special message when plugin reloads with no changes

### 2. Module Exports (`src/plugin/mod.rs`)

- Exported `PluginReloadDiff` type for use by other modules

### 3. Documentation Updates

#### `src/plugin/README.md`

Added section on "Hot-Reload with Change Detection" explaining:
- What changes are detected
- Example reload output
- Benefits for iterative development

#### `docs/plugin-api.md`

Enhanced "Hot-Reload Support" section with:
- Detailed explanation of change detection
- Example outputs for various scenarios
- Benefits for plugin developers

### 4. Comprehensive Tests (`src/plugin/registry.rs`)

Added 8 new test cases:
- `reload_diff_detects_version_change`
- `reload_diff_detects_capability_changes`
- `reload_diff_detects_added_and_removed_commands`
- `reload_diff_detects_added_and_removed_formatters`
- `reload_diff_detects_dependency_changes`
- `reload_diff_reports_no_changes_when_identical`
- `reload_diff_summary_is_concise_and_readable`

## Example Output

### With Changes
```
Plugin 'example-logger' reload changes:
  Version: 1.0.0 → 1.1.0
  Capabilities:
    provides_commands: false → true
  Commands added: log-stats, clear-log
  Formatters added: json-formatter
  Dependencies added: helper-plugin
```

### No Changes
```
Plugin 'example-logger' reloaded with no changes
```

## Acceptance Criteria Met

✅ Plugin reloads emit a concise diff of added, removed, and changed capabilities  
✅ Developers can verify the reload result immediately  
✅ Tests are added for the changed behavior  
✅ User-facing docs are updated

## Files Modified

1. `src/plugin/registry.rs` - Core implementation
2. `src/plugin/mod.rs` - Module exports
3. `src/plugin/README.md` - User documentation
4. `docs/plugin-api.md` - API documentation

## Technical Details

### Diff Computation Algorithm

1. Compare versions (string equality)
2. Compare each capability field (boolean equality)
3. Convert command/formatter/dependency lists to HashSets
4. Compute set differences for added/removed items
5. Sort all result lists for consistent output

### Display Format

- Uses `Display` trait implementation for easy printing
- Hierarchical indentation for readability
- Only shows sections with changes
- Special handling for "no changes" case

## Benefits

1. **Immediate feedback**: Developers know instantly what changed
2. **Trust**: Clear verification that changes were loaded correctly
3. **Debugging**: Easier to spot unintended changes or regressions
4. **Documentation**: Reload output serves as a change log

## Future Enhancements

Potential improvements for future iterations:
- Colorized output for better visual distinction
- Detailed command/formatter signature changes
- Performance metrics (reload time)
- Rollback capability on failed reloads
