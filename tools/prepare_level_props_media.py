#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_props or hive_props pack (props.json and every image it names)
from explicit original game files.

  python3 tools/prepare_level_props_media.py --level museum --game GAME --output-root FRESH
  python3 tools/prepare_level_props_media.py --level hive --game GAME --output-root FRESH

Both packs come from export_museum_props.py (museum directly, hive through prepare_hive_props.py, which copies the
export unchanged; both unchanged). This tool runs that exporter's logic unchanged, with its historical inputs replaced
by the originals and published readers:
- the level archive (DAT/L3_DH.MIX or DAT/L5_HC.MIX) through lol2_source_format.parse_mix / build_game_atlas.u32;
- the texture blob is a fresh lol2/map_materials.export_materials texture.bin of the same level, asserted equal to the
  exporter's pinned blob hash;
- lol2_material_format.sections / rgb_palette and lol2_creature_sprite_format.decode_rows (source-identical to the RE
  readers the exporter imported, with the same ValueError rejections).
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
image is decoded and every check passes. No historical export, no RE checkout, no executable.
"""
import argparse, hashlib, io, json, struct, sys, tempfile
from pathlib import Path

LEVELS = {  # export_museum_props.py pins: archive, its sha, blob sha, metadata key, geometry key
    'museum': ('L3_DH', 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
               '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07', 3105896470, 3106551060, 'museum_props'),
    'hive': ('L5_HC', 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
             'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba', 3776335874, 3776990464, 'hive_props'),
}


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def export(level, mix, blob, parse_mix, u32, sections, decode_rows, rgb_palette, Image):
    """export_museum_props.py main(), unchanged apart from collecting files in memory instead of writing a.out."""
    mix_hash, blob_hash, meta_key, geo_key = LEVELS[level][1], LEVELS[level][2], LEVELS[level][3], LEVELS[level][4]
    if hashlib.sha256(mix).hexdigest() != mix_hash or hashlib.sha256(blob).hexdigest() != blob_hash: raise ValueError('Source changed')
    files = {}
    es = parse_mix(mix); me = next(e for e in es if e['key'] == meta_key); ge = next(e for e in es if e['key'] == geo_key)
    meta = mix[me['offset']:me['offset'] + me['size']]; geo = mix[ge['offset']:ge['offset'] + ge['size']]
    off, count = u32(meta, 8), u32(meta, 0x40); so = off + count * 55 + 4; state_count = u32(meta, so - 4); fo = so + state_count * 16 + 4; frame_count = u32(meta, fo - 4)
    if fo + frame_count * 12 > len(meta): raise ValueError('Frame table exceeds entry')
    state = frame = 0; templates = {}
    for t in range(count):
        d = meta[off + t * 55:off + (t + 1) * 55]; n = d[46] + d[47]
        for selector in range(n):
            if state >= state_count: raise ValueError('State outside table')
            s = meta[so + state * 16:so + (state + 1) * 16]; c = struct.unpack_from('<b', s, 13)[0]; nf = 1 if c < 0 else c
            if frame + nf > frame_count: raise ValueError('State frame range outside table')
            if n == 1 and c == 1 and d[50] == 0:
                f = meta[fo + frame * 12:fo + (frame + 1) * 12]
                templates[t] = dict(descriptor=struct.unpack_from('<h', f)[0], left=-s[14] / 2 + f[5], right=s[14] / 2 - f[7], bottom=f[8], top=s[15] - f[6], frame_flags=f[2], template_hex=d.hex(), state_hex=s.hex(), frame_hex=f.hex(), state_offset=me['offset'] + so + state * 16, frame_offset=me['offset'] + fo + frame * 12)
            state += 1; frame += nf
    if state != state_count or frame != frame_count: raise ValueError('Unaccounted states/frames')
    sec = sections(blob); descriptors = (sec[3] - sec[2]) // 56; paloff = u32(blob, 4); pal = rgb_palette(blob[paloff:paloff + 768], 6)

    def save(name, w, h, rgba):
        stream = io.BytesIO(); Image.frombytes('RGBA', (w, h), rgba).save(stream, format='PNG'); files[name] = stream.getvalue()
    images = {}; rejected = []; props = []
    for t, info in templates.items():
        k = info['descriptor']
        if k in images: continue
        try:
            if not 0 <= k < descriptors: raise ValueError('Descriptor outside table')
            v = struct.unpack_from('<6H11I', blob, sec[2] + k * 56)
            if v[3] == 0x2c6 and k in [187, 363]:
                if not 1 <= v[4] <= 64: raise ValueError('Sequence count invalid')
                pos = sec[3] + v[7]; frames = []
                for variant in range(v[4]):
                    size = 8 + struct.unpack_from('<H', blob, pos + 6)[0]
                    if variant == 0 and size != v[12]: raise ValueError('First frame size mismatch')
                    w, h, indices, _ = decode_rows(blob[pos:pos + size], expected_flags=0x2c6)
                    if (w, h) != (v[1], v[2]): raise ValueError('Sequence dimensions differ')
                    name = f'prop_{k}_frame_{variant}.png'
                    rgba = bytes(c for i in indices for c in [*pal[i * 3:i * 3 + 3], 255 if i else 0])
                    save(name, w, h, rgba)
                    frames.append(dict(file=name, payload_sha256=hashlib.sha256(blob[pos:pos + size]).hexdigest()))
                    pos += size
                if pos != sec[3] + v[8]: raise ValueError('Sequence/mip boundary mismatch')
                images[k] = dict(file=frames[0]['file'], width=w, height=h, frames=frames, preview_fps=10, scope='Authored decorative loop rate; native timing/phase unverified')
                continue
            if v[3] != 0x28e or v[4] != 1: raise ValueError('Not a supported ordinary sprite or selected decorative sequence')
            start = sec[3] + v[7]; size = v[12]
            if start + size > len(blob): raise ValueError('Sprite payload exceeds blob')
            w, h, indices, marked = decode_rows(blob[start:start + size])
            if (w, h) != (v[1], v[2]): raise ValueError('Sprite dimensions differ')
            rgba = bytes(c for i in indices for c in [*pal[i * 3:i * 3 + 3], 255 if i else 0])
            name = f'prop_{k}.png'; save(name, w, h, rgba)
            images[k] = dict(file=name, width=w, height=h, payload_sha256=hashlib.sha256(blob[start:start + size]).hexdigest())
        except ValueError as e: rejected.append(dict(template=t, descriptor=k, reason=str(e)))
    for i in range(u32(geo, 0x60)):
        off = u32(geo, 0x14) + i * 37; d = geo[off:off + 37]
        if len(d) != 37: raise ValueError('Truncated placement')
        t = struct.unpack_from('<H', d, 32)[0]
        if t not in templates or d[35] != 0: continue
        info = templates[t]
        if info['descriptor'] not in images or info['right'] <= info['left'] or info['top'] <= info['bottom']: continue
        x, y, z = [struct.unpack_from('<h', d, k)[0] for k in [0, 2, 6]]
        region = struct.unpack_from('<H', d, 10)[0]
        if region >= u32(geo, 0x58): raise ValueError('Placement region outside map')
        props.append(dict(record=i, template=t, position=[x, z, -y], region=region, placement_offset=ge['offset'] + off, placement_hex=d.hex(), **info))
    report = dict(mix_sha256=mix_hash, blob_sha256=blob_hash, templates=count, states=state_count, frames=frame_count, images=images, props=props, rejected=rejected, scope='Single-state/frame source placements and sprite bounds. Index0 alpha and fixed-Y billboarding are review conventions. Activation, collision, interaction and native rendering parity unverified; unsupported classes omitted.')
    files['props.json'] = (json.dumps(report, indent=2) + '\n').encode()
    named = {v['file'] for v in images.values()} | {f['file'] for v in images.values() for f in v.get('frames', [])}
    assert named | {'props.json'} == set(files), 'every staged image is named by props.json'
    if level == 'hive':
        # Preserve the existing unreferenced first-frame artifact from original resource62.
        # It is byte-identical to the separately prepared Hive quest-pillar sprite.
        v = struct.unpack_from('<6H11I', blob, sec[2] + 62 * 56)
        assert v[3] == 0x2c6
        payload = blob[sec[3] + v[7]:sec[3] + v[7] + v[12]]
        w, h, indices, _ = decode_rows(payload, expected_flags=0x2c6)
        assert (w, h) == v[1:3]
        rgba = bytes(c for i in indices for c in [*pal[i * 3:i * 3 + 3], 255 if i else 0])
        save('prop_62_frame_0.png', w, h, rgba)
        assert digest(files['prop_62_frame_0.png']) == '79c5b2f39f35f677f91a38e3bd42bfd074c00d3eca228a294dcf36e2285e581a'
    return report, files


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--level', choices=sorted(LEVELS), required=True)
    for name in ['game', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if overlaps(a.output_root, a.game): p.error(f'--output-root overlaps input {a.game}')
    area, mix_sha, blob_sha, _, _, pack = LEVELS[a.level]
    rel = f'DAT/{area}.MIX'
    if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
    mix = (a.game / rel).read_bytes()
    if digest(mix) != mix_sha: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from lol2_source_format import parse_mix
        from build_game_atlas import u32
        from lol2_material_format import sections, rgb_palette
        from lol2_creature_sprite_format import decode_rows
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    with tempfile.TemporaryDirectory(prefix='level-props-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, area, tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes()
            assert digest(blob) == blob_sha, f'{area} texture is not the exporter blob'
            report, files = export(a.level, mix, blob, parse_mix, u32, sections, decode_rows, rgb_palette, Image)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / 'assets/lol2/generated' / pack; out.mkdir(parents=True)
    for name, data in sorted(files.items()): (out / name).write_bytes(data)
    print(f'PASS {pack}: sprites', len(report['images']), 'placements', len(report['props']),
          'deferred template decodes', len(report['rejected']), 'files', len(files))


if __name__ == '__main__':
    main()
