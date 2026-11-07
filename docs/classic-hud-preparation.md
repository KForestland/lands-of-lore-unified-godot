# Reproduce the classic HUD artwork

From the source checkout, use explicit original-game and fresh output paths:

```sh
python3 tools/prepare_classic_hud.py \
  --game /path/to/original/game \
  --output-root /path/to/fresh/hud-stage
```

No companion RE checkout is needed. Both preparers read the MIX archives with the published `tools/lol2_source_format.py` `parse_mix`, which has the same body as the former RE helper `tools/draracle/lol2_extract_draracle_geometry.py` `parse_mix`; `LOL2_RE_ROOT` is not read.

Inputs are the original `GLOBAL.MIX` and `LOCAL.MIX`. The preparer checks `intrface.shp` key 606080735 against SHA-256 `1c03f2a0f739368c66078103d43131ea0fde26bfffdd34186b21611dde3fd50e`, and palette key 1915865337 against `520c6fe31ccb9d5e1044b958e082df7919d63b46008dee9965d1b1e956a17729`. Hash and layout checks finish before output creation.

Outputs are ten PNGs under `assets/lol2/generated/classic_hud/` and `scripts/lol2/classic_hud_source.json` beneath the chosen output root. Independent regeneration with Python 3.12.3 and Pillow 10.2.0 matched all eleven existing files byte for byte. Missing originals, altered shape data and an empty helper override failed while preserving existing output. A separately located helper copy supplied both direct and transitive imports. Those helper checks describe the earlier RE-helper version; the current preparers have no helper root.

## Portrait, blink frames and cursor

Prepare the Museum interface artwork into the same fresh staging root:

```sh
python3 tools/prepare_museum_interface.py \
  --game /path/to/original/game \
  --output-root /path/to/fresh/hud-stage
```

This reads `GLOBAL.MIX` and `LOCAL.MIX`, including `P_LUTHER.WSA`, `EYENORM.WSA`, `intrface.shp`, `mouseh.shp` and the base palette. It retains the original decoder bounds, frame-count and loop-closure checks. All input decoding and PNG index roundtrips finish before the output directory is created or existing output files are replaced. This guards input-validation failures; it does not promise an atomic filesystem transaction if a later write fails.

Outputs are `portrait.png`, `blink_1.png`, `blink_2.png`, `blink_3.png`, `portrait_frame.png`, `cursor.png` and `provenance.json` under `assets/lol2/generated/museum_interface/`. Independent explicit-path regeneration with Python 3.12.3 and Pillow 10.2.0 reproduced all seven baseline files byte for byte. Missing originals, an invalid helper override (earlier RE-helper version) and a malformed eye-animation header failed without changing prior outputs. The decoder functions are unchanged. Existing unrelated files, including Godot import sidecars, are left in place.

Without arguments, both preparers retain the historical local game directory and repository output root. Use explicit paths for isolated preparation. These steps do not produce the complete asset tree or certify a clean installation, export or platform run.
