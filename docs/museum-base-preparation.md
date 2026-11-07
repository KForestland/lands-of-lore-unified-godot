# Museum base pack preparation

```sh
python3 tools/prepare_museum_review.py --game /path/to/original/game \
  --recipe scripts/lol2/museum_review_selection_source.json \
  --layout scripts/lol2/museum_review_capture_layout_source.json \
  --output-root /path/to/fresh-output
```

Requires Python/Pillow, the published checkout's static geometry/material/surface readers and `docs/game-geometry-profiles.json`. Produces all 69 files under `assets/lol2/generated/museum_review`, with deterministic builder inputs under `tmp/museum_review_inputs`. No historical generated files, private saves or native replay are required by the command.

The existing builder runs unchanged. Geometry, material pixels, selector/preset bindings, initial surface setup and rotation data are regenerated from the originals. The starting entry is selected by the original Cave-to-Museum transitions and positioned at that Museum region's floor. The compact selection recipe retains the captured material set, animation rate and deferred ceilings. The layout recipe retains the captured orientation and hashes of material111: its base image and ten frames are the transpose of the published raw-material export. This preserves the shipped appearance; it is not a new claim about native presentation. Both recipes describe their recorded-evidence limits.

Independent verification found 68 files byte-identical to the existing pack. Every `museum.json` key except `sources` is equal, including all 5,437 faces, materials, animations, arrival region1226 and start `[-3796,34,-369]`. Provenance now names relative builder inputs and their fresh hashes. Two separate runs produce all69files byte-identically. The recorded capture hash and all11transposed image pairs were independently checked. No script/test consumer of the `sources` field was found.

Regenerate paired floor variants against the new manifest. The published Long Arm command accepts this fresh base; its16images remain exact and `floors.json` changes only `shipped_sha256` to the correct new manifest hash. Other paired variants must likewise be prepared against the same base before whole-project qualification.

The output must be absent and must not overlap the originals or recipes. Existing-output, missing-original, wrong-layout and overlapping-output controls pass. The preparation run imports no native replay modules; the builder child uses the published static interior builder. Validated inputs are staged before that child runs, so a later builder/filesystem failure may leave partial output; retry in a new destination. Original/generated media are excluded from source publication. This preparation proof does not replace rendered whole-build qualification or owner acceptance.
