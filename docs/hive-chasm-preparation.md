# Hive chasm-pack preparation

```sh
python3 tools/prepare_hive_chasm_media.py --game /path/to/original/game --texture /path/to/fresh/L5_HC/materials/texture.bin --review /path/to/prepared/hive_review/hive.json --props /path/to/fresh/hive_props/props.json --output-root /path/to/fresh/output
```

This prepares the complete three-file `assets/lol2/generated/hive_chasm` pack. It uses Pillow and published source/material/sprite/geometry/event readers. Original Hive and executable hashes and the explicit texture hash are checked. The source report is reconstructed directly, including rock 233, its event list, command group 1680, 13 floor targets and two executable code spans.

The report's `filter_cases=170`, `native_write_checks=4` and replay scope retain historical verifier metadata. This command does not rerun those native checks. Original floor corners and signed target-minus-current arithmetic are checked directly.

The scene supplies existing floor materials/UVs. Its source binding and all 13 selected floor polygons are checked against original records. Fresh props supply trigger 233; its placement, position, template, state and frame bytes are checked against the archive. All 73 rubble frames and 11 rubble placements are decoded/read from originals. Intermediate work stays temporary; final output is copied only after checks succeed.

Lead verification reproduced all three files byte-for-byte with fresh texture and freshly prepared props, paired with the existing Hive scene. An isolated eight-helper run and six refusal controls pass, including tampered floor and prop inputs. Pairing with a newly prepared Hive base scene is still pending; this is not yet a clean whole-Hive assembly claim. UV/material choices remain the supplied scene's responsibility.

Output must be absent and outside all inputs. The legacy writer remains unchanged. Existing authored movement duration, simultaneous motion, hit cylinder and single-hit policy remain unchanged; native scheduling, wall rebuilding, projectile state and live response are not newly verified.
