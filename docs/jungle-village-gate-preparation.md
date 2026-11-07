# Jungle village gate preparation

```sh
python3 tools/prepare_jungle_village_gate_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow, the published material exporter/profile, face-order constants and rotation helper. The original Jungle archive/geometry and reconstructed rotation table are pinned. The output must be absent and cannot overlap the game. Computation and temporary material export complete before output creation.

This prepares the complete three-file jungle_village runtime pack from original movable78/79 placement rows, template6/5 child records, region2443 and freshly exported materials514/742. Initial-mode masks select the same four/five closed faces as the shared movable exporter. Quarter-turn inversion and the published integer rotation formula reproduce all101 hinge poses per leaf, preserving face order, UVs and materials. Admission predicate rows and region/group4354 gate commands are checked directly.

Independent isolated preparation matched all three existing files byte for byte, including202 leaf poses. No native/RE modules loaded. Four refusal controls covered existing output, missing originals, input overlap and incorrect Jungle archive.

The legacy prepare_jungle_village.py and docs/jungle-village-source.json remain unchanged. That document contains historical native predicate/emission replay evidence; this command does not regenerate it or claim a new native replay. Modern timing/collision and gameplay admission behavior are unchanged. Whole clean assembly and gameplay/platform acceptance remain separate gates.
