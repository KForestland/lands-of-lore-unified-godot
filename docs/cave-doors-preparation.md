# Cave door preparation

Run with Python 3 from the source checkout:

```sh
python3 tools/prepare_cave_doors_media.py --game /original/game --texture /fresh/L1_DC/materials/texture.bin --output-root /fresh/door-output
```

Use the published L1_DC material exporter for the texture input. The output root must be fresh and must not overlap either input. The original Cave archive, LOLG.DAT executable data and texture hashes are pinned. No historical generated media or reverse-engineering checkout is required.

The command reconstructs placements 75 and 79, their template children, source material bindings and 101 opening poses per door using the published fixed-point rotation formula and original rotation table. It writes placement.json, motion.json and material/index PNG pairs for descriptors 85 and 470 under assets/lol2/doors. The index PNGs retain the established RGB channel encoding. All six files were verified byte-for-byte against the current runtime pack, including all 202 poses. Isolated generation loaded no native emulation/disassembly modules; existing-output, missing-input, overlapping-output and wrong-texture checks refused.

Placement report checks=2, mismatches=0 and its scope text preserve historical native base-constructor evidence; this command does not rerun that evidence. Coordinates and the executable code-span hash are reconstructed directly from originals. Motion is sampled travel percentage, not native timing. Existing runtime UV mapping, lighting, collision and gameplay behavior are unchanged; this preparation check does not establish new native rendering or gameplay parity. Legacy exporters remain unchanged. Initial review used the wrong executable filename and refused before output; the corrected source reads LOLG.DAT.
