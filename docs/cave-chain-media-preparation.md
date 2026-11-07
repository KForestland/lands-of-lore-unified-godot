# Cave chain media preparation

Run from a clean checkout with Python 3, Pillow and liblzo2 installed:

```sh
python3 tools/prepare_cave_chain_media.py --game /path/to/originals --output-root /path/to/fresh/output
```

The command validates the pinned `DAT/L1_DC.MIX` through the shared prop exporter, decodes the original sprite resources, and writes 58 PNGs plus `assets/lol2/chain/chain.json`. It reads no RE checkout, previous generated assets or private saves. Output must be fresh and outside the original game tree.

Placement record 544 supplies template 77, region 799 and the position. Original template/state/frame records supply selectors 0/1/2, resources 87/89/88, width, side/bottom trims and flags. Region floor/ceiling supplies height 60. The established preview deliberately retains that full height without subtracting the original top trim (the generic prop preview yields 58). This reproduces the existing visual contract; it is not new proof of native UV or vertical-bound parity. Billboard orientation, normalized UV and palette transparency remain preview choices.

Validation: all 59 outputs match the existing runtime pack byte for byte; a separate clean archived-tools rebuild gives the same files. Existing-output, input-overlap and missing-originals cases fail. The producer changes preparation only; gameplay qualification is recorded separately.
