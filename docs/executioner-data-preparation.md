# Executioner data preparation

Run from the source checkout with locally supplied original game files:

```sh
python3 tools/prepare_executioner_data.py --game /path/to/game --output-root /path/to/fresh-output
```

Produces `assets/lol2/generated/hive_actor_health.json` and `executioner_melee_reward.json`. Requires only Python standard library and the published `lol2_source_format.py` reader. The destination must be absent and must not overlap the originals.

The command pins the Hive archive, geometry entry and executable. It reads placement 36 from the geometry actor section, follows its definition index into the metadata's 147-byte records, and extracts the health fields and reward scale. Both output files match the existing runtime packets byte-for-byte. Missing input, altered archive, existing destination and overlapping destination refusal checks pass; extraction also passes with only the command and MIX reader present.

`mode=0`, the source-proof names and the reward semantic description retain the existing adapter contract. This command does not rerun or replace the historical constructor/reward callback proofs, prove native callback parity, or change combat behavior. The executable hash binds the supported edition; reward scale comes from the archive definition. Original media and generated output are not included in source publication. Copy the two generated JSON files into a prepared local project as part of assembly.
