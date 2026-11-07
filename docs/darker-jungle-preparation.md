# Darker-Jungle arrival preparation

Rebuild the complete existing Act 1 destination pack from the supported original installation:

```sh
python3 tools/prepare_darker_jungle_portable.py --game-root /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re --output-root /path/to/fresh-output
```

The command generates geometry, materials, scenery and assembly reports beneath `tmp/darker_jungle`, then writes `assets/lol2/generated/darker_jungle`. It does not read historical generated maps. Output must be a new directory outside the original game, RE helper tree and installed tools. Later decoder failures can leave partial output; retain it for diagnosis.

Use the RE helper closure documented in [movable preparation](map-movables-preparation.md), plus `tools/draracle/lol2_verify_flat_wall_spans.py`, all from revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`. Python, Pillow, NumPy, Capstone and the system liblzo2 decoder are required. Original `LOLG.DAT` and `DAT/L8_SJ.MIX` are hash-checked. Rotation comes from the supplied executable. The source checkout supplies geometry profiles and the decoding/assembly tools. No original media or generated maps belong in the source repository.

The pipeline reconstructs base surfaces, initial static props, type0 assembly faces and type1 attached scenery. It retains the existing emulated isolated-sector boundaries, front orientation, sector-light and sector-membership fields used by the arrival pack. Boundary emulation remains explicitly distinct from recovered native wall behavior. The intermediate review is serialized before staging so animation dictionaries do not share path-rewrite mutations.

An independent fresh command run reproduced all 251 shipped files byte-identically: 250 PNGs and `area.json`, including 13,003 faces, 1,767 scenery instances, 206 material bindings and 12 animations. Existing-output, missing-game and overlapping-input controls refused without modifying output. The earlier component checks also covered all ten Act 1 area/placement-kind attached-scenery exports.

This is the existing saved darker-Jungle arrival boundary. It does not add Act 2 gameplay, source sky, advanced dynamic lighting, prop-shadow composition, interactions or alternate-state behavior. It does not complete preparation of every other Act 1 pack. The historical `prepare_darker_jungle.py` entry point remains unchanged; use the explicit command above for clean preparation. The assembly helpers' historical standalone entry points may still require research workspace inputs; this recipe calls their explicit library interfaces.
