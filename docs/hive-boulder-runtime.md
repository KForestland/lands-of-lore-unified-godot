# Hive boulder surface sequence

`hive_boulder_sequence.gd` isolates the ordered surface callbacks in a small, JSON-safe state machine. It has no scene, asset or external package dependency beyond the shared numeric validator. This lets the same sequence drive live surfaces and deterministic tests without duplicating trigger logic.

The source chain is group6778, ceiling794 completion to6250, then floor1216 completion to6806. The planner closes ceiling794 by128, lowers floors1216/1217/1218 by313, and raises ceiling801 by100 relative to its original height. Translating the entire floor quads preserves the original slopes in1217/1218.

`begin` admits the initial callback once. `advance` returns subsequent callbacks in order, including when a large update crosses both boundaries. `restore` validates a JSON packet before canonicalizing it. Invalid state or delta leaves the input unchanged. Rendering, collision reconstruction and actor callbacks belong to the caller.

The current speeds125/25/50 world units per second are explicit modern clock adapters, not native timing claims. The local Hive scene now uses the sequence through `hive_boulder_surfaces.gd`. It rebuilds adjacent portal walls as heights change with `hive_moving_geometry.gd`, using the existing exporter's interval and original wall-record UV policy. The original sloped floors retain their shape. Grounded entry at region1216 starts the chain; the player rides the actual downward displacement. Surface state participates in Hive saves and Jungle transport. Actor path motion, action9 completion, contact admission/cadence, sounds and final player damage remain open. The encounter is incomplete until those consumers are attached. Opus identified a second native pair scanner as a contact lead; that advisory is not promoted to verified behavior.

Validation: `tests/hive_boulder_sequence_test.gd` passes in Godot headless. It covers one-shot callback order, coarse/fine completion, saves at every phase, JSON restoration, invalid state/delta rejection, slope-preserving offsets and relative exit opening. Run from the project root:

```sh
flatpak run org.godotengine.Godot --headless --path . --script tests/hive_boulder_sequence_test.gd
```

Original textures, sprite sheets and personal saves are not required by this test or `hive_moving_geometry_portable_test.gd`.

Local original-data tests additionally compare every initial affected face, material and UV against the existing Hive export; test the emerging west lower wall and east exit aperture; and exercise the live grounded trigger, floor ride, partial disk rollback, pause, malformed-save rejection, collision rays and Jungle disk roundtrip. The initial comparison test first failed because it mixed integer IDs with JSON float IDs in array membership; using the actual parsed IDs corrected that test. No production geometry was relaxed to satisfy it.

Publication includes the surface controller, portable sequence and geometry helpers/tests. The controller expects the locally staged original-data packet; it is not connected to a scene in the publication branch. Full live scene wiring remains in the working tree with the broader unpublished Act One implementation.

The full96-test Hive run passed95 tests; the sole failure was the small-form route's expected save omitting the new optional checkpoint. Corrected small-form and normal-route tests both pass; all96 latest unique results pass (not a fresh96/96 run). The supplied-start quest walk took70.49 seconds.

An earned continuation from the hash-verified lower Hive fight uses lift stops5/6, jumps to landing303, traverses13 source regions, triggers the descent and walks through the exit. The final instrumented run passes6.58 seconds and verifies actual input/output save hashes. Its natural human-to-lizard transformation restores health through the existing form callback. No position/form/quest/item or healing injection follows load. Earlier campaign legs are reused and the absent boulder hazards mean this is surface-route evidence only. See the adjacent live/earned checks JSON.

A separate pinned relocation audit resolves source actor virtual0 to type2, virtual+D8 to scannerB1FB4, and virtual+DC to pair testB276C. Actual pair geometry/cadence remains unverified; these pointers do not establish final contact damage.
