# Cave captain equipment and guard shield preparation

Run from the source checkout with separate fresh destinations:

```sh
python3 tools/prepare_cave_captain_items.py \
  --game /path/to/original-game --output-root /path/to/fresh-captain
python3 tools/prepare_cave_guard_shield.py \
  --game /path/to/original-game --output-root /path/to/fresh-shield
```

Explicit mode requires Python 3, Pillow and only the published `lol2_source_format`, `lol2_material_format` and `lol2_creature_sprite_format` helpers. No native wax/audit module or external RE checkout is imported. Use ordinary Python without optimization because the unchanged producer bodies retain assertion checks.

Both commands pin the GLOBAL definition and LOCAL graphic payloads before writing. They preserve the existing item-definition, identity, single-view resource and defense-byte checks. Each graphic is decoded as colour and original palette indices, with indices0/1 transparent. Captain equipment produces five runtime files under `assets/lol2/generated/cave_captain_items` and its historical source report under `docs`; the shield produces three runtime files under `assets/lol2/generated/cave_guard_shield`. Keep generated media local.

Existing destinations, missing inputs, overlapping game/output paths and incorrect payload pins are refused. Later decoding failures may leave partial fresh output; preserve it and retry in a new directory. Both no-argument legacy producers and main function bodies are unchanged; explicit mode binds their inputs to the portable readers and the requested paths.

Independent full-pack comparisons reproduced all eight runtime files byte-for-byte, including manifests and palette-index images; the captain source report also matched exactly. Rebuilding with only the two preparers and three reader modules reproduced both packs again. Existing-output, missing-game and overlap controls passed for both commands. Main-function AST equality was verified. This preparation does not replay grants, armor summation or weapon behavior and does not alter R18 or establish full Act 1 acceptance.
