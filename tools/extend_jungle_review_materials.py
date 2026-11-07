#!/usr/bin/env python3
"""Stage a legacy jungle material root for prepare_jungle_review.

  python3 -B tools/extend_jungle_review_materials.py \
      --game-root GAME --re-root RE --tools-root PUBLISHED_TOOLS \
      --texture TEXTURE.bin --base-materials CLEAN_MATERIALS --out OUT

OUT is a jungle_materials_20260914-style root: materials.json with
identity.blob_sha256, 92 material rows, and material_NNNN/mip_0_palette.png.
Sixty-six images are copied from the clean map_materials mip0 files. Twenty-six
are rebuilt here. Floors stay file-order opaque RGB for compatibility with the
historical review images. Walls use published decode_column_payload indices and
the Pillow 10.2.0 RGBA writer. alpha_cutout is set only on the 20 column walls.
Materials 85 and 655 keep the historical unset flag. intentional_differences
records each PNG and flag choice. The published decoder is loaded, not rewritten.

Before any base PNG is read, source.sha256, source_hash.archive_sha256,
decode.decoded_sha256, and source_hash.decoded_texture_sha256 must match the
pinned archive and texture. Those four fields do not validate the rest of the
base extraction. The 92 mip0 files must still exist before 66 of them are
copied. --out must not already exist and must not overlap a supplied input.
Publish then moves files one at a time. That is not an atomic directory
replacement. An I/O failure can leave a partial --out.
"""
import argparse
import hashlib
import importlib.util
import json
import shutil
import struct
import sys
import tempfile
from io import BytesIO
from pathlib import Path

# Published companion RE 2791eb11e453ad5cbccdce5d5d29efc1850a2d3c.
PALETTE_SHA256 = '1f621336414238ef3d8502d8b9d240e9d6cfe46dedcf1b90e37d587b7bbb6484'
SECTIONS_SHA256 = '8658170f0c0415d0656a5242b168b48c9cc6383d8cfdb0ad69ece1b062a90f0f'
CACHE_SHA256 = '60a6347fe53e47950c972ba902bf0d5ea9a97b734088a81facbedea81583b9b2'
# Publication d6bff86f3c5f7ad75239f24480bf41a64b56893f. Loaded, not rewritten.
# map_materials.py imports the other three while loading. The LZO helper is not called.
PUBLISHED_COMMIT = 'd6bff86f3c5f7ad75239f24480bf41a64b56893f'
MAP_MATERIALS_SHA256 = '95547a37263bb49b54b563ce39067ea31fb41cfa0ffea1b3cb02289171a66fe3'
MATERIAL_FORMAT_SHA256 = '61332945f41c75828382ae08dfd25498a4a988466714e2bb7589b103a05653c3'
SOURCE_FORMAT_SHA256 = 'e66046e1ad87559706b75e21822440b7ebc2753e9321b3d9e042f6e9ff2f4791'
TEXTURE_CONTAINER_SHA256 = '782717823195d60430fc1dd89bf1f22ba58b941ca897c7603453612d6283b45e'
TEXTURE_SHA256 = '98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'
ARCHIVE_SHA256 = '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'
PILLOW_VERSION = '10.2.0'
FLOOR_SCOPE = ('Compatibility with the historical jungle-review images: variant 0 '
               'mip0 is opaque RGB in raw file order. This is not a native '
               'row-orientation claim.')
WALL_SCOPE = ('Published map_materials.decode_column_payload mip0 (0x12621C, '
              'repeat_le2) with index 0 transparent, written by Pillow 10.2.0 RGBA.')
BASE_HASH_FIELDS = (
    'source.sha256',
    'source_hash.archive_sha256',
    'decode.decoded_sha256',
    'source_hash.decoded_texture_sha256',
)
PUBLISH_NOTE = ('Sequential moves into a fresh directory. This is not an atomic '
                'directory replacement. An I/O failure can leave a partial --out.')
FLOORS = (41, 85, 618, 655, 808, 849)
WALLS = (88, 452, 469, 471, 472, 473, 498, 528, 542, 615, 733, 734, 736, 738,
         743, 747, 749, 766, 770, 1034)
