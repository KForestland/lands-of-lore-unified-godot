# Hive rune-light preparation

```sh
python3 tools/prepare_hive_rune_light.py --game /path/to/original/game \
  --texture /path/to/fresh/L5_HC/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python/Pillow, `prepare_hive_wax.py` and the three published source/material/creature readers. The texture comes from the published Hive material exporter; its complete decoded hash and the original Hive archive hash are checked before output creation.

Produces the complete ten-file `assets/lol2/generated/hive_rune_light` pack: one unlit sprite, eight lit frames and `light.json`, plus `docs/hive-rune-light-source.json`. All runtime files and the source report match the existing outputs byte-for-byte in an isolated four-helper run. The extraction body is unchanged except for an explicit texture path. Original prop377 placement and template36 selector resources293/285, state/frame bytes, bounds, decoded pixels and payload hashes are retained.

Existing-output, missing-game, altered-texture and overlapping-output checks pass. No historical generated input or native replay is needed; the shared Wax reader now imports local readers directly. The no-argument historical paths remain available. Output must be absent and outside the inputs; later failures can leave partial output, so retry in a new destination. Original/generated media are excluded from publication. Billboarding, aim proxy, looping rate and index1 omission retain their existing adapter behavior; no new native rendering or timing parity is claimed.
