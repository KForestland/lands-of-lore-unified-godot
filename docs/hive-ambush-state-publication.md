# Hive ambush save state

Two distinct source encounters use an unfolding warrior and a feeding Executioner. This state module preserves their separate animation stages, activation history, health, position, combat clocks and reward RNG through JSON saves. A defeated actor remains defeated after revisiting.

The portable test covers independent clocks, partial animation restoration, activation, saved defeat and malformed state rejection. Run:

```sh
flatpak run org.godotengine.Godot --headless --path . --script res://tests/hive_ambush_state_test.gd
```

Source positions,400/300 health and reward scale8 are independently bound locally. Original clips contain25 unfolding frames and54/17 feeding/transition frames at15fps. Native event/state admission is checked separately; the local next-loop scheduling convention is an explicit adapter. Native scheduling, complete alternate activation paths and visual/combat parity remain open.

This publication includes no original media or personal saves. The asset-dependent live controller and broader Act One integration remain local. This state module does not establish complete encounters or Act One acceptance. The shared save-value helper is identical to the helper used in the other portable state PRs.

The optional `feeding_hit_disabled` field preserves a consumed hit condition. Native Hive owner318 logic suppresses hit-triggered activation; the state helper leaves all animation phases/clocks unchanged. Region contact remains the activation path. Tests cover phases0/1/2, repeated hits and older saves without the optional field. Persisting the consumed record through disk/area travel is a modern adapter; original event-blob lifetime remains open.
