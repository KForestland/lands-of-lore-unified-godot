# Recorded Executioner perception data preparation

```sh
python3 -S tools/prepare_hive_perception_data.py \
  --game /path/to/original-game \
  --recipe scripts/lol2/hive_perception_source.json \
  --output-root /path/to/fresh-output
```

The standard-library command verifies the recorded recipe and original executable hashes, then stages `assets/lol2/generated/hive_perception_definition.json`. Use a fresh destination separate from inputs. Existing output, wrong recipe/executable and overlapping paths are refused.

The recipe contains the existing actor36 perception packet, with historical report/producer hashes, capture hashes, sample count and scope. Independent review re-read the original local captures: both file hashes matched, the construction mapping contained37indices, and all496Executioner definition records yielded the exact recorded values. The full runtime JSON reproduced byte-for-byte. No capture payload is published or required by the preparation command.

This is recorded runtime observation, not source-loader derivation. The executable hash binds preparation to the known edition but does not itself prove those values. The command trusts the hash-pinned recipe and does not re-run capture or native verification; changing its recipe pin could permit different recorded values. The historical `verify_hive_perception_definition.py` is unchanged. The evidence does not establish mutable definitions outside the capture.

Four invalid-input controls pass. R18 and gameplay behavior remain unchanged; whole Act1 assembly and acceptance are separate.
