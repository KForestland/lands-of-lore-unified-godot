# Jungle inner-gate preparation

```sh
python3 tools/prepare_jungle_inner_gate_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow and the published material exporter/profile, face-order constants and rotation helper. Original Jungle archive/geometry and rotation table are pinned. Output must be absent and cannot overlap the game. Computation and temporary material export finish before output creation.

This reconstructs the complete three-file jungle_inner_gate pack from movable74/75, template43 child records and fresh materials522/742. Both leaves contain four faces and101 poses; the original world-space hinge formula and closed-position gap are retained. Five original command groups5160/21138/21156/27916/27934 are checked. All three files independently match the existing runtime pack byte for byte, including vertices, UVs and material bindings.

Isolated generation loaded no native/RE modules. Four refusal controls covered existing output, missing originals, overlap and incorrect archive. The legacy prepare_jungle_inner_gate.py and scripts/lol2/jungle_inner_gate_source.json remain unchanged; this command prepares runtime media without regenerating the owner/predicate contract. Existing timing/collision behavior is retained. Whole clean assembly and final acceptance remain separate gates.
