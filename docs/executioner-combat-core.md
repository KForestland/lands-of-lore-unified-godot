# Executioner combat core

This update publishes a reusable combat component and an asset-free contract test.
It does **not** connect a new enemy to the playable scene or complete Classic Edition.
Functionality remains the priority; UI polish and LoL3 follow later.

## Included behavior

`hive_attack_runtime.gd` implements native-unit animation countdown, forward/reverse
traversal, frame events, attack gates, damage requests, synchronous nonlethal feedback,
ordered stat adjustments and version2 snapshots with version1 migration. Invalid
snapshots/replies are rejected; a failed reply restores the component's pre-update
state. Feedback resolvers must return data only, without external side effects.

The native findings behind this component are documented in the
[LoL2 research repository](https://github.com/KForestland/lands-of-lore-2-re).
The local research pass checked 65,536 damage-split inputs, 65,536 signed stat-change
pairs, source CSV parsing, constructor branches and native attack-event composition.
Those local checks are distinct from the synthetic portable test included here.

## Test from a clean checkout

With Godot available as `godot`:

```sh
godot --headless --path . --script res://tests/hive_attack_portable_test.gd
```

For the Flatpak installation, replace `godot` with
`flatpak run org.godotengine.Godot`. This pass was tested with Godot4.7.2.
The synthetic test uses no original game files or generated asset directories.
It checks event ordering, zero-time behavior, successful feedback, failed-second-hit
rollback, snapshot migration, frozen updates, independent contracts and clamped stats.

## Integration contract

Pass a dictionary to `Runtime.new(contract)` with `version: 1` and two `clips`
entries for selectors11/12. Each clip has `frames`, positive native `interval`, and
an `events` array; the included test demonstrates the schema. Contract data is trusted
caller configuration and is copied on initialization. The default constructor loads
`assets/lol2/generated/hive_attack/attack.json` only when no dictionary is supplied.

`advance_native(delta, resolver)` accepts integer native deltas0..32767. The optional
synchronous resolver receives a copied damage request and returns unsigned32-bit
`loss`, `remaining` and `percentage`; remaining must be positive. It must not perform
external mutations. Check for `error` before consuming returned events. Sound,
terminal and adjustment notifications still require caller handling.

`apply_stat_adjustments(stats, rows, events)` applies supplied signed rows7/8 to a
30-byte bank, in event order, without changing the inputs. The source-specific
convenience methods expect locally generated `adjustments.json` and
`initial_stats.json`; these extracted data files and their local generation workflow
are not part of this publication. They return an error when those files are absent.

## Remaining work

- Bind the constructor A3 condition and later attack-stat recomputation.
- Establish the native clock-to-seconds conversion and live AI admission.
- Compose target mitigation, health loss, lethal continuation and queue effects.
- Connect the component and stat bank to the scene and shared player saves.

The generated source-backed regression fixtures and original game assets remain
local. This commit contains only code, an authored test and documentation.
