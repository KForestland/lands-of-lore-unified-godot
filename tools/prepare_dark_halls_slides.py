#!/usr/bin/env python3
"""Pin six Spy Slider controls to staged native records and geometry (no original media embedded)."""
import argparse, hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
IDS = (236, 890, 891, 1013, 1015, 1041)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    args=parser.parse_args()
    from lol2 import map_materials as mm
    import export_map_movables as exporter
    raw=(args.game/'DAT/L7_DH.MIX').read_bytes()
    assert hashlib.sha256(raw).hexdigest()=='40b394ebb3cfcfd9f332c4707f2f9e9e7de76d89b82836cec211772ca456b8e7'
    identities=mm.identify_entries(raw,mm.parse_mix(raw),3374994708)
    entry=identities['metadata_entry']
    exporter.require=mm.require
    template=exporter.load_movable_templates(raw[entry['offset']:entry['offset']+entry['size']])['templates'][22]
    closed=next(c for c in template['children'] if c['mask']==1)
    opened=next(c for c in template['children'] if c['mask']==2)
    assert closed['bounds']==opened['bounds']
    assert [x['resource_id'] for x in closed['surfaces']]==[259,259,367,367,367,367]
    assert [x['resource_id'] for x in opened['surfaces']]==[259,259,368,368,367,367]
    assert all(c['mask'] in [0,1,2] for c in template['children'])
    native = json.loads((ROOT/'scripts/lol2/native_scripts/L7_DH.json').read_text())
    area = json.loads((ROOT/'assets/lol2/generated/dark_halls/area.json').read_text())
    rows = []
    for index in IDS:
        obj = next(o for o in native['objects'] if o['ref'] == f'control:{index}')
        events = [e for e in obj['events'] if e['kind'] == 4]
        assert len(events) == 2
        assert {e['predicate']['index'] for e in events} == {206,207}
        groups = [next(g for g in native['groups'] if g['group']==e['group'] and g['stream']==e['stream']) for e in events]
        for state, group in enumerate(groups):
            assert group['commands'][-1]['raw_hex'] == f'1010{index.to_bytes(2,"little").hex()}{1-state:02x}00'
        faces = [f for f in area['faces'] if f.get('placement')==f'static_{index}']
        assert faces and all(f['template']==22 for f in faces)
        lo = [min(p[i] for f in faces for p in f['points']) for i in range(3)]
        hi = [max(p[i] for f in faces for p in f['points']) for i in range(3)]
        rows.append(dict(control=index, center=[(a+b)/2 for a,b in zip(lo,hi)], height=hi[1]-lo[1], groups=[g['group'] for g in groups]))
    (ROOT/'scripts/lol2/dark_halls_slides_source.json').write_text(json.dumps(dict(controls=rows,closed_material="367",open_material="368",variant_faces=[2,3],source_template=22),indent=1)+'\n')
    print('PASS Dark Halls slide source: six native toggle pairs, template 22 geometry')
if __name__=='__main__':main()
