#!/usr/bin/env python3
"""Recover original HUD frame and neutral portrait; source archives stay read-only.

No-argument use keeps the legacy game directory and writes under the repository
that contains this script. Pass --game and --output-root for a clean run.
The MIX reader is the published lol2_source_format.parse_mix (same body as the former RE helper); no LOL2_RE_ROOT is needed.
"""
import argparse
import hashlib
import json
import struct
import sys
import tempfile
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix  # same body as RE lol2_extract_draracle_geometry.parse_mix


def lcw(src, limit):
    out = bytearray()
    pos = 0
    def read(n):
        nonlocal pos
        assert pos + n <= len(src)
        result = src[pos:pos+n]
        pos += n
        return result
    while True:
        code = read(1)[0]
        if code == 0x80:
            assert pos == len(src)
            return bytes(out)
        if code < 0x80:
            count = (code >> 4) + 3
            offset = len(out) - (((code & 15) << 8) | read(1)[0])
        elif code < 0xc0:
            out.extend(read(code & 63))
            assert len(out) <= limit
            continue
        elif code == 0xfe:
            count = int.from_bytes(read(2), 'little')
            out.extend(read(1) * count)
            assert len(out) <= limit
            continue
        else:
            count = int.from_bytes(read(2), 'little') if code == 0xff else (code & 63) + 3
            offset = int.from_bytes(read(2), 'little')
        assert len(out) + count <= limit
        for i in range(count):
            assert 0 <= offset + i < len(out)
            out.append(out[offset+i])


def delta(src, size, previous=None):
    out = bytearray(size) if previous is None else bytearray(previous)
    assert len(out) == size
    sp = dp = 0
    def read(n):
        nonlocal sp
        assert sp+n <= len(src)
        result = src[sp:sp+n]
        sp += n
        return result
    while True:
        code = read(1)[0]
        fill = False
        skip = False
        if code == 0:
            count = read(1)[0]
            fill = True
        elif code < 0x80:
            count = code
        elif code > 0x80:
            count = code & 127
            skip = True
        else:
            word = int.from_bytes(read(2), 'little')
            if word == 0:
                assert sp == len(src) and dp <= size
                return bytes(out)
            skip = not (word & 0x8000)
            fill = bool(word & 0x4000) and not skip
            count = word & (0x3fff if fill else 0x7fff)
        assert dp + count <= size
        if not skip:
            data = read(1) * count if fill else read(count)
            for i, value in enumerate(data):
                out[dp+i] ^= value
        dp += count



def shape(shp, i):
    offset = struct.unpack_from('<I', shp, 2+4*i)[0]+2
    flags,h,w,h2,size,unc = struct.unpack_from('<HBHBHH', shp, offset)
    assert flags in (0,2) and h == h2 and offset+size <= len(shp)
    raw = shp[offset+10:offset+size]
    raw = raw if flags & 2 else lcw(raw, unc)
    assert len(raw) == unc
    pixels = bytearray()
    pos = 0
    while pos < len(raw):
        value = raw[pos]
        pos += 1
        if value:
            pixels.append(value)
        else:
            assert pos < len(raw)
            pixels.extend(bytes(raw[pos]))
            pos += 1
    assert len(pixels) == w*h
    return w, h, bytes(pixels)

ROOT = Path(__file__).resolve().parents[1]
LEGACY_GAME = Path('~/lol2_out/museum_capture_20260913/game')
STAGED = ('portrait.png', 'blink_1.png', 'blink_2.png', 'blink_3.png', 'portrait_frame.png', 'cursor.png')

