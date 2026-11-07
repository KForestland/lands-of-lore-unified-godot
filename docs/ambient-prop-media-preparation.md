# Cave side-chamber and Jungle beehive media

From the checkout, with Python and Pillow installed:

```sh
python3 tools/prepare_ambient_prop_media.py --game /path/to/original/game \
  --contracts scripts/lol2 --output-root /path/to/fresh-output
```

The command builds `assets/lol2/generated/cave_side_chamber` (30 indexed mist, waterfall and splash frames) and `jungle_beehives` (three fullness images and Wax icon). Both complete packs match the existing runtime files byte-for-byte.

It verifies original Cave/Jungle/GLOBAL/LOCAL archive hashes and both published source-contract hashes. The published material and prop exporters regenerate their inputs in a temporary directory using `docs/game-geometry-profiles.json`; no historical generated maps or assets are read. Cave placements, dimensions, templates, materials and frame counts are checked against the contract. Jungle hive placements and selector metadata are checked, each selector PNG is hash-checked, and Wax is selected by its original item identity and name.

Only after both packs pass are they copied to the fresh output. Output overlap with originals or contracts is refused. Existing destination, missing game, wrong contract and overlap refusal checks pass. An isolated committed-helper run has no native replay imports. The legacy source-contract writers are unchanged; this media command retains their published timing and gameplay contracts and does not establish native timer or sequencer parity. Original files and generated assets are not included in source publication.
