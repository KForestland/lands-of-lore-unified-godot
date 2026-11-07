# Jungle world-item preparation

```sh
python3 tools/prepare_jungle_world_items.py --game /path/to/original/game \
  --source docs/game-geometry-profiles.json \
  --recipe scripts/lol2/jungle_world_item_probe_source.json \
  --output-root /path/to/fresh-output
```

Requires Python/Pillow and the three published source/material/creature readers. Produces the13icons and `items.json` in `assets/lol2/generated/jungle_world_items`, plus `docs/jungle-world-items-source.json`. The complete14file pack and source report match the existing outputs byte-for-byte in an isolated three-reader run. Row51 remains the separate dagger module.

Original Jungle/GLOBAL/LOCAL archives and the Jungle geometry profile are checked before extraction. Placement rows, coordinates, flags, item identities/definitions, names, handlers, inventory resources and pixels come from those originals. The producer's extraction body is unchanged apart from explicit source-profile and probe inputs.

The compact recipe retains the13previous Godot probe results consumed by the catalog: support height, navigation reachability, line of sight and absent ceiling. Its provenance hashes identify the historical probe JSON, probe script and producer. All13rows were independently compared with the probe and catalog before integration. These are recorded results, not fresh collision/navigation tests or native pickup admission proof. Deliberately changing and re-pinning a recipe could change these recorded fields; whole-build qualification must still exercise gameplay. No private save or probe payload is required by the command.

The destination must be absent and must not overlap the inputs. Existing-output, missing-game, incorrect-recipe and overlapping-output refusal checks pass. Later decode/filesystem failures may leave partial output; retry in a new destination. The no-argument historical workflow retains its original helpers and paths. Original/generated media are excluded from source publication; gameplay admission and item behavior are unchanged.
