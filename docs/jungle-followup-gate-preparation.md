# Jungle follow-up gate preparation

```sh
python3 tools/prepare_jungle_followup_gate_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python 3 and Pillow, the published tools and docs/game-geometry-profiles.json. The output root must be absent and must not overlap the original game. Original Jungle and executable hashes are checked; no historical generated input or RE checkout is used. All computation and the temporary material export finish before output creation.

The command reconstructs movable70/template34/child76 directly from original placement and metadata records. Its four resource92 faces reuse the published face-order/UV constants; hinge poses use the published integer rotation formula and the rotation table reconstructed from the original executable. No constructor or native replay is run. Original regions3255/3262, predicates and open/close command bindings are checked. The original material is freshly exported with the published map-material reader.

Outputs are assets/lol2/generated/jungle_followup/gates.json, material_0092.png and docs/jungle-followup-source.json. All three match the existing files byte for byte, including all101 four-face poses. The source report's rotation_checks=101 is retained historical native-replay metadata, not a new replay claim. Authored timing/collision and other source group effects are unchanged. The legacy prepare_jungle_followup.py remains untouched.

Validation used an isolated committed helper snapshot plus this command, with the legacy RE root disabled. The repeated output matched all three files; no capstone, unicorn or RE modules loaded. Five refusal controls covered existing output, absent originals, input overlap, incorrect Jungle archive and incorrect executable. Whole clean assembly and gameplay acceptance remain separate gates.
