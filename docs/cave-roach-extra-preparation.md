# Cave Roach extra-action preparation

```sh
python3 tools/prepare_cave_roach_extra_media.py --game /path/to/original-game --texture /path/to/fresh/L1_DC/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python3, Pillow and the published Cave directional preparation/readers. Prepare the pinned texture using the published material exporter for L1_DC. The command reads original actor23 (definition5, initial goal14/action9), both Roach definitions and their selector7/8 resource bindings. It freshly rebuilds the directional pack in temporary storage to derive the shared canvas rather than reading an existing generated pack.

The complete output is assets/lol2/generated/cave_roach_extra_actions (16 indexed PNGs and animation.json), plus docs/cave-roach-extra-actions-checks.json. Every file and the report independently match the existing outputs byte for byte. All16 frames reconstruct losslessly on the fresh shared canvas. The3072 action-table cases run the published pure selector against original rows; this is not new native replay. Original sound-event IDs and existing authored presentation settings are retained.

The output root must be absent and must not overlap inputs. Isolated generation loaded no native/RE modules; four refusal controls covered existing output, missing originals, overlap and incorrect texture. Decode failure can leave partial output; retain it for diagnosis and retry in a fresh directory. Legacy preparation and native evidence remain unchanged. Whole clean assembly and gameplay acceptance remain separate gates.
