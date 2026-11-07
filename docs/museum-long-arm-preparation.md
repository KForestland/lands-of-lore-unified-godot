# Museum Long Arm preparation

```sh
python3 tools/prepare_museum_long_arm_media.py --game /path/to/game \
  --source scripts/lol2/museum_long_arm_source.json \
  --recipe scripts/lol2/museum_review_selection_source.json \
  --museum-review /path/to/prepared/museum_review/museum.json \
  --output-root /path/to/fresh-output
```

Produces all 17 files in `assets/lol2/generated/museum_long_arm`: 15 pedestal frames, the icon and `floors.json`. Requires the checkout's published geometry profile/readers/builders, Python with Pillow, and local original files. The output must be absent and must not overlap inputs.

Geometry, materials, selectors, setup and rotation data are regenerated in a temporary directory. A compact recipe retains the historical captured material selection, animation rate and deferred ceiling selections with their source hashes; these selections are recorded evidence, not newly derived native behavior. Fresh base faces must equal the supplied Museum manifest's faces before floor indices are generated. The Long Arm contract pins every pedestal frame. The legacy source-contract writer remains unchanged.

Independent reconstruction matches all 17 existing runtime files byte-for-byte: 40 closed faces, 44 open faces, 15 frames and an icon. Recipe provenance hashes and every retained selection were rechecked. Existing-output, missing-game, wrong-recipe and overlapping-output controls pass. The isolated parent loads no native replay modules, and the builder child uses the published static interior builder. The exported geometry helper's legacy RE-dependent function is not called.

The paired Museum manifest remains an explicit generated input. `floors.json.shipped_sha256` binds its exact bytes, while closed indices refer to its face ordering. Regenerate Long Arm after changing that manifest. This command alone does not establish portable preparation of the base Museum pack. The base builder embeds input paths and arrival information; Long Arm rebuilds only its faces with a placeholder arrival, which is not used by the floor variant. Original assets and generated files are excluded from source publication.
