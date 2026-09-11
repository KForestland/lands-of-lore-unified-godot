# Faster walk and first neighboring ring — 2026-09-11

User feedback: walking felt slow. Walk speed is now 80 original units/s (was 32,
2.5× faster); hold Shift for sprint at 144 units/s. These are usability choices,
not recovered native movement constants. Existing launcher:
`/home/bob/run_lol2_connected_walk.sh`. Restart an existing running view to load changes.

Connected geometry expands from 12 to 21 regions. One ring of ordinary reciprocal
connections with continuous endpoint floor heights is accepted; candidates need
edge length >=32 and centroid distance >=16. Source vertices remain unchanged.
Twelve old outgoing directions add nine unique regions. Eight directions defer
height discontinuities: four rises of 165 units, one drop of 10, three drops of 20.
They have not been flattened or bridged. The generator records each decision in
assets/lol2/generated/original_floors/connected_walk_audit.json.

The area now has 21 ceilings and six provisional interior spans, 24 selected
graph edges, 26 outgoing neighbor directions, and ten internal neighbor directions
outside the selected graph. Amber markers continue to indicate omitted neighbors,
not proof of traversable doorways. Candidate wall and original opening semantics
remain unresolved.

Validation: actual connected scene completes its 79-waypoint spanning-tree tour
at both walk and sprint speeds, with no fall resets. All 119 original local samples
also pass the forward actual-scene sprint check. Smoke navigation caps the last
movement step to remaining waypoint distance to avoid artificial overshoot; manual
input remains full selected speed. GUI capture inspected with updated region count
and Shift instructions. Neither test proves all seams, frame rates or movement
angles, and no native movement-parity claim is made.

```sh
python3 tools/lol2/build_connected_walk.py
flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . res://scenes/lol2/original_walk_review.tscn -- --connected --walk-smoke --sprint-smoke
```

Next: classify the deferred height-change connections and remaining neighboring
regions, then test steps and clearances before extending them. Full cave and
wall texture reconstruction remain incomplete.
