# Initial progression data preparation

```sh
python3 -S tools/prepare_player_initial.py \
  --game /path/to/original-game \
  --recipe scripts/lol2/player_initial_source.json \
  --output-root /path/to/fresh-output
```

The standard-library command verifies the pinned recorded recipe, original LOLG.DAT and four initializer code spans, then writes `assets/lol2/generated/player_progression_initial.json`. Use a new directory separate from inputs. Existing output, incorrect recipe/executable and overlapping paths are refused.

The recipe retains the existing fighting/magic initialization packet and source-code hashes from the historical bounded native-replay report. Its provenance records that report and producer hashes. All four dirty-memory cases in the report agree on these values. The preparation command verifies original bytes but does not execute or re-derive their semantics. The values remain trusted recorded data; changing the recipe pin could permit different values. No native emulator, historical generated pack or unpublished report is needed at preparation time.

Independent reconstruction and the command reproduce the entire runtime JSON byte-for-byte. Four invalid-input controls pass. The historical `verify_player_progression_initial.py` is unchanged. This does not change authored guardian health, migrate old saves, or claim subsequent game-start scripts/full-constructor coverage. R18 remains unchanged; full Act1 assembly and acceptance remain separate.
