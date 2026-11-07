# Museum broken-case preparation

```sh
python3 tools/prepare_museum_broken_case_media.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares the complete seven-file `assets/lol2/generated/museum_broken_case` pack from pinned original `DAT/L3_DH.MIX`. Run from a source checkout containing the published tools and `docs/game-geometry-profiles.json`, which the material exporter reads. No historical generated pack, executable, recipe, constructor replay or native dependency is required.

Control 181, template 9 and children 26–36 come from original geometry and metadata. The tool constructs 46 faces using the published movable exporter's face order and UV rules; heading zero is asserted, making rotation the identity. Nine children form the case; the sword and empty inactive child are excluded. Fresh material export supplies six PNGs. Source bounds, placement, surface slots and contact envelope are checked before output is written.

Lead verification reproduced all seven runtime files byte-for-byte. Catalog fields and material hashes match historical evidence, the direct faces match the historical constructor export, and the copied face/UV rules match the published exporter AST. The isolated committed-helper run loaded no native or RE modules. Four independent controls refused existing output, overlapping output, missing originals and a wrong archive.

The output root must be fresh and outside the game directory. The legacy writer is unchanged. Historical instruction-slice evidence in `docs/museum-broken-case-source.json` is not regenerated; this preparation is not a new native replay. Runtime contact and visibility adapter conventions are preserved.
