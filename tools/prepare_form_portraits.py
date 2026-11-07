#!/usr/bin/env python3
"""Stage the original Beast and Lizard HUD portraits (frame 0) beside the neutral Luther portrait.

LOCAL.MIX holds P_LUTHER.WSA (staged by prepare_museum_interface.py), P_BEAST.WSA and P_LIZARD.WSA; the keys are
the Westwood v1 name hashes. All three are 65-frame 38x52 WSAs with the same header, so they decode with the same
bounded LCW + delta reader and basepal.pal. Frame 0 is staged; the WSA loop must close back to frame 0. The original's
per-form animation scheduling is not restored (the HUD shows frame 0; the human blink overlay is human-only).
Usage: prepare_form_portraits.py [--game GAME] [--output-root ROOT]
"""
import argparse, hashlib, json, struct, tempfile
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1
from prepare_museum_interface import lcw, delta, LEGACY_GAME, ROOT

PORTRAITS = {'beast': 'P_BEAST.WSA', 'lizard': 'P_LIZARD.WSA'}
# Unnamed 22-frame 38x52 WSAs in LOCAL.MIX (MIX key only): the transformation morphs with the blue curse glow, as the
# longplay shows at 6:45-6:52. human->beast plays forward; lizard->human forward, so human->lizard plays it reversed.
MORPHS = {'human_beast': 1258370824, 'lizard_human': 1260992264}
PALETTE_KEY = 1915865337  # basepal.pal


def frames(wsa, count):
    n, x, y, w, h, limit, flags = struct.unpack_from('<7H', wsa)
    assert (n, x, y, w, h, flags) == (count, 0, 0, 38, 52, 0), (n, x, y, w, h, flags)
    offsets = struct.unpack_from('<%dI' % (n + 2), wsa, 14)
    assert all(a < b for a, b in zip(offsets, offsets[1:])) and offsets[-1] <= len(wsa)
    out, previous = [], None
    for i in range(n):
        previous = delta(lcw(wsa[offsets[i]:offsets[i + 1]], limit), w * h, previous)
        out.append(previous)
    return w, h, out


def decode(wsa):
    n, x, y, w, h, limit, flags = struct.unpack_from('<7H', wsa)
    assert (n, x, y, w, h, flags) == (65, 0, 0, 38, 52, 0), (n, x, y, w, h, flags)
    offsets = struct.unpack_from('<%dI' % (n + 2), wsa, 14)
    assert offsets[0] == 282 and offsets[-1] == len(wsa) and all(a < b for a, b in zip(offsets, offsets[1:]))
    first = previous = delta(lcw(wsa[offsets[0]:offsets[1]], limit), w * h)
    for i in range(1, n + 1):
        previous = delta(lcw(wsa[offsets[i]:offsets[i + 1]], limit), w * h, previous)
    assert previous == first, 'WSA loop does not close'
    return w, h, first


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, default=LEGACY_GAME)
    p.add_argument('--output-root', type=Path, default=ROOT)
    a = p.parse_args()
    data = (a.game / 'LOCAL.MIX').read_bytes()
    entries = {e['key']: e for e in parse_mix(data)}
    blob = lambda key: data[entries[key]['offset']:entries[key]['offset'] + entries[key]['size']]
    pal = blob(PALETTE_KEY)
    assert len(pal) == 768 and max(pal) <= 63
    palette = bytes(round(v * 255 / 63) for v in pal)
    assert ww_hash_v1('P_LUTHER.WSA') == 990864663  # same key the neutral portrait preparer pins
    staged, provenance = [], {}
    for form, name in PORTRAITS.items():
        key = ww_hash_v1(name)
        raw = blob(key)
        w, h, pixels = decode(raw)
        staged.append((form + '.png', w, h, pixels))
        provenance[form] = dict(file=name, key=key, archive='LOCAL.MIX', wsa_sha256=hashlib.sha256(raw).hexdigest(),
                                frame0_indices_sha256=hashlib.sha256(pixels).hexdigest(), width=w, height=h)
    for name, key in MORPHS.items():
        raw = blob(key)
        w, h, seq = frames(raw, 22)
        for i, pixels in enumerate(seq): staged.append(('%s_%02d.png' % (name, i), w, h, pixels))
        provenance[name] = dict(key=key, archive='LOCAL.MIX', wsa_sha256=hashlib.sha256(raw).hexdigest(), frames=len(seq),
                                frames_indices_sha256=[hashlib.sha256(p).hexdigest() for p in seq])
    encoded = []
    with tempfile.TemporaryDirectory(prefix='form_portraits_') as tmp:
        for name, w, h, pixels in staged:
            image = Image.frombytes('P', (w, h), pixels)
            image.putpalette(palette)
            image.save(Path(tmp) / name, transparency=0)
            assert Image.open(Path(tmp) / name).tobytes() == pixels
            encoded.append((name, (Path(tmp) / name).read_bytes()))
    out = a.output_root / 'assets/lol2/generated/form_portraits'
    out.mkdir(parents=True, exist_ok=True)
    for name, raw in encoded: (out / name).write_bytes(raw)
    (out / 'provenance.json').write_text(json.dumps(dict(portraits=provenance, palette='LOCAL.MIX basepal.pal',
        scope='Frame 0 of each form WSA and both 22-frame morphs; native portrait expression banks (65 frames) not restored.'), indent=1) + '\n')
    print('PASS form portraits: staged', ', '.join(provenance), '(%d files)' % len(encoded))


if __name__ == '__main__':
    main()
