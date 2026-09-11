# Full recovered cave walk — 2026-09-11

User requested whole-map assembly instead of incremental area expansion.
Launch `/home/bob/run_lol2_full_cave.sh`.

- WASD + mouse: walk/look; Shift: sprint (80 / 144 original units per second).
- F: toggle collision-free inspection flight, at four times movement speed.
- Space/Ctrl: ascend/descend in flight.
- N/P: jump among 119 checkpoint starts without reloading the map.
- R: reset to current start and return to walking. Escape releases the mouse;
  left-click captures it. Reset also recovers from entering geometry during flight.

All 1,953 recovered floor polygons, 1,939 ceilings, 1,338 boundary quads and
955 provisional interior spans are loaded in one original-unit coordinate frame.
This includes subdivision floor polygons. Twenty-eight neighbor edges on special
connector regions are marked amber; markers do not establish native connector
behavior. Original coordinates are translated by [-4, -430, -12794], not rescaled.
The fall reset threshold is below the lowest recovered floor, allowing movement
to cave elevations below the original spawn. Default spawn stays in the familiar
rock-floor area. Pink surfaces have unresolved material bindings.

Floor textures are cached per material, and geometry is batched per material
instead of one draw mesh per face. A white ambient inspection light makes neutral
shell geometry visible. Camera far plane is 30,000 units for full-map inspection.
Lighting, floor UVs, player size and motion are provisional, not native parity.

Validation in Godot 4.7.2: the existing continuous 79-waypoint sprint tour passed
with all world geometry present; the full-map checkpoint smoke then jumped to
and traversed all 119 checkpoint routes at sprint speed with zero fall resets.
Those sampled routes are not exhaustive whole-map traversal proof. The final
GUI capture was rendered and inspected (captures/full_walk_review.png). Flight
and keyboard feel have not been manually gameplay-tested. The original game
files were not changed.

```sh
python3 tools/lol2/build_full_walk.py
flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . res://scenes/lol2/original_walk_review.tscn -- --full-map --checkpoint-smoke --sprint-smoke
```

Generator inputs: floors.json, connected_walk.json, traversal_expanded.json and
geometry_v2.json. Outputs: generated/original_floors/full_walk.json and
full_walk_audit.json beneath assets/lol2. Earlier local and connected launchers
remain usable. This is the whole recovered static layout, not a completed 1:1
restoration: native wall textures/UV closure, special opening geometry, animated
surfaces, doors/objects/actions, hazards and sounds remain. Next work should
improve full-map fidelity directly rather than continue adding region rings.
