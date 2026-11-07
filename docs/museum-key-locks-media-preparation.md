# Museum key-lock media preparation

First prepare the Museum base with `prepare_museum_review.py` as described in `museum-base-preparation.md`, then:

```sh
python3 tools/prepare_museum_key_locks_media.py --game /path/to/original/game \
  --source scripts/lol2/museum_key_locks_source.json \
  --recipe scripts/lol2/museum_review_selection_source.json \
  --museum-review /path/to/base/assets/lol2/generated/museum_review/museum.json \
  --output-root /path/to/fresh-key-locks
```

Requires Python/Pillow and the published checkout's static geometry/material/surface and source-event readers. Produces all three files under `assets/lol2/generated/museum_key_locks`: `sk_key.png`, `ss1.png`, and `passage78.json`. No new recipe is needed. The legacy contract writer remains unchanged.

Control78 insert/take records are reread from original geometry and checked against the published contract. Prop81 opening/closing commands, control106 placement/poses and original item identities are checked. The existing Museum builder regenerates the base and lowered-passage faces from original data and the recorded selection recipe. Base faces must equal the supplied Museum manifest before indices are written.

Independent fresh-base verification finds both icons byte-identical and every passage field equal except `shipped_sha256`, which correctly names the fresh Museum manifest. All seven closed indices resolve to the expected faces in that base; the six open faces and control commands/poses are unchanged. Regenerate this pack whenever its paired base manifest changes. The fresh base's historical comparison differs only in provenance, as documented separately.

The command refuses existing output and overlap with the game, paired base root or contract/recipe directories. Existing-output, missing-game, wrong-contract, base-overlap, malformed-manifest and tampered-face controls pass. An isolated committed-helper run imports no native replay modules; its builder child uses the static interior builder. The selection recipe retains recorded material/deferred-ceiling evidence; no native event execution or new gameplay parity is claimed. Original/generated media are excluded from publication. Whole-build rendered qualification remains separate.
