# Bacatta village door preparation

```sh
python3 tools/prepare_jungle_bacatta_gate_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow and the published material exporter/profile, face-order constants and rotation helper. Original Jungle archive/geometry and rotation table are pinned. Output must be absent and cannot overlap the game. Computation and temporary material export finish before output creation.

The complete three-file jungle_bacatta57 runtime pack is reconstructed from movable56/57, template82 children, source command group10162 and freshly exported materials66/92. Initial-mode masks select41 faces per leaf. The source hinge calculation reproduces101 poses per leaf and verifies the closed endpoint gap below6 source units. All three files independently match the existing pack byte for byte, including every face, UV and material binding. Isolated generation loaded no native/RE modules; four refusal controls cover existing output, missing originals, overlap and incorrect archive.

The legacy prepare_jungle_bacatta57.py and existing jungle_bacatta57_source.json/population contracts are unchanged; this command prepares runtime door media only, rather than regenerating the actor/quest evidence. Existing modern timing/collision behavior is retained. No native pushing/crushing replay is claimed. Whole clean assembly and final acceptance remain separate gates.
