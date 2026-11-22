#!/usr/bin/env python3
"""Pin one G03 level's published census and native placements, excluding absent rows."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
AREAS = {'L9_DR':'l9','L8_SJ':'l8','L12_CM':'l12','L13_RC':'l13',
         'L14_HT':'l14','L16_CA':'l16','L17_HC':'l17','L19_BC':'l19','L20_BB':'l20'}
# These existing puzzle owners decide admission and pose their own geometry.
# A click bit does not authorize bypassing their earned keys/plates/trials.
DELEGATED = {'L19_BC': {74,75,76}, 'L16_CA': {103}, 'L14_HT': {0,1,55,76,80,81,88,89,90,92,93}}

def build(area, census):
    doc = json.loads(census.read_text())
    if not doc.get('complete'):
        raise ValueError('Published complete census required')
    native = ROOT / f'scripts/lol2/native_scripts/{area}.json'
    source = json.loads(native.read_text())
    placements = {r['ref']:r['placement_hex'] for r in source['objects'] if 'placement_hex' in r}
    rows = []
    for original in doc['rows']:
        if original['area'] != area:
            continue
        row = dict(original)
        if row.get('in_162') or row.get('in_57') or row['native_class']=='movable':
            ref = f"{row['native_class']}:{row['index']}"
            row['placement_hex'] = placements[ref]
            raw = bytes.fromhex(row['placement_hex'])
            if int.from_bytes(raw[8:10], 'little') & 0x1000:
                if row.get('in_162') or row.get('in_57'):
                    raise ValueError(f'Absent placement in the published live set: {ref}')
                row['absent'] = True
                rows.append(row)
                continue
            if row.get('in_162') and (raw[0x22] != row['mode'] or raw[0x24] != row['span'] or not raw[0x23] & 2):
                raise ValueError(f'Published motion differs from placement: {ref}')
            if row['native_class']=='movable' and raw[0x23]&2 and raw[0x22] in range(7):
                row['generic_motion']=True
                if area=='L17_HC' and row['index']==50:
                    row['use_event']={'kind':6,'input':{'caller_byte':20,'context':ref}}
            if row['native_class']=='movable' and row['index'] in DELEGATED.get(area,set()):
                row['dedicated_owner'] = True
        if area=='L20_BB' and row.get('in_57') and row['native_class']=='prop' and row['template']==12:
            row['selector_limit']=1  # Existing map_props producer resolves original selectors0/1.
        rows.append(row)
    if not rows:
        raise ValueError('No published rows for requested level')
    return {'version':1,'scope':area+' published census; absent/copy-block rows excluded',
            'census_sha256':hashlib.sha256(census.read_bytes()).hexdigest(),
            'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'rows':rows}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('area', choices=AREAS)
    p.add_argument('census',type=Path)
    p.add_argument('--check',action='store_true')
    a = p.parse_args()
    data = json.dumps(build(a.area,a.census),indent=2)+'\n'
    output = ROOT / f'scripts/lol2/generic_objects_{AREAS[a.area]}.json'
    if a.check:
        if output.read_text() != data:
            p.exit(1,'Generic level census is stale\n')
        print('PASS exact census/native placements:',a.area)
    else:
        output.write_text(data)
if __name__ == '__main__':
    main()
