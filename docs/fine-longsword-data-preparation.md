# Fine Longsword request data preparation

```sh
python3 -S tools/prepare_fine_longsword_data.py \
  --game /path/to/original-game \
  --output-root /path/to/fresh-output
```

Only the Python standard library and published MIX reader are required. The command pins GLOBAL.MIX and its definitions entry, extracts definition5, and checks identity, mask, signature and handler. It writes `assets/lol2/generated/hive_fine_longsword_request.json` with the original definition offset and hash. No historical generated input or native replay is needed.

Independent verification reproduced the full runtime JSON byte-for-byte. Existing output, wrong archive, missing game and overlapping paths were refused. Use a fresh destination separate from originals; generated output remains local.

The historical `verify_hive_fine_longsword_request.py` remains unchanged. This command extracts the data packet without repeating its callback-dispatch, owner-default or call/return replay. It does not claim native weapon damage, change gameplay, or modify R18. Full Act1 assembly and acceptance remain separate.
