# Kelsrick media preparation

Rebuild Kelsrick’s seven dialogue movies and creature sprites with explicit local inputs:

```sh
python3 tools/prepare_jungle_kelsrick_media.py --game /path/to/game --texture /path/to/L4_HJ/texture.bin --source scripts/lol2/jungle_kelsrick_source.json --output-root /path/to/fresh-output
```

Requires Python, Pillow, NumPy and FFmpeg, plus the local game archives and extracted texture. The texture hash must match the source contract. The output directory must not exist. The tool uses repository helpers; the older source/native audit in `prepare_jungle_kelsrick.py` is not required for this media-only rebuild. Full game preparation remains separate.

The generated pack is `assets/lol2/generated/jungle_kelsrick` under the output root; temporary source movies and raw frames are under `tmp`. Only the generated pack belongs in a locally prepared game. Original media is not supplied by this repository.

The independent rebuild produced all 2,325 expected files. Audio, metadata and sprites match; 72 movie frames differ from the existing pack because that pack still carries the older FFmpeg seek-snapshot artifact. Across all seven movies, all 2,033 rebuilt frames match FFmpeg after removing only top-level VQFL seek snapshots. All 2,033 existing frames match FFmpeg on the unchanged movies. This causal comparison supports the corrected rebuild and the existing reviewed linear-playback decoder.

Live replacement is pending while ongoing campaign and gate checks consume the shared assets. The rebuilt pack is staged separately; these results do not certify a new demo build or player acceptance. See [checks](kelsrick-media-portability-checks.json) and [decoder evidence](vqa-linear-playback.md).
