# Hive base preparation

```sh
python3 tools/prepare_hive_review_media.py --game /path/to/original-game --recipe scripts/lol2/hive_review_capture_source.json --output-root /path/to/fresh-output
```

Requires Python 3, Pillow, published tools and docs/game-geometry-profiles.json. Original L5_HC, L4_HJ and LOLG.DAT hashes and the recipe hash are checked. Output must be absent and must not overlap the game or recipe directory. Temporary generation and validation finish before output creation. No historical generated files, RE checkout, native constructor or replay are needed. The legacy prepare_hive_review.py is unchanged.

The command freshly exports Hive geometry/materials, derives floor/ceiling presets and texture indirection from original tables, reconstructs the pinned rotation table, and uses the published interior-span builder. Jungle transition commands identify the two Hive arrivals. Its face, UV and wall logic matches the legacy writer.

The small source recipe preserves explicit historical choices: raw-file-order image layout for four materials, authored animation rates and arrival review heights, and eight historical native ceiling-selector deferrals. Only region265 changes an otherwise available ceiling binding; this evidence is retained, not re-derived. Image hashes check the recorded raw layout. These choices preserve the current presentation and do not establish native rendering parity.

The complete output is assets/lol2/generated/hive_review: hive.json,22 material images and19 animation frames. Independent isolated generation matched all41 images byte for byte and every field of all4001 faces,1692 wall bindings,8 unresolved walls, arrivals, animation settings and interior audit. The sole manifest difference is geometry_sha256: it now identifies the fresh geometry export (53f98a99fe028aa7abfab8c6f6cb63079444e189959bfd66d1511775160c2e14), whose metadata/schema differ from the historical export. Substituting the historical hash makes the manifest byte-identical. No runtime consumer reads this provenance field.

The integrated chasm preparation was independently run with this fresh Hive scene, fresh Hive props and fresh texture. All three chasm files matched byte for byte, closing its previously pending fresh-scene pairing, including the13 floor faces. Isolated generation loaded no native/RE modules. Five independent refusal controls covered existing output, overlap, missing originals, wrong recipe and wrong Hive archive; the contributor also supplied18 controls and repeat-generation evidence.

This verifies preparation of the base and its chasm dependency. It does not close whole clean assembly, moving-boulder preparation or remaining gameplay/platform acceptance gates.
