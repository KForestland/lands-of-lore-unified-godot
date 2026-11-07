# Cave surface index preparation

Run from the source checkout with Python 3 and Pillow:

```sh
python3 tools/prepare_cave_surface_indices.py --texture /fresh/L1_DC/materials/texture.bin --floors /fresh/floors/assets/lol2/generated/original_floors --props /fresh/props/assets/lol2/generated/prop_review --output-root /fresh/surface-output
```

Prepare the inputs using the published original-floor and Cave-prop preparation commands and the L1_DC material exporter. The output root must not exist and must not overlap any input. The texture hash and complete material selections are checked. This command writes 13 floor and 19 prop grayscale index images plus their manifest under `assets/lol2/generated/surface_indices`.

Each image is decoded from the original first mip. Palette expansion must match the supplied floor RGB or prop RGBA preview exactly. Floor source layout is selected by that comparison, preserving the established floor import orientation; this is not new native orientation evidence. Prop index zero remains transparent, and unsupported special index one is refused. Floor image paths must stay within the floor input directory.

The entire 33-file pack was compared byte-for-byte against the existing runtime pack using freshly prepared floor and prop inputs. An isolated published-helper run loaded no native emulator or reverse-engineering modules; existing-output, missing-input, overlapping-output and wrong-texture controls refused. A later decode or image mismatch can leave an incomplete output directory; retain it for diagnosis and retry with another fresh root. Legacy exporters and runtime behavior are unchanged. This pack check does not establish whole-project clean assembly or gameplay acceptance.