# 0xe1 floors: orientation only. 0x8b floors: orientation plus the unset cutout flag.
FLOOR_ROWS = (41, 618, 808, 849)
FLOOR_ALPHA = (85, 655)
PNG_DIFFERENCES = (
    41, 85, 88, 452, 471, 472, 473, 498, 528, 542, 615, 618, 655, 733, 734, 736,
    738, 743, 747, 749, 766, 770, 808, 849, 1034,
)
REQUIRED = (
    5, 41, 62, 65, 66, 67, 68, 69, 71, 85, 88, 91, 92, 93, 94, 95, 96, 97, 98,
    100, 101, 113, 114, 452, 466, 467, 469, 471, 472, 473, 475, 476, 477, 478,
    492, 497, 498, 513, 514, 528, 541, 542, 543, 544, 545, 546, 547, 548, 549,
    550, 551, 552, 553, 554, 555, 556, 615, 617, 618, 655, 656, 657, 714, 722,
    732, 733, 734, 736, 737, 738, 740, 743, 744, 745, 747, 749, 750, 754, 766,
    770, 772, 776, 777, 778, 804, 805, 807, 808, 849, 1031, 1034, 1035,
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def sha_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def check(condition, message):
    if not condition:
        fail(message)


def overlaps(left, right):
    return left == right or right in left.parents or left in right.parents


def base_hashes_match(report):
    """True only when the four published report hashes equal the pins.

    A present materials.json is not enough. Missing keys fail the check.
    """
    if not isinstance(report, dict):
        return False
    source = report.get('source')
    decode = report.get('decode')
    source_hash = report.get('source_hash')
    if not isinstance(source, dict) or not isinstance(decode, dict) or not isinstance(source_hash, dict):
        return False
    return (
        source.get('sha256') == ARCHIVE_SHA256
        and source_hash.get('archive_sha256') == ARCHIVE_SHA256
        and decode.get('decoded_sha256') == TEXTURE_SHA256
        and source_hash.get('decoded_texture_sha256') == TEXTURE_SHA256
    )


def load_published_decoder(tools_root):
    """Load decode_column_payload from the pinned publication file.

    The file must live at <tools-root>/tools/lol2/map_materials.py so its
    parents[2] path insert finds the sibling format modules.
    """
    path = tools_root / 'tools/lol2/map_materials.py'
    spec = importlib.util.spec_from_file_location('lol2_published_map_materials', path)
    if spec is None or spec.loader is None:
        fail(f'cannot load published decoder {path}')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    decode = getattr(module, 'decode_column_payload', None)
    if decode is None:
        fail('published map_materials.py has no decode_column_payload')
    return decode


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True)
    parser.add_argument('--tools-root', type=Path, required=True,
                        help='Directory whose tools/lol2/map_materials.py is publication d6bff86.')
    parser.add_argument('--texture', type=Path, required=True)
    parser.add_argument('--base-materials', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--fail-before-publish', action='store_true',
                        help='Build every image, then exit 1 before creating --out.')
    args = parser.parse_args()
    try:
        game_root, re_root, tools_root, texture, base = (
            path.resolve() for path in (
                args.game_root, args.re_root, args.tools_root, args.texture, args.base_materials))
        out = args.out.resolve()
    except OSError as exc:
        parser.error(f'cannot resolve a path: {exc}')
    if out.exists():
        parser.error('--out must not already exist')
    supplied = (game_root, re_root, tools_root, texture, base)
    if any(overlaps(out, path) for path in supplied):
        parser.error('--out overlaps a supplied input')
    pins = {
        re_root / 'tools/draracle/lol2_palette_png.py': PALETTE_SHA256,
        re_root / 'tools/draracle/lol2_wall_material_checkpoint.py': SECTIONS_SHA256,
        re_root / 'tools/draracle/lol2_cache_named_wall_fixture.py': CACHE_SHA256,
        tools_root / 'tools/lol2/map_materials.py': MAP_MATERIALS_SHA256,
        tools_root / 'tools/lol2_material_format.py': MATERIAL_FORMAT_SHA256,
        tools_root / 'tools/lol2_source_format.py': SOURCE_FORMAT_SHA256,
        tools_root / 'tools/lol2_texture_container.py': TEXTURE_CONTAINER_SHA256,
    }
    for path, digest in pins.items():
        if not path.is_file() or sha_file(path) != digest:
            parser.error(f'{path}: missing or not the pinned helper {digest}')
    try:
        import PIL
        from PIL import Image
    except ModuleNotFoundError:
        parser.error('Pillow is not installed')
    if PIL.__version__ != PILLOW_VERSION:
        parser.error(f'Pillow {PIL.__version__} is not the pinned {PILLOW_VERSION} encoder')
    archive_path = game_root / 'DAT/L4_HJ.MIX'
    if not archive_path.is_file():
        parser.error(f'missing original {archive_path}')
    if sha_file(archive_path) != ARCHIVE_SHA256:
        fail('L4_HJ.MIX differs from the pinned original')
    if not texture.is_file():
        parser.error(f'missing texture {texture}')
    blob = texture.read_bytes()
    if sha(blob) != TEXTURE_SHA256:
        fail('texture differs from the pinned L4_HJ blob')
    base_json = base / 'materials.json'
    if not base_json.is_file():
        parser.error(f'missing {base_json}')
    try:
        base_report = json.loads(base_json.read_text())
    except json.JSONDecodeError:
        parser.error(f'{base_json} is not JSON')
    if not base_hashes_match(base_report):
        fail('base materials report source/texture hashes do not match the pinned archive and texture')
    base_bytes = {}
    missing = []
    for index in REQUIRED:
        path = base / f'material_{index:04d}' / 'mip_0_palette.png'
        if not path.is_file():
            missing.append(index)
        else:
            base_bytes[index] = path.read_bytes()
    if missing:
        parser.error(f'base materials missing mip0 for {missing}')
    materials = base_report.get('materials') if isinstance(base_report, dict) else None
    if not isinstance(materials, list):
        parser.error('base materials.json has no materials list')
    base_rows = {row['index']: row for row in materials if isinstance(row, dict) and 'index' in row}
    absent_rows = [index for index in REQUIRED if index not in base_rows]
    if absent_rows:
        parser.error(f'base materials.json missing rows {absent_rows}')
    sys.path[:0] = [str(re_root / 'tools/draracle')]
    from lol2_palette_png import colorize, png_rgb, rgb_palette
    from lol2_wall_material_checkpoint import sections
    decode_column_payload = load_published_decoder(tools_root)

    offsets = sections(blob)
    end = min(offset for offset in offsets if offset > offsets[3])
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    rgb = rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    groups = {}
    for index in range(256):
        groups.setdefault(rgb[index * 3:index * 3 + 3], []).append(index)
    duplicates = sorted(indices for indices in groups.values() if len(indices) > 1)
    check(duplicates == [[0, 3], [1, 2], [112, 255]], 'palette duplicate groups changed')

    images = {}
    floor_records = []
    for index in FLOORS:
        view = struct.unpack_from('<6H11I', blob, offsets[2] + index * 56)
        width, height, flags, variants = view[1:5]
        levels = view[5] & 255
        check(flags in (0xe1, 0x8b) and 1 <= variants <= 9, f'material {index} floor flags')
        check(levels == 5, f'material {index} floor mip count')
        checks = 0
        staged = None
        for level in range(levels):
            level_width, level_height = max(1, width >> level), max(1, height >> level)
            size = view[12 + level]
            start = offsets[3] + view[7 + level]
            check(size == 8 + level_width * level_height and start + variants * size <= end,
                  f'material {index} floor span')
            if level < levels - 1:
                check(view[7 + level] + variants * size == view[8 + level], f'material {index} floor packing')
            for variant in range(variants):
                pos = start + variant * size
                check(struct.unpack_from('<4H', blob, pos) == (flags, level_width, level_height,
                                                                (level_width * level_height) & 65535),
                      f'material {index} floor header')
                checks += 1
                if level == 0 and variant == 0:
                    pixels = blob[pos + 8:pos + size]
                    staged = png_rgb(width, height, colorize(pixels, rgb))
        images[index] = staged
        floor_records.append(dict(index=index, width=width, height=height, flags=flags,
                                   variant_count=variants, validated_images=checks, scope=FLOOR_SCOPE))

    wall_records = []
    for index in WALLS:
        view = struct.unpack_from('<6H11I', blob, offsets[2] + index * 56)
        width, height, flags, variants = view[1:5]
        levels = view[5] & 255
        check(flags in (0x8f, 0x808f) and variants == 1 and 1 <= levels <= 5, f'material {index} wall flags')
        mip_checks = []
        for level in range(levels):
            start, size = offsets[3] + view[7 + level], view[12 + level]
            check(offsets[3] <= start < start + size <= end, f'material {index} wall span')
            if level < levels - 1:
                check(start + size == offsets[3] + view[8 + level], f'material {index} wall packing')
            payload = blob[start:start + size]
            payload_flags, level_width, level_height, length = struct.unpack_from('<4H', payload)
            check((level_width, level_height) == (max(1, width >> level), max(1, height >> level)),
                  f'material {index} wall size')
            check(length == size - 8, f'material {index} wall length')
            if payload_flags in (0x8f, 0x808f):
                pixels, unproven = decode_column_payload(payload[8:], level_width, level_height)
                check(unproven is False and len(pixels) == level_width * level_height,
                      f'material {index} decoded size')
            else:
                check(payload_flags in (0x8b, 0x808b) and length == level_width * level_height,
                      f'material {index} raw lower mip')
                pixels = None
            mip_checks.append(dict(level=level, flags=payload_flags, width=level_width, height=level_height,
                                    payload_sha256=sha(payload)))
            if level == 0:
                check(pixels is not None, f'material {index} mip0 was not a column payload')
                rgba = bytes(channel for pixel in pixels for channel in (*rgb[pixel * 3:pixel * 3 + 3], 255 if pixel else 0))
                stream = BytesIO()
                Image.frombytes('RGBA', (level_width, level_height), rgba).save(stream, format='PNG')
                images[index] = stream.getvalue()
        wall_records.append(dict(index=index, width=width, height=height, flags=flags, variant_count=variants,
                                  alpha_cutout=True, mip_checks=mip_checks, scope=WALL_SCOPE))

    check(set(images) == set(FLOORS) | set(WALLS), 'extender image set')
    published = {index: images[index] if index in images else base_bytes[index] for index in REQUIRED}
    same_as_base = sorted(index for index in images if images[index] == base_bytes[index])
    extended = {record['index']: record for record in floor_records + wall_records}
    material_rows = []
    for index in REQUIRED:
        clean = base_rows[index]
        if index in extended:
            record = extended[index]
            width, height, flags = record['width'], record['height'], record['flags']
            check((clean['width'], clean['height'], clean['flags']) == (width, height, flags),
                  f'material {index} clean row differs from the extender descriptor')
        else:
            width, height, flags = clean['width'], clean['height'], clean['flags']
        row = dict(index=index, width=width, height=height, flags=flags)
        if index in WALLS:
            check(clean.get('alpha_cutout') is True, f'material {index} clean alpha flag')
            row['alpha_cutout'] = True
        elif index in FLOOR_ALPHA:
            check(clean.get('alpha_cutout') is True, f'material {index} clean 0x8b alpha flag')
        else:
            check(not clean.get('alpha_cutout', False), f'material {index} unexpected clean alpha_cutout')
        material_rows.append(row)
    difference_by_index = {}
    for index in FLOOR_ROWS:
        difference_by_index[index] = dict(
            index=index, kind='floor_row_major',
            png=('Opaque RGB in raw file order. Clean mip0 is the same palette after '
                 'column-major-to-rows, also RGB.'),
            alpha_cutout_emitted='unset', alpha_cutout_historical='unset', alpha_cutout_clean=False,
            reason=('File-order opaque RGB is compatibility with the historical review images. '
                    'This is not a native-orientation claim. alpha_cutout stays unset. Width and '
                    'height stay the clean descriptor values.'),
        )
    for index in FLOOR_ALPHA:
        difference_by_index[index] = dict(
            index=index, kind='floor_row_major_and_alpha',
            png=('Opaque RGB in raw file order, with no alpha channel. Clean mip0 is '
                 'column-major rows in RGBA, transparent where the index is 0.'),
            alpha_cutout_emitted='unset', alpha_cutout_historical='unset', alpha_cutout_clean=True,
            reason=('File-order opaque RGB is compatibility with the historical review images. '
                    'This is not a native-orientation claim. alpha_cutout stays unset. Setting the '
                    'clean flag would mark a cutout on an image that has no alpha channel.'),
        )
    for index in WALLS:
        if index == 469:
            continue
        difference_by_index[index] = dict(
            index=index, kind='wall_png_container',
            png=('Same indices and the same index-0 alpha as the clean mip0. Indices are '
                 'published decode_column_payload. Historical bytes are Pillow 10.2.0 RGBA. '
                 'Clean bytes are map_materials._png_rgba_bytes.'),
            alpha_cutout_emitted=True, alpha_cutout_historical=True, alpha_cutout_clean=True,
            reason=('alpha_cutout stays true. Published decoder indices match the clean mip0 '
                    'on this texture. The PNG container is Pillow 10.2.0 RGBA.'),
        )
    differences = [difference_by_index[index] for index in PNG_DIFFERENCES]
    check([item['index'] for item in differences] == list(PNG_DIFFERENCES), 'difference index order')
    materials_json = dict(
        identity=dict(blob_sha256=TEXTURE_SHA256),
        materials=material_rows,
        intentional_differences=differences,
        scope=('Legacy jungle_materials_20260914 layout: identity.blob_sha256, 92 material rows, '
               'and material_NNNN/mip_0_palette.png. alpha_cutout is set only on the 20 column walls. '
               'Materials 85 and 655 keep the historical unset flag. Floor mip0 images stay file-order '
               'opaque RGB for compatibility with the historical review images. Wall indices come from '
               'published decode_column_payload and the PNG writer is Pillow 10.2.0 RGBA. '
               'intentional_differences lists every PNG and flag choice that differs from clean '
               'map_materials. The 66 unchanged images are copied only after the four base report '
               'hashes match the pinned archive and texture. Those hashes do not validate the rest '
               'of the base extraction. ' + PUBLISH_NOTE),
    )
    provenance = dict(
        texture_sha256=TEXTURE_SHA256,
        archive_sha256=ARCHIVE_SHA256,
        pillow=PILLOW_VERSION,
        published_decoder_commit=PUBLISHED_COMMIT,
        column_decoder='tools/lol2/map_materials.py:decode_column_payload',
        column_decoder_sha256=MAP_MATERIALS_SHA256,
        checked_before_base_copy=list(BASE_HASH_FIELDS),
        not_validated_by_those_hashes=[
            'texture_payload_sha256',
            'rejected entries',
            'base images other than the 92 required mip0 files',
            'lower mips of the copied materials',
        ],
        required_count=len(REQUIRED),
        copied_from_base=sorted(set(REQUIRED) - set(images)),
        same_as_base=same_as_base,
        palette_duplicate_indices=duplicates,
        extended_raw_variants=floor_records,
        extended_column_walls=wall_records,
        materials_json='materials.json',
        publish=PUBLISH_NOTE,
        scope=('Ninety-two historical jungle-review mip0 images. Sixty-six are clean '
               'map_materials bytes copied from the clean base after the report hashes match. '
               'Six floors are file-order opaque RGB kept for compatibility with the historical '
               'review images. Twenty walls use published decode_column_payload indices and '
               'Pillow 10.2.0 RGBA. materials.json keeps the legacy identity, 92 rows, and '
               'historical alpha_cutout flags. ' + PUBLISH_NOTE),
    )
    if args.fail_before_publish:
        fail('stopped before publish')
    # Parents of --out may be created. --out itself is created here, then filled
    # by sequential moves. A failure in that loop can leave a partial directory.
    out.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='.jungle-materials-', dir=out) as tmp:
        stage = Path(tmp)
        staged = []
        for index in REQUIRED:
            folder = stage / f'material_{index:04d}'
            folder.mkdir()
            target = folder / 'mip_0_palette.png'
            target.write_bytes(published[index])
            staged.append((target, out / folder.name / target.name))
        sidecar = stage / 'provenance.json'
        sidecar.write_text(json.dumps(provenance, indent=2) + '\n')
        staged.append((sidecar, out / sidecar.name))
        catalog = stage / 'materials.json'
        catalog.write_text(json.dumps(materials_json, indent=2) + '\n')
        staged.append((catalog, out / catalog.name))
        for source, target in staged:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(target))
    print(f'Staged {len(REQUIRED)} jungle-review mip0 images; '
          f'{len(floor_records)} floors and {len(wall_records)} walls extended.')


if __name__ == '__main__':
    main()
