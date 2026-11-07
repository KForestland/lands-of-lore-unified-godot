# Reward threshold data preparation

```sh
python3 -S tools/prepare_reward_thresholds.py \
  --game /path/to/original-game \
  --output-root /path/to/fresh-output
```

Only the Python standard library and original LOLG.DAT are required. The command pins the executable, follows the same LE object/page-table addressing as the historical reward verifier, and extracts 31 unsigned words. It verifies the 124-byte table hash before writing `assets/lol2/generated/hive_reward_thresholds.json`. No native replay, historical generated data or external helper is needed.

The complete JSON is byte-identical to the existing runtime file, including file offset1898548, executable hash and table hash. Existing output, wrong executable, missing input and overlapping game/output controls pass. Use a fresh output directory separate from originals; generated output remains local.

The historical `verify_hive_sword_reward_application.py` remains unchanged. Extracting its table does not repeat or replace its native accumulation, level-stat, RNG or presentation checks. No gameplay or R18 build changes are made.
