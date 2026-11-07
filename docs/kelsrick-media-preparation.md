# Kelsrick media preparation

Rebuild Kelsrick’s seven dialogue movies and creature sprites with explicit local inputs:

```sh
python3 tools/prepare_jungle_kelsrick_media.py --game /path/to/game --texture /path/to/L4_HJ/texture.bin --source scripts/lol2/jungle_kelsrick_source.json --output-root /path/to/fresh-output
```

Requires Python, Pillow, NumPy and FFmpeg, plus the local game archives and extracted texture. The texture hash must match the source contract. The output directory must not exist. The shared sprite helper must include its optional RE-root lookup fix for a machine without the historical checkout. The tool uses repository helpers; the older source/native audit in `prepare_jungle_kelsrick.py` is not required for this media-only rebuild. Full game preparation remains separate.

The generated pack is `assets/lol2/generated/jungle_kelsrick` under the output root; temporary source movies and raw frames are under `tmp`. Only the generated pack belongs in a locally prepared game. Original media is not supplied by this repository.

Independent verification on 2026-10-13 reproduced all 2,325 current runtime files byte for byte: seven dialogue poses, six WAVs, both manifests and 285 sprite files. The run used the published source/tool tree, the optional sprite-helper fix, original archives and a freshly decoded texture, with no RE, Capstone or Unicorn imports. All 2,033 movie frames matched the current pack.

The earlier [portability checks](kelsrick-media-portability-checks.json) recorded a 72-frame difference against that comparison's baseline and a causal FFmpeg seek-snapshot comparison. That is historical evidence; the current pack has no such difference in this new file-by-file rebuild. The causal FFmpeg comparison was not rerun. See [decoder evidence](vqa-linear-playback.md).

The CLI rejects existing output roots and missing source/texture paths. Some archive and texture checks occur after creating the fresh pack directory; invalid inputs or later decoding failures can leave partial output. Use ordinary Python without `-O` so reader assertions remain enabled. These preparation results do not certify a new demo, rendered/audible playback or player acceptance.
