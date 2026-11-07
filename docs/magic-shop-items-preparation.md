# Magic shop item preparation

```sh
python3 tools/prepare_magic_shop_items.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Requires Python, Pillow and the checkout's three local readers: `lol2_source_format.py`, `lol2_material_format.py` and `lol2_creature_sprite_format.py`. Produces `assets/lol2/generated/magic_shop_items/items.json` and six original inventory PNGs. All seven files match the existing runtime pack byte-for-byte, including item definitions, resource references and pixel hashes.

The explicit path pins the original GLOBAL and LOCAL archives and uses the original producer's unchanged extraction body. The six item-name selections remain in that body. It takes no generated input, private probe or native replay dependency. An isolated run with only the producer and three readers passes, as do existing-output, missing-game, altered-archive and overlapping-output refusals.

The no-argument legacy workflow is retained and still imports its historical helper. Use explicit arguments for portable assembly. The destination must be absent and outside the original game tree. Later decoding or filesystem failures may leave a partial destination; select a new destination for a retry. Original and generated media are excluded from source publication. Shop gameplay, prices and callbacks are unchanged.
