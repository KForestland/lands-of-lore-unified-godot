# Hive warrior-pack preparation

```sh
python3 tools/lol2/map_materials.py export --game-root /path/to/original/game --area L5_HC --out /path/to/fresh/materials
python3 tools/prepare_hive_warriors_media.py --game /path/to/original/game --texture /path/to/fresh/materials/texture.bin --output-root /path/to/fresh/output
```

The material exporter needs the published geometry profile. The warrior tool uses Pillow and the published source/material/sprite, atlas and event/command readers. It checks the original Hive archive and fresh texture hashes. No historical pose/encounter export or native replay is an input.

The complete `assets/lol2/generated/hive_warriors` pack contains `warrior.png` and `provenance.json`. Original definition 0 (`HIVEW`), selector 0/view 0 binds resource 1503. The published LCW/block decoder reads its bounded codebook; palette index zero remains transparent. Actor records 32 and 34 supply positions, region/heading, structural definition candidates and complete event/group records with original offsets.

Output must be absent and outside both inputs. The PNG is encoded in memory; final files are written after checks. Lead verification reproduced both files byte-for-byte with an isolated seven-helper run. Five refusal controls cover existing output, overlap, missing originals, wrong archive and wrong texture.

The legacy writer remains unchanged. Selector zero is a recovered review pose, not proof of initial activation. Encounter activation, combat rules and event-10 defeat timing retain their existing authored scope; constructor execution is not replayed here.
