# Jungle review material extensions

The historical jungle-review tree has 92 material folders. Sixty-seven `mip_0_palette.png` files match a clean `L4_HJ` `map_materials.py` extraction. This tool rebuilds those 92 mip0 images from explicit paths. It does not assemble jungle geometry, presets, arrival, or `jungle_review`.

```sh
python3 -B tools/extend_jungle_review_materials.py \
  --game-root /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re-2791eb1 \
  --tools-root /path/to/publication-d6bff86 \
  --texture /path/to/L4_HJ/materials/texture.bin \
  --base-materials /path/to/L4_HJ/materials \
  --out /path/to/fresh/jungle_materials
```

`--tools-root` is the directory that contains `tools/lol2/map_materials.py`. `python3 -S` is not used. Pillow 10.2.0 is a site package, and the wall bytes use that encoder. `--out` must not already exist.

## Pins

| Input | sha256 |
| --- | --- |
| `DAT/L4_HJ.MIX` | `517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f` |
| texture blob | `98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b` |
| `tools/draracle/lol2_palette_png.py` | `1f621336414238ef3d8502d8b9d240e9d6cfe46dedcf1b90e37d587b7bbb6484` |
| `tools/draracle/lol2_wall_material_checkpoint.py` | `8658170f0c0415d0656a5242b168b48c9cc6383d8cfdb0ad69ece1b062a90f0f` |
| `tools/draracle/lol2_cache_named_wall_fixture.py` | `60a6347fe53e47950c972ba902bf0d5ea9a97b734088a81facbedea81583b9b2` |
| `tools/lol2/map_materials.py` | `95547a37263bb49b54b563ce39067ea31fb41cfa0ffea1b3cb02289171a66fe3` |
| `tools/lol2_material_format.py` | `61332945f41c75828382ae08dfd25498a4a988466714e2bb7589b103a05653c3` |
| `tools/lol2_source_format.py` | `e66046e1ad87559706b75e21822440b7ebc2753e9321b3d9e042f6e9ff2f4791` |
| `tools/lol2_texture_container.py` | `782717823195d60430fc1dd89bf1f22ba58b941ca897c7603453612d6283b45e` |

The three `draracle` files are published RE commit `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`. The four `tools/lol2*` files are publication `d6bff86f3c5f7ad75239f24480bf41a64b56893f`. `map_materials.py` imports the format modules and `lol2_texture_container.py` when it loads. The exporter calls `decode_column_payload` only. It does not call the LZO decoder, and it does not rewrite the published file. The patch does not vendor those files.

The original MIX is hash-checked and is not decoded again. The texture file is hash-checked against the same pin.

## Base report before the 66 copies

After the archive file and the texture file match their pins, and before any base `mip_0_palette.png` is read, the base `materials.json` must contain all four of these fields with those same pins:

| Report field | Must equal |
| --- | --- |
| `source.sha256` | pinned `DAT/L4_HJ.MIX` |
| `source_hash.archive_sha256` | pinned `DAT/L4_HJ.MIX` |
| `decode.decoded_sha256` | pinned texture blob |
| `source_hash.decoded_texture_sha256` | pinned texture blob |

A missing field fails this check. The check does not validate `texture_payload_sha256`, rejected descriptors, base images other than the 92 required mip0 files, or lower mips of the copied materials. Existence of `materials.json` is not that check. After the four hashes match, the 92 `material_NNNN/mip_0_palette.png` files and the 92 material rows must be present. That presence is what allows the 66 unchanged images to be copied. It is not a validation of the rest of the extraction. The tool does not re-decode those 66 images.

## What is written

OUT is the legacy material root `prepare_jungle_review.py` reads through `--material-root`. It contains `materials.json` and `material_XXXX/mip_0_palette.png` for the 92 historical indices, plus `provenance.json`.

`materials.json` has `identity.blob_sha256` `98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b` and 92 rows sorted by index. Each row has `index`, `width`, `height`, and `flags`. `alpha_cutout` is present and true only for the 20 column walls. Materials 85 and 655 leave the key unset. Clean `map_materials.py` sets `alpha_cutout` true for those two because the flag is `0x8b`. Width, height, and flags match the clean rows, so floor and wall UV scales stay on the same dimensions.

`intentional_differences` has one entry for each of the 25 PNGs that differ from clean. The 85 and 655 entries record both the file-order opaque RGB image and the unset cutout flag. Setting the clean flag would mark a cutout on a PNG that has no alpha channel. The 19 wall entries record a Pillow container around the same pixels and the same true flag. Material 469 matches clean bytes and keeps `alpha_cutout` true, so it is not a difference entry.

Indices 41, 85, 618, 655, 808, and 849 use the floor rule. Variant 0 mip0 is the raw slot payload colorized in file order and written with `png_rgb`. There is no column-major transpose and no index-0 alpha. That file order is compatibility with the historical review images. The recorded scope is `Compatibility with the historical jungle-review images: variant 0 mip0 is opaque RGB in raw file order. This is not a native row-orientation claim.`

The 20 wall indices call published `decode_column_payload(payload[8:], width, height)` with `repeat_le2=True` (original `0x12621C`) and write mip0 with Pillow `Image.frombytes('RGBA', ...).save`. Index 0 is transparent. Lower mips are size-checked only. The recorded scope is `Published map_materials.decode_column_payload mip0 (0x12621C, repeat_le2) with index 0 transparent, written by Pillow 10.2.0 RGBA.`

The other 66 images are the clean base `mip_0_palette.png` bytes. Material 469 is rebuilt and matches that base file: it is a 16×16 empty column image.

## Paths and publish

`--out` must not already exist. It must not be the same path as, inside, or a parent of `--game-root`, `--re-root`, `--tools-root`, `--texture`, or `--base-materials`. The tool has no machine-specific output denylist.

Images are built in memory first. `--fail-before-publish` exits 1 before creating `--out`. On a normal run the tool creates `--out`, stages the files in a temporary directory inside it, and then moves each `material_NNNN` directory, `provenance.json`, and `materials.json` one at a time. Those moves are sequential. They are not an atomic directory replacement. An I/O failure during a move can leave a partial `--out`. The partial directory is left in place. A later run refuses it because `--out` must not already exist. Remove the partial directory before retrying.

A missing path or a helper whose bytes differ from the pin exits 2. A MIX file, texture file, or base report whose checked hash differs exits 1. This tool does not run `prepare_jungle_review.py`. Independent verification joined its 92 images to freshly generated geometry, reproducing the 67-file Jungle scene and 143-file chief-hut pack.

## Measured difference from clean map_materials

Same DAC palette. Shade row 64 is not applied. Duplicate DAC colors are indices `(0, 3)`, `(1, 2)`, and `(112, 255)`.

Materials 41, 618, 808, and 849 are `0xe1`. Clean transposes the column-major raw pixels into rows. The historical images store those bytes directly in file order. Both files are RGB. The file-order images are the compatibility choice.

Materials 85 and 655 are `0x8b`. They have that same order difference, and clean also writes index-0 transparency. The historical files are opaque RGB. Their `alpha_cutout` key stays unset.

The 20 wall index buffers match the published column decoder on this texture: no run lead is 1 or 2. Alpha policy matches. Nineteen historical wall PNG files differ from clean only in the PNG container. Pillow 10.2.0 reproduces the historical bytes. `map_materials._png_rgba_bytes` reproduces the clean bytes.

Native orientation and playback remain unverified. The separately verified Jungle assembly preserves the historical scene semantics; its geometry provenance hash records the actual fresh input. This preparation does not integrate the images.
