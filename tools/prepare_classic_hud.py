#!/usr/bin/env python3
"""Stage the original bottom-right HUD cluster pieces from intrface.shp (docs/classic-hud.md).

Layout reference: manual.pdf (sha256 3c3cac3f…, lead evidence classic_review_20261007/lead/manual_hud_review),
printed pages 7/10/39:
- the cluster (shape 2) sits bottom-right; its upper ring is the Attack Button, its lower ring the Magic Button;
- the Blue Button slides out the Spell Bar to the left.
Geometry is measured here from the decoded art itself (enclosed index-0 holes and bar slots), never from manual crops.
The hole sizes match the staged pieces exactly:
- portrait 38x52;
- ring icons 21x21; shape 1 = the 349-pixel ring disc;
- bar slots 25x4 (shape 59 blue) and 39x4 (shape 57 red);
- Spell Bar (shape 62) six 21x21 holes.
Writes assets/lol2/generated/classic_hud/shape_NNN.png (local, never published) and scripts/lol2/classic_hud_source.json.
"""
import hashlib, json, sys
from pathlib import Path
from PIL import Image
from prepare_museum_interface import shape
sys.path.insert(0, '/home/bob/lol2_re_publish_20260911/tools/draracle')
from lol2_extract_draracle_geometry import parse_mix

ROOT = Path(__file__).resolve().parents[1]
GAME = Path('/home/bob/lol2_out/museum_capture_20260913/game')
SHP_SHA = '1c03f2a0f739368c66078103d43131ea0fde26bfffdd34186b21611dde3fd50e'
PAL_SHA = '520c6fe31ccb9d5e1044b958e082df7919d63b46008dee9965d1b1e956a17729'
MANUAL_SHA = '3c3cac3f02fb22771948c7cd9c997f2a2c2588d5535adaa0a4f8e0dfd5eb8f52'
# Roles: the cluster/bar/disc are structural; icons and bars are size+manual visual matches (adapters, see docs).
ROLES = {2: 'cluster', 1: 'ring_disc', 62: 'spell_bar', 6: 'attack_unarmed_hand', 57: 'health_fill', 59: 'mana_fill',
         25: 'blue_button', 26: 'blue_button_open', 63: 'spell_heal', 65: 'spell_spark'}


def blob(archive, key):
    data = (GAME / archive).read_bytes(); e = next(e for e in parse_mix(data) if e['key'] == key)
    return data[e['offset']:e['offset'] + e['size']]


def holes(w, h, p, minimum=20):
    grid = [[p[y * w + x] for x in range(w)] for y in range(h)]; seen = set(); out = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] or (x, y) in seen: continue
            stack = [(x, y)]; seen.add((x, y)); pts = []; border = False
            while stack:
                a, b = stack.pop(); pts.append((a, b))
                if a in (0, w - 1) or b in (0, h - 1): border = True
                for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= c < w and 0 <= d < h and not grid[d][c] and (c, d) not in seen: seen.add((c, d)); stack.append((c, d))
            if not border and len(pts) >= minimum:
                xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
                out.append(dict(x=min(xs), y=min(ys), width=max(xs) - min(xs) + 1, height=max(ys) - min(ys) + 1, pixels=len(pts)))
    return sorted(out, key=lambda r: (r['y'], r['x']))


def main():
    shp = blob('GLOBAL.MIX', 606080735); assert hashlib.sha256(shp).hexdigest() == SHP_SHA
    pal = blob('LOCAL.MIX', 1915865337); assert hashlib.sha256(pal).hexdigest() == PAL_SHA
    palette = bytes(round(v * 255 / 63) for v in pal)
    out = ROOT / 'assets/lol2/generated/classic_hud'; out.mkdir(parents=True, exist_ok=True)
    shapes = {}
    for index, role in ROLES.items():
        w, h, pixels = shape(shp, index)
        image = Image.frombytes('P', (w, h), pixels); image.putpalette(palette)
        name = f'shape_{index:03d}.png'; image.save(out / name, transparency=0)
        shapes[str(index)] = dict(role=role, file=name, width=w, height=h, opaque=sum(1 for v in pixels if v), indices_sha256=hashlib.sha256(pixels).hexdigest())
    w, h, p = shape(shp, 2); cluster = holes(w, h, p, 60)
    assert [(r['x'], r['y'], r['width'], r['height']) for r in cluster] == [(41, 7, 38, 52), (7, 9, 21, 21), (7, 42, 21, 21), (5, 66, 25, 4), (41, 66, 39, 4)], cluster
    w, h, p = shape(shp, 62); bar = holes(w, h, p)
    assert [(r['x'], r['y'], r['width'], r['height']) for r in bar] == [(15 + 24 * k, 5, 21, 21) for k in range(6)], bar
    assert shapes['1']['opaque'] == cluster[1]['pixels'] == 349
    assert (shapes['57']['width'], shapes['57']['height']) == (39, 4) and (shapes['59']['width'], shapes['59']['height']) == (25, 4)
    source = dict(version=1, scale=2, source=dict(archive='GLOBAL.MIX', key=606080735, sha256=SHP_SHA, palette_sha256=PAL_SHA),
                  manual=dict(sha256=MANUAL_SHA, printed_pages=[7, 10, 39], evidence='classic_review_20261007/lead/manual_hud_review/evidence.json'),
                  anchor='bottom_right', shapes=shapes,
                  cluster=dict(portrait=cluster[0], attack_ring=cluster[1], magic_ring=cluster[2], mana_slot=cluster[3], health_slot=cluster[4]),
                  spell_bar=dict(rings=bar, attach='left_of_cluster_bottom_aligned'),
                  adapters=['ring icon / bar fill / blue button roles: size match to the art plus manual look, not byte-proven',
                            'Spell Bar attachment and Blue Button position: placed beside the cluster, offsets not taken from manual crops',
                            'equipped weapon icon: the existing item icon fitted into the Attack ring'])
    (ROOT / 'scripts/lol2/classic_hud_source.json').write_text(json.dumps(source, indent=1) + '\n')
    print('PASS classic HUD: %d shapes staged; cluster holes portrait 38x52 + 2 rings 21x21 + bar slots 25x4/39x4; spell bar 6 rings' % len(shapes))


if __name__ == '__main__':
    main()
