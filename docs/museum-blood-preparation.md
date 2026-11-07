# Museum Dragon Blood preparation

```sh
python3 tools/prepare_museum_blood.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Requires Python/Pillow and the checkout's published archive, source-event and inventory-icon readers, plus `docs/game-geometry-profiles.json`. Produces `assets/lol2/generated/museum_blood_loot/icon.png`, `scripts/lol2/museum_blood_source.json`, and `docs/museum-blood-source-checks.json`. All three outputs match their existing counterparts byte-for-byte.

The explicit path pins Museum/GLOBAL/LOCAL archives and passes the original-game path to the existing readers. It checks the two actor20 grants, owner/group/event binding, definition166 identity and three active placed Dragon Blood vials directly from source records, then decodes the original inventory icon. No historical generated input or native replay is required. An isolated committed-helper run imports no native modules; existing-output, missing-game, altered-archive and overlapping-output refusal checks pass.

The no-argument legacy workflow remains available. The destination must be absent and outside the originals; later failures may leave partial output, so retry in a new destination. Original/generated media are excluded from publication. Corpse retirement, fuse, blast damage and placement remain the existing modern adapters; this preparation does not establish native gameplay parity.