def main(argv=None):
    parser = argparse.ArgumentParser(description='Stage the original neutral portrait, HUD frame and cursor.')
    parser.add_argument('--game', type=Path, default=LEGACY_GAME, help='directory containing GLOBAL.MIX and LOCAL.MIX')
    parser.add_argument('--output-root', type=Path, default=ROOT, help='root that receives assets/lol2/generated/museum_interface')
    args = parser.parse_args(argv)
    import lol2_source_format as helper_mod
    print(f'helper_module {Path(helper_mod.__file__).resolve()}', file=sys.stderr)
    game = args.game
    sources = {}
    def asset(archive, key, name):
        path = game / archive
        if not path.is_file():
            raise SystemExit(f'missing original archive {path}')
        data = path.read_bytes()
        try:
            entries = parse_mix(data)
        except ValueError as error:
            raise SystemExit(f'{path} is not a readable MIX: {error}')
        entry = next((item for item in entries if item['key'] == key), None)
        if entry is None:
            raise SystemExit(f'{path} has no MIX key {key}')
        blob = data[entry['offset']:entry['offset']+entry['size']]
        sources[name] = dict(archive=archive, **entry, sha256=hashlib.sha256(blob).hexdigest())
        return blob
    pal = asset('LOCAL.MIX', 1915865337, 'basepal.pal')
    assert len(pal) == 768 and max(pal) <= 63
    palette = bytes(round(v*255/63) for v in pal)
    pending = []
    def stage(name, w, h, pixels):
        pending.append((name, w, h, pixels))
        return dict(width=w, height=h, indices_sha256=hashlib.sha256(pixels).hexdigest())
    wsa = asset('LOCAL.MIX', 990864663, 'P_LUTHER.WSA')
    n,x,y,w,h,limit,flags = struct.unpack_from('<7H', wsa)
    assert (n,x,y,w,h,flags) == (65,0,0,38,52,0)
    offsets = struct.unpack_from('<67I', wsa, 14)
    assert offsets[0] == 282 and offsets[-1] == len(wsa)
    assert all(a < b for a,b in zip(offsets, offsets[1:]))
    pixels = delta(lcw(wsa[offsets[0]:offsets[1]], limit), w*h)
    portrait = stage('portrait.png', w,h,pixels)
    previous = pixels
    portrait_hashes = [hashlib.sha256(pixels).hexdigest()]
    for i in range(1,n+1):
        previous = delta(lcw(wsa[offsets[i]:offsets[i+1]],limit), w*h, previous)
        if i < n: portrait_hashes.append(hashlib.sha256(previous).hexdigest())
    assert previous == pixels
    eyes = asset('LOCAL.MIX', 2515623178, 'EYENORM.WSA')
    en,ex,ey,ew,eh,elimit,eflags = struct.unpack_from('<7H',eyes)
    assert (en,ex,ey,ew,eh,eflags) == (10,0,0,29,15,0)
    eo = struct.unpack_from('<12I',eyes,14)
    assert eo[0] == 62 and eo[-1] == len(eyes)
    assert all(a < b for a,b in zip(eo,eo[1:]))
    previous = None
    eye_hashes = []
    first = None
    for i in range(en+1):
        previous = delta(lcw(eyes[eo[i]:eo[i+1]],elimit),ew*eh,previous)
        if first is None: first = previous
        if i < en: eye_hashes.append(hashlib.sha256(previous).hexdigest())
        if i in (1,2,3): stage(f'blink_{i}.png',ew,eh,previous)
    assert previous == first

    shp = asset('GLOBAL.MIX', 606080735, 'intrface.shp')
    assert struct.unpack_from('<H', shp)[0] == 144
    frames = []
    for i in range(144):
        w, h, pixels = shape(shp, i)
        frames.append(dict(index=i,width=w,height=h,indices_sha256=hashlib.sha256(pixels).hexdigest()))
        if i == 2:
            stage('portrait_frame.png', w,h,bytes(pixels))
    mouse = asset('LOCAL.MIX', 4088536583, 'mouseh.shp')
    assert struct.unpack_from('<H', mouse)[0] == 19
    for i in range(19):
        w, h, pixels = shape(mouse, i)
        if i == 1:
            assert (w,h) == (9,14)
            cursor = stage('cursor.png', w,h,pixels)
    manifest = dict(sources=sources, portrait=portrait, portrait_frame_hashes=portrait_hashes, eye_frame_hashes=eye_hashes, loop_closure_verified=True, blink_frames=[1,2,3], blink_offset=[5,13], cursor=cursor, verified_cursor_shapes=19, verified_shapes=frames,
        scope='Original neutral portrait frame 0, HUD shape 2 and mouseh shape 1, basepal palette. Strict bounded LCW, delta and shape RLE with exact consumption and PNG index roundtrip. Blink timing/patch placement is authored; native animation scheduling, health/mana behavior and complete HUD not restored.')
    text = json.dumps(manifest, indent=2) + '\n'
    assert tuple(name for name, _, _, _ in pending) == STAGED, [name for name, _, _, _ in pending]
    # Decoder checks and the PNG index roundtrip finish before the output directory is created.
    encoded = []
    with tempfile.TemporaryDirectory(prefix='museum_interface_') as tmp:
        folder = Path(tmp)
        for name, w, h, pixels in pending:
            image = Image.frombytes('P', (w, h), pixels)
            image.putpalette(palette)
            image.save(folder / name, transparency=0)
            assert Image.open(folder / name).tobytes() == pixels
            encoded.append((name, (folder / name).read_bytes()))
    out = args.output_root / 'assets/lol2/generated/museum_interface'
    out.mkdir(parents=True, exist_ok=True)
    for name, raw in encoded:
        (out / name).write_bytes(raw)
    (out / 'provenance.json').write_text(text)
    print('Verified 144 interface shapes and portrait frame 0; 19 mouse shapes; staged original portrait, frame and arrow.')

if __name__ == '__main__':
    main()
