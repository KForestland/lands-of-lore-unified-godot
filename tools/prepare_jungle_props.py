#!/usr/bin/env python3
"""Stage the Huline Jungle's generic sprite props (L4_HJ: grass, ferns, palms, vines, rocks) for scripts/lol2/jungle_props.gd.

lol2.map_props.export_props decodes every placement (its own selector, region height formula, bounds, RGBA frames).
Props a script owns or moves are left to their feature hosts: any prop with an event record, or named by a command
whose target kind is 3 (prop), is excluded, so no host-drawn prop is drawn twice. The rest are grouped by material and
bounds for batched billboards. Native solidity and per-prop animation phase are not staged (docs/DEVIATIONS.md).
Output: PROJECT/assets/lol2/generated/jungle_props/{props.json, <material>_<frame>.png}.
Usage: prepare_jungle_props.py --game GAME [--project PROJECT]
"""
import argparse, hashlib, json, shutil, tempfile
from pathlib import Path
from verify_actor_item_grants import source_area

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    game = a.game.resolve()
    _, _, _, _, owners, streams = source_area('L4_HJ', game)
    scripted = {o['owner'] for o in owners if o['owner_kind'] == 'prop'}
    for stream in streams:
        for commands in stream.values():
            for c in commands:
                raw = bytes.fromhex(c['raw_hex'])
                if len(raw) >= 4 and raw[1] == 0x03: scripted.add(int.from_bytes(raw[2:4], 'little'))
    from lol2.map_props import export_props
    out = a.project / 'assets/lol2/generated/jungle_props'
    with tempfile.TemporaryDirectory(prefix='jungle-props-') as temp:
        t = Path(temp)
        report = export_props(game, 'L4_HJ', t / 'props', material_root=t / 'materials')
        if out.exists(): shutil.rmtree(out)
        out.mkdir(parents=True)
        materials, groups = {}, {}
        kept = [x for x in report['props'] if x['record'] not in scripted]
        for x in kept:
            key = x['material']
            if key not in materials:
                sources = report['animations'][key]['frames'] if key in report['animations'] else [report['materials'][key]]
                frames = []
                for i, f in enumerate(sources):
                    name = f'{key}_{i}.png'
                    shutil.copyfile(t / 'props' / f, out / name)
                    frames.append(name)
                materials[key] = dict(frames=frames, fps=report['animations'][key].get('fps', 10) if key in report['animations'] else 0)
            bounds = (x['left'], x['right'], x['bottom'], x['top'])
            groups.setdefault((key, bounds), []).append([x['position'][0], x['position'][1], x['position'][2], x['record']])
    rows = [dict(material=k, left=b[0], right=b[1], bottom=b[2], top=b[3], instances=v) for (k, b), v in sorted(groups.items())]
    result = dict(version=1, area='L4_HJ', source=report['source'], props=len(kept), excluded_scripted=len(report['props']) - len(kept),
                  materials=materials, groups=rows,
                  scope='Unscripted L4_HJ sprite props as billboards: original sprites, positions (native region height formula) '
                        'and bounds; frames at the exporter\'s provisional 10 fps in one shared phase per material; no collision.')
    (out / 'props.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')
    print(f'PASS jungle props: {len(kept)} props ({result["excluded_scripted"]} scripted left to hosts), {len(materials)} materials, '
          f'{len(rows)} groups, props.json sha256 {hashlib.sha256((out / "props.json").read_bytes()).hexdigest()[:16]}')


if __name__ == '__main__':
    main()
