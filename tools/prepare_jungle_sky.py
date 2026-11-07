#!/usr/bin/env python3
"""Stage an area's original sky panorama (the texture container's DEFAULT record) for jungle_review.gd and its hosts.

lol2.map_materials.export_materials decodes the area texture blob; lol2.map_environment.export_from_game recovers the
1280x300 indexed panorama and the native vertical origin (geometry environment +0x18). The same shader and camera
controller as the Cave sky (all_maps_sky.gdshader, map_sky_controller.gd) draw it; in the Jungle it shows through the
transparent edge walls (material 469) as in the original.
Areas: L4_HJ (jmountn2.pcx -> assets/lol2/generated/jungle_sky, the Huline Jungle, since 2026-10-22) and L8_SJ
(backgrnd.pcx -> assets/lol2/generated/darker_jungle_sky, the night jungle, 2026-10-30 Phase A). Pins are the panorama's
pixel sha256, size and vertical origin; a differing archive fails.
Output: PROJECT/assets/lol2/generated/<pack>/{panorama.png, panorama_indices.png, environment.json}.
Usage: prepare_jungle_sky.py --game GAME [--area L4_HJ|L8_SJ] [--project PROJECT]
"""
import argparse, json, shutil, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AREAS = {
    'L20_BB': dict(pack='map_sky/L20_BB', pixels_sha256='411754f3d14dbc5cc88059a15b12410cb233ddd5d30fd9405550a8533662c391', vertical_origin=-100, scope='Original archive DEFAULT panorama, shared sky projection adapter.'),
    'L14_HT': dict(pack='map_sky/L14_HT', pixels_sha256='b8c19103206d7b150254f6f4c03dbfc3a09f01061c2b91a3feaf13cb5bc62165', vertical_origin=60, scope='Original archive DEFAULT panorama, shared sky projection adapter.'),
    'L12_CM': dict(pack='map_sky/L12_CM', pixels_sha256='105af5eab7e0513a9fdba7e0ee4d688990ace7267a743e6665ae5aac16490c98', vertical_origin=50, scope='Original archive DEFAULT panorama, shared sky projection adapter.'),
    'L4_HJ': dict(pack='jungle_sky', pixels_sha256='11afec1fe5d8b7fde135bb579f5635d4d1ddc891f801dbb94d7935c8d9447f4d', vertical_origin=50,
                  scope='Original Jungle panorama in the Cave sky projection; pitch and below-image rows as the Cave sky.'),
    'L8_SJ': dict(pack='darker_jungle_sky', pixels_sha256='95c77132614990e44633cd6f10a433ef7eaf90db959fe987a1f2057ad77d6f94', vertical_origin=42,
                  scope='Original darker-jungle (night) panorama in the Cave sky projection; pitch and below-image rows as the Cave sky.'),
    'L10_DC': dict(pack='map_sky/L10_DC', pixels_sha256='4be1bd69bd7cb1b662e1a5700134b17634f548b7447b3c3780adb8d4299e3d20', vertical_origin=50,
                   scope='Original L10_DC panorama (texture container DEFAULT record, sky01.pcx 1280x300) in the Cave sky projection; pitch and below-image rows as the Cave sky.'),
    'L13_RC': dict(pack='map_sky/L13_RC', pixels_sha256='52bcb877e9781cea561306b592fefb3a1b1bbec39f7ee2eccdfcceabf38ea8c2', vertical_origin=0,
                   scope='Original L13_RC panorama (texture container DEFAULT record; the source path names SPHERE3/L16_CA/backgrnd.pcx, 1280x300) in the Cave sky projection; pitch and below-image rows as the Cave sky.'),
    'L16_CA': dict(pack='map_sky/L16_CA', pixels_sha256='a4205f489d68f2c0d40174ce342a167d82aa4856f5276c7b5007ee78ba35aaec', vertical_origin=100,
                   scope='Original L16_CA panorama (texture container DEFAULT record, backgrn1.pcx 1280x300) in the Cave sky projection; pitch and below-image rows as the Cave sky.'),
}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--area', choices=sorted(AREAS), default='L4_HJ')
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    from lol2.map_materials import export_materials
    from lol2.map_environment import export_from_game
    spec = AREAS[a.area]
    out = a.project / 'assets/lol2/generated' / spec['pack']
    with tempfile.TemporaryDirectory(prefix='jungle-sky-') as temp:
        t = Path(temp)
        export_materials(a.game.resolve(), a.area, t / 'materials')
        report = export_from_game(a.game.resolve(), a.area, t / 'materials', t / 'environment')
        panorama = report['panorama']
        assert panorama['pixels_sha256'] == spec['pixels_sha256'] and (panorama['width'], panorama['height']) == (1280, 300), panorama
        assert panorama['vertical_origin'] == spec['vertical_origin'], panorama
        if out.exists(): shutil.rmtree(out)
        out.mkdir(parents=True)
        for name in ('panorama.png', 'panorama_indices.png'): shutil.copyfile(t / 'environment' / name, out / name)
    meta = dict(panorama=dict(vertical_origin=spec['vertical_origin'], width=1280, height=300, pixels_sha256=spec['pixels_sha256'],
                              source_path=panorama['source_path']), area=a.area, scope=spec['scope'])
    (out / 'environment.json').write_text(json.dumps(meta, indent=2) + '\n')
    print(f'PASS {a.area} sky: {panorama["source_path"]} 1280x300, vertical origin {spec["vertical_origin"]} -> {out.relative_to(a.project)}')


if __name__ == '__main__':
    main()
