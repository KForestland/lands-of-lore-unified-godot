#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_hourglass pack (hourglass.png, hourglass.json, animation_0..2.png,
animation.json, stages.json) from explicit original game files.

  python3 tools/prepare_museum_hourglass_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_hourglass.py, verify_hourglass_pixels.py (export branch) and
export_hourglass_stages.py (all unchanged) with the originals and published readers:
- movie: DAT/L3_DHI.MIX entry SPHERE1\\L3_DH\\HRGLASS.VQA (lol2_source_format.parse_mix, lol2_movie_format.ww_hash_v1);
- resource 477 (hrglass.vqa descriptor) checked in the decoded L3_DH texture from lol2/map_materials.export_materials;
- record 226 (template 25 resource 477) placement, bounds, state and frame from lol2/map_props.export_props;
- all 300 frames rendered with the native-rule split-plane renderer of verify_hourglass_pixels.py, ported unchanged
  (VPTZ vectors, 4x2 codebook, CBFZ / 8-part CBPZ updates, 0xFF solid blocks, VGA 6-bit palette; VQFL checkpoints and
  vector bounds asserted), LCW from lol2_creature_sprite_format; the same magenta alpha key and 10x10 atlas pages;
- stages from the movie's LINF/LNIN chunks.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
frame is decoded and every check passes. No historical export, no RE checkout, no ffmpeg, no native replay.
"""
import argparse, hashlib, json, struct, sys, tempfile
from pathlib import Path

SOURCE_SHA = 'f7d8ee9632870b9b8fd8e82f4ebb78868c531630908dc704d3ef947b5bd5738a'  # HRGLASS.VQA entry
ORIGINALS = {'DAT/L3_DHI.MIX': 'bdbebdb475f7756357f1e9687f4a4a654c0817399fc728267c1b6d97d6663834',
             'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
MUSEUM_TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'
FILENAME = 'SPHERE1\\L3_DH\\HRGLASS.VQA'
PACK = 'assets/lol2/generated/museum_hourglass'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def chunks(data, start=0):  # as normalize_hourglass_vqa.chunks (that module needs the RE helper root at import)
    result = []; pos = start
    while pos < len(data):
        assert pos + 8 <= len(data)
        tag = data[pos:pos + 4]; size = struct.unpack_from('>I', data, pos + 4)[0]
        end = pos + 8 + size
        assert end + (size & 1) <= len(data)
        result.append([pos, tag, data[pos + 8:end]])
        pos = end + (size & 1)
    assert pos == len(data)
    return result


def render(raw, lcw):
    """verify_hourglass_pixels.py native-rule renderer, unchanged apart from the FFmpeg cross-check input."""
    import numpy as np
    header = next(d for _, t, d in chunks(raw, 12) if t == b'VQHD')
    assert struct.unpack_from('<HHH', header, 4) == (300, 320, 200) and header[10:14] == bytes([4, 2, 15, 8])
    book = None; parts = []; palette = None; checkpoints = 0; frames = []
    for _, tag, data in chunks(raw, 12):
        if tag == b'VQFL':
            snapshot = chunks(data); assert lcw(snapshot[0][2]) == book
            assert [d for _, t, d in snapshot[1:]] == parts; checkpoints += 1; continue
        if tag != b'VQFR': continue
        next_book = None; vectors = None
        for _, kind, payload in chunks(data):
            if kind == b'CPL0':
                pal = np.frombuffer(payload, dtype=np.uint8).reshape(-1, 3).astype(np.uint16)
                pal = pal & 63
                pal = ((pal << 2) | (pal >> 4)).astype(np.uint8)  # VGA6-bit channels; high bits discarded.
                palette = np.concatenate((pal, np.full((len(pal), 1), 255, dtype=np.uint8)), axis=1)
            elif kind == b'CBFZ': book = lcw(payload)
            elif kind == b'CBPZ':
                parts.append(payload)
                if len(parts) == 8: next_book = lcw(b''.join(parts)); parts = []
            elif kind == b'VPTZ': vectors = lcw(payload)
            else: raise ValueError(kind)
        assert vectors and len(vectors) == 16000 and book and palette is not None
        v = np.frombuffer(vectors, dtype=np.uint8).astype(np.uint16)
        index = v[:8000] + (v[8000:] << 8); solid = v[8000:] == 255
        assert np.all(index[~solid] < len(book) // 8)
        blocks = np.empty((8000, 8), dtype=np.uint8)
        blocks[solid] = v[:8000][solid, None]
        blocks[~solid] = np.frombuffer(book, dtype=np.uint8).reshape(-1, 8)[index[~solid]]
        pixels = blocks.reshape(100, 80, 2, 4).transpose(0, 2, 1, 3).reshape(200, 320)
        frames.append(palette[pixels].copy())
        if next_book is not None: book = next_book
    assert len(frames) == 300 and not parts and checkpoints == 3
    return frames


def stages(raw):
    """export_hourglass_stages.py, unchanged, on the movie bytes."""
    top = {tag: data for _, tag, data in chunks(raw, 12) if tag in (b'LINF', b'LNIN')}
    loops = {tag: data for _, tag, data in chunks(top[b'LINF'])}
    names = {tag: data for _, tag, data in chunks(top[b'LNIN'])}
    assert loops[b'LINH'] == bytes.fromhex('040002000000')
    assert names[b'LNIH'] == bytes.fromhex('04000000000036000000')
    ranges = list(struct.iter_unpack('<HH', loops[b'LIND']))
    offsets = struct.unpack('<4I', names[b'LNIO'])
    labels = [names[b'LNID'][o:].split(b'\0', 1)[0].decode('ascii') for o in offsets]
    assert ranges == [(0, 74), (75, 149), (150, 224), (225, 299)]
    assert labels == ['SandRunningOut', '2ndStageDecay', '3rdStageDecay', 'FinalDecay']
    return dict(source_sha256=SOURCE_SHA, stages=[dict(name=n, first=a, last=b) for n, (a, b) in zip(labels, ranges)],
                scope='Source LINF ranges and LNIN names. Inclusive endpoints cover all300 frames. Gameplay trigger mapping and native looping policy remain unresolved; restoration plays a selected stage once and holds.')


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if overlaps(a.output_root, a.game): p.error(f'--output-root overlaps input {a.game}')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from lol2_source_format import parse_mix
        from lol2_movie_format import ww_hash_v1
        from lol2_material_format import sections
        from lol2_creature_sprite_format import lcw
        import map_materials, map_props
        from PIL import Image
        import numpy as np
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    archive = (a.game / 'DAT/L3_DHI.MIX').read_bytes()
    try:
        key = ww_hash_v1(FILENAME); entry = next(e for e in parse_mix(archive) if e['key'] == key)
        assert entry['index'] == 3 and key == 2686739476, 'movie entry'
        movie = archive[entry['offset']:entry['offset'] + entry['size']]; assert digest(movie) == SOURCE_SHA, 'movie sha'
    except (AssertionError, StopIteration) as error:
        p.error('Original movie does not match: ' + (str(error) or type(error).__name__))
    with tempfile.TemporaryDirectory(prefix='museum-hourglass-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == MUSEUM_TEXTURE_SHA, 'museum texture'
            s = sections(blob); descriptor = struct.unpack_from('<6H11I', blob, s[2] + 477 * 56)
            payload = blob[s[3] + descriptor[7]:][:descriptor[12]]
            assert payload[:8] == bytes.fromhex('42034001c8001600') and payload[8:].rstrip(b'\0') == b'hrglass.vqa', 'resource477'
            map_props.export_props(a.game, 'L3_DH', tmp / 'props', tmp / 'materials')
            prop = next(q for q in json.loads((tmp / 'props/props.json').read_text())['props'] if q['record'] == 226)
            state, frame = bytes.fromhex(prop['state_hex']), bytes.fromhex(prop['frame_hex'])
            assert prop['template'] == 25 and prop['position'] == [1332, 10, -663] and (prop['left'], prop['right'], prop['top']) == (-50.0, 50.0, 62), 'record226'
            assert state[14:] == bytes([100, 62]) and frame[5:9] == bytes(4), 'record226 state/frame'
            frames = render(movie, lcw)
            stage = stages(movie)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
        out = a.output_root / PACK; out.mkdir(parents=True)
        # prepare_museum_hourglass.py: first frame with the provisional magenta key.
        im = Image.fromarray(frames[0].copy()).convert('RGBA')
        im.putdata([(r, g, b, 0 if r > 220 and b > 220 and g < 25 else 255) for r, g, b, _ in im.getdata()]); im.save(out / 'hourglass.png')
        (out / 'hourglass.json').write_text(json.dumps(dict(position=[1332, 10, -663], size=[100, 62], source_record=226,
            source_filename=FILENAME, source_entry=entry, source_sha256=SOURCE_SHA,
            scope='Source resource477 filename/full-path hash,placement and100x62 bounds matched. Native-rule decoded first frame only; magenta chroma key and fixed-Y billboard are restoration conventions. No animation,interaction,collision or progression claimed.'), indent=2) + '\n')
        # verify_hourglass_pixels.py export branch.
        pages = []
        for page in range(3):
            sheet = Image.new('RGBA', (3200, 2000))
            for cell, rgba in enumerate(frames[page * 100:(page + 1) * 100]):
                rgba[:, :, 3] = np.where((rgba[:, :, 0] > 220) & (rgba[:, :, 2] > 220) & (rgba[:, :, 1] < 25), 0, 255)
                sheet.paste(Image.fromarray(rgba), ((cell % 10) * 320, (cell // 10) * 200))
            name = f'animation_{page}.png'; sheet.save(out / name); pages.append(name)
        (out / 'animation.json').write_text(json.dumps(dict(source_sha256=SOURCE_SHA, frames=300, fps=15, width=320, height=200, columns=10, frames_per_page=100, pages=pages,
            scope='Verified source pixels; provisional magenta alpha key. In-world object frames; native event-to-frame selection remains unresolved.'), indent=2) + '\n')
        (out / 'stages.json').write_text(json.dumps(stage, indent=2) + '\n')
    print('PASS museum_hourglass: 300 native-rule frames, 3 pages, stages', [x['name'] for x in stage['stages']])


if __name__ == '__main__':
    main()
