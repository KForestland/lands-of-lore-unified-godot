# Hive boulder surface sequence

`hive_boulder_sequence.gd` isolates the ordered surface callbacks in a small, JSON-safe state machine. It has no scene, asset or external package dependency beyond the shared numeric validator. This lets the same sequence drive live surfaces and deterministic tests without duplicating trigger logic.

The source chain is group6778, ceiling794 completion to6250, then floor1216 completion to6806. The planner closes ceiling794 by128, lowers floors1216/1217/1218 by313, and raises ceiling801 by100 relative to its original height. Translating the entire floor quads preserves the original slopes in1217/1218.

`begin` admits the initial callback once. `advance` returns subsequent callbacks in order, including when a large update crosses both boundaries. `restore` validates a JSON packet before canonicalizing it. Invalid state or delta leaves the input unchanged. Rendering, collision reconstruction and actor callbacks belong to the caller.

The current speeds125/25/50 world units per second are explicit modern clock adapters, not native timing claims. The module is not yet attached to the playable scene: adjacent portal walls must be rebuilt as heights change. Actor path motion, action9 completion, contact admission/cadence and final player damage remain open. Opus identified a second native pair scanner as a contact lead; that advisory is not promoted to verified behavior.

Validation: `tests/hive_boulder_sequence_test.gd` passes in Godot headless. It covers one-shot callback order, coarse/fine completion, saves at every phase, JSON restoration, invalid state/delta rejection, slope-preserving offsets and relative exit opening. Run from the project root:

```sh
flatpak run org.godotengine.Godot --headless --path . --script tests/hive_boulder_sequence_test.gd
```

Original textures, sprite sheets and personal saves are not required by this test.
