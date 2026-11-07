# Jungle review scene preparation

`prepare_jungle_review.py` assembles the existing Jungle review scene from explicit original-game, geometry and material inputs. It derives numeric bindings, UVs, presets and arrival from the original sources through published helpers. No historical numeric review JSON or captured rotation table is required.

First generate fresh `L4_HJ` geometry, ceiling subdivisions, source walls and materials using the published geometry, ceiling and source-wall preparation instructions. The independently checked sequence uses these functions (with the repository `tools` directory on `PYTHONPATH`):

```python
from pathlib import Path
from lol2.map_geometry import export_geometry
from lol2.map_ceiling_subdivisions import patch_geometry
from lol2.map_source_walls import export_source_walls
from lol2.map_materials import export_materials

game = Path('/path/to/original/game')
area = Path('/path/to/fresh/L4_HJ')
export_geometry(game, 'L4_HJ', area / 'geometry')
patch_geometry(area / 'geometry', game)
export_source_walls(game, 'L4_HJ', area / 'geometry', area / 'geometry')
export_materials(game, 'L4_HJ', area / 'materials')
```

Then follow [Jungle material extensions](jungle-material-extensions.md) to produce the compatibility material root from that fresh texture and material extraction. Use the resulting root below:

```sh
python3 tools/prepare_jungle_review.py \
  --game-root /path/to/original/game \
  --geometry /path/to/fresh/L4_HJ/geometry/geometry.json \
  --material-root /path/to/fresh/jungle_materials \
  --output-root /path/to/fresh/jungle_scene
```

The output is `jungle_scene/assets/lol2/generated/jungle_review`: `jungle.json` and 66 material PNGs. All referenced PNGs are checked before creating the output root. Existing output roots are refused. Original source pins are checked by the shared readers. Writes after preflight are sequential; an I/O failure can leave a partial fresh root.

Independent verification regenerated the 92 compatibility materials using published helpers, then built this 67-file scene and the 143-file chief-hut pack. Scene faces, UVs, material fields, presets, arrival and wall coverage match the historical scene. The scene has 10,476 faces and starts at `[353, 75, -4909]`. `geometry_sha256` deliberately records the actual fresh geometry bytes; fresh geometry metadata differs from the historical input, so that provenance field differs. No historical generated files were used as build inputs in this joined verification.

Pass the fresh scene directory above as `--jungle-review` and the fresh `L4_HJ` directory as `--map-root` to [chief-hut preparation](chief-hut-preparation.md). Runtime `res://` paths remain unchanged. Generated originals and caches remain private.

This explicit-input tool replaces the historical hardcoded preparation entry point. This recipe covers the Jungle scene and joined chief-hut preparation; it does not establish complete Act 1 assembly, native orientation, rendered playback or all actor and movie packs.
