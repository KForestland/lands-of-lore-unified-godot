# Hive boulder preparation

```sh
python3 tools/prepare_hive_boulders_media.py --game /path/to/original-game --recipe scripts/lol2/hive_review_capture_source.json --output-root /path/to/fresh-output
```

Requires the published Hive base preparation, its capture recipe, geometry-profile document, Python3 and Pillow. The same original-game and recipe pins are checked. Output must be fresh and must not overlap either input. Preparation completes in temporary storage before writing output.

The command regenerates Hive base inputs and uses its unchanged wall resolver through synthetic interior spans. Those spans reproduce the legacy dummy quads used to resolve styles even when an initial wall span is empty. It reads original paths, markers and actor rows directly. Unlike the legacy writer, it does not execute another writer through runpy or rewrite the Hive base pack. No historical generated inputs, RE checkout or native replay are required.

Both assets/lol2/generated/hive_boulders/boulders.json and docs/hive-boulder-staging-checks.json independently match the existing files byte for byte. Component checks cover five moving surfaces,13 markers, actor30/31 spawns, trigger1216,28 edges and30 styles. Each style is tied to its region's original wall record and code. Isolated generation loaded no native/RE modules; four independent refusal controls passed. Contributor evidence additionally covers14 refusals, repeated generation and write-target tracing.

The existing base recipe retains its disclosed historical presentation choices. The legacy prepare_hive_boulders.py is unchanged. Runtime motion, collision/event behavior and whole-build acceptance are separate from this preparation verification.
