# Cave initial data preparation

Run from the source checkout:

```sh
python3 tools/prepare_cave_initial_data.py --game /path/to/original/game --output-root /path/to/fresh/output
```

The command prepares `assets/lol2/generated/cave_start/start.json` and `cave_roach/actor.json`. It needs the original `DAT/L1_DC.MIX` and `LOLG.DAT`, whose complete hashes are checked, and the three published source, geometry and creature sprite readers. It needs no historical generated assets or native replay dependencies.

The arrival selector, source coordinates, region, floor height and heading come from original geometry. Actor 23 is joined to definition 5 and its original ROACH view resources. Two executable code spans are checked against the recorded startup evidence.

The `startup_cases=2`, level/entry and scope text preserve historical verifier metadata. This command does not replay those startup branches or establish new native AI behavior. The existing actor scope and modern pursuit/combat limitations remain unchanged.

The output directory must be absent and must not overlap the game directory. All extraction checks run before output is written. Lead verification reproduced both complete runtime JSON files byte-for-byte using an isolated tool and three-reader closure. Existing output, missing input, overlapping output, wrong executable and wrong archive were refused without creating new output.
