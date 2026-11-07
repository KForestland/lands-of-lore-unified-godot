# Original Cave floor preparation

```sh
python3 tools/prepare_original_floors_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow, the published map readers and geometry profile. Cave archive and executable are pinned. Output must be absent and cannot overlap the game; temporary generation and all builders finish before output creation. No historical generated input, RE checkout or native replay is required.

This prepares all21 original_floors files: floors/interior audit,13 material images, both traversal fixture sets, connected walk/audit and full walk/audit. It executes the existing builders' logic over freshly exported source geometry, presets, materials and rotation table. All21 files independently match the existing pack byte for byte, including1953 floor quads and the full-walk geometry/checkpoints/special links.

Two historical presentation conventions are retained explicitly: negative-resource preset16 remains unresolved (86 regions), and images retain the captured column-major byte-order interpretation. These preserve the current runtime pack; neither is a native-rendering claim. Source comparisons verified all used geometry fields,1946 region bindings,21 initial presets,13 material layouts and the rotation table.

Isolated generation loaded no native/RE modules. Four independent refusals cover existing output, overlap, missing originals and incorrect archive. Contributor evidence additionally covers12 controls, repeat generation and a rerun of the four unchanged legacy builders. Published legacy builders and their CLIs remain unchanged. Full clean assembly and final gameplay/platform acceptance remain separate gates.
