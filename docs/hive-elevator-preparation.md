# Hive elevator preparation

From the source checkout:

```sh
python3 tools/prepare_hive_elevator.py \
  --game /path/to/original-game \
  --re-root /path/to/re-helpers \
  --recipe scripts/lol2/hive_elevator_source.json \
  --output-root /path/to/fresh-output
```

Use a new output directory separate from inputs. Python 3, Pillow and the committed map geometry/material/surface/movable exporters are required, along with the published RE2791eb1 draracle dependency set described in `map-movables-preparation.md`. The existing movable exporter runs as a child process and uses Capstone for its constructor replay. The parent preparer does not load Capstone, Unicorn or native audit modules. No new native archaeology is performed. Use ordinary Python without optimization because source checks include assertions.

The command regenerates Hive geometry, floor surfaces and static assemblies from original data in a temporary directory. It reconstructs trigger regions282/283, floors772–774, eight control assemblies and eight stops, then stages the existing manifest and20material images. Historical map exports and `hive_review/hive.json` are not inputs. The output pack is `assets/lol2/generated/hive_elevator`; no video or audio is present. Keep generated media local.

The compact recipe carries recorded flute-handler relocation and disassembly text. Original fixup bytes, target and handler bytes are checked; the fixup-table walk and disassembly are not repeated. The text is trusted recorded data protected by the recipe hash, with address-range checks. Re-pinning the recipe could permit different text within that range. This does not establish additional flute audio or gameplay effects.

Existing output and invalid pinned inputs are refused. Temporary intermediate exports are removed when the command exits; later staging errors can leave partial final output. Preserve failed output and retry with a fresh directory. No-argument behavior keeps the historical reads, native steps and source-report write. Explicit mode writes no legacy source report.

Independent rebuilding from originals, committed helpers and the pinned RE dependency set reproduced all21runtime files byte-for-byte. All318control-face material references resolve. Recipe provenance hashes, relocation and disassembly match the historical report. Existing output, missing game and wrong-recipe controls pass. This validates preparation of the current pack, not all lift/flute behavior or complete Act1 acceptance; R18 is unchanged.
