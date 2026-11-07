# Hive rune-entry preparation

```sh
python3 tools/prepare_hive_rune_entry_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow, the published map readers, geometry profile, face-order constants and integer rotation model. Original L5_HC and LOLG.DAT are pinned. Output must be fresh and cannot overlap the game directory. Temporary generation completes before output creation. No historical generated inputs, RE checkout or native constructor replay are needed.

The command builds control0's32 faces from its original placement and template64's seven children, with the published face order, UVs and rotation table. All seven children are active type0 records; there are no hidden-state faces in this pinned assembly. Three materials are freshly exported. Control events, group5244, prop327's empty event list and the return point's containment in region679 are checked against original records/fresh geometry.

All four runtime files in assets/lol2/generated/hive_rune_entry and docs/hive-rune-entry-source.json independently match the existing outputs byte for byte. Bindings match the historical constructor export; the pure rotation model agrees with the original verifier's model on5448 cases. These comparison checks do not execute native instructions. Isolated preparation loaded no native/RE modules. Four independent refusal controls cover existing output, missing originals, input overlap and incorrect archive; contributor evidence additionally covers12 controls and repeated generation.

The legacy writer and its scope text remain unchanged. Return-height collision adaptation and runtime command ordering remain gameplay concerns; this preparation result does not establish whole clean assembly or final gameplay/platform acceptance.
