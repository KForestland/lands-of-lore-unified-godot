# Museum Mail Shirt and Champion Stone preparation

With Python and Pillow installed, run each command into a separate absent destination:

```sh
python3 tools/prepare_museum_mail.py --game /path/to/original/game --output-root /path/to/fresh-mail
python3 tools/prepare_museum_stones.py --game /path/to/original/game --output-root /path/to/fresh-stones
```

The commands produce `assets/lol2/generated/museum_mail` (`mail.png`, `item.json`) and `museum_stones` (`stone.png`, `items.json`). All four files match the existing runtime assets byte-for-byte. Item10 Mail Shirt and items8/9 Champion Stone retain their original placement records, item definitions, resource references and pixel hashes.

Both tools now use only the published source/material/creature readers. Their extraction bodies are unchanged; the explicit CLI pins Museum/GLOBAL/LOCAL archives and rejects an existing or overlapping destination before writing. An isolated run with those three readers passes. Each tool passes existing-output, missing-game, altered-archive and output-overlap checks. No historical generated inputs or companion RE checkout are needed.

The no-argument original paths and staging behavior remain available, now using the local readers. These legacy scripts execute their staging body at top level and should be run as commands, not imported. Later decoding/filesystem errors may leave partial output; retry in a new destination. Original/generated media are excluded from source publication. The manifests preserve their historical scope text; this work does not change item effects, admission or placement behavior.
