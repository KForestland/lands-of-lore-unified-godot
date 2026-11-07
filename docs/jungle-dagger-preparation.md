# Jungle dagger pickup preparation

```sh
python3 tools/prepare_jungle_source_pickups.py --game /path/to/original/game \
  --source docs/game-geometry-profiles.json --output-root /path/to/fresh-output
```

Requires Python and Pillow plus the three published readers `lol2_source_format.py`, `lol2_material_format.py` and `lol2_creature_sprite_format.py`. Produces `assets/lol2/generated/jungle_source_pickups/th_dagger.png`, `pickups.json`, and `docs/jungle-source-pickups-source.json`. Both runtime files and the source report match the existing outputs byte-for-byte in an isolated three-reader run.

The explicit path pins Jungle/GLOBAL/LOCAL archives and validates the Jungle source profile against fixed geometry identity and hash. Placement row51, item definition9, first-view resource66, pixels and region connectivity are extracted from the originals. The legacy extraction body remains unchanged except for an explicit source-profile path. Existing-output, missing-game, invalid-profile and overlapping-output refusal checks pass. No generated input, captured probe or native replay import is needed.

The reported 18 region hops and reachability without region2443 describe the existing neighbor graph; they do not establish collision clearance, a walked route or an earned pickup. This producer covers row51 only; the separate world-item module handles its other admitted rows. No gameplay admission changes are made.

The no-argument historical workflow is retained and still imports its historical helpers. Use explicit arguments for portable assembly. The destination must be absent and outside the inputs; later decoding/filesystem failures may leave partial output, so retry in a new destination. Original files and generated assets are excluded from publication.
