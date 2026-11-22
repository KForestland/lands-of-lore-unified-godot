#!/usr/bin/env python3
"""Import the approved L10 pilot from Grok's census, pinning its native export."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def build(census):
    doc = json.loads(census.read_text())
    # The canonical census also grows scripted/static object classes. They do
    # not join the generic pilot just because a later research row exists.
    rows = [dict(row) for row in doc['rows'] if row['area'] == 'L10_DC'
            and (row.get('in_162', False) or row.get('in_57', False))]
    if not doc.get('complete') or len(rows) != 85 or sum(r['in_162'] for r in rows) != 56 or sum(r['in_57'] for r in rows) != 29:
        raise ValueError('Expected the reviewed pilot:56 movables and29 covers; no new classes enabled')
    native = ROOT / 'scripts/lol2/native_scripts/L10_DC.json'
    source = json.loads(native.read_text())
    placements = {r['ref']: r['placement_hex'] for r in source['objects'] if 'placement_hex' in r}
    for row in rows:
        if row['in_162'] or row['in_57']:
            row['placement_hex'] = placements[f"{row['native_class']}:{row['index']}"]
            if int.from_bytes(bytes.fromhex(row['placement_hex'])[8:10], 'little') & 0x1000:
                raise ValueError('Absent placement cannot join the pilot')
    return {'version': 1, 'scope': 'L10 Cemetery pilot; no absent/copy-block rows enabled',
            'census_sha256': hashlib.sha256(census.read_bytes()).hexdigest(),
            'native_sha256': hashlib.sha256(native.read_bytes()).hexdigest(), 'rows': rows}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('census', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = ROOT / 'scripts/lol2/generic_objects_l10.json'
    data = json.dumps(build(args.census), indent=2) + '\n'
    if args.check:
        if output.read_text() != data:
            parser.exit(1, 'Generic pilot census is stale\n')
        print('PASS exact L10 census/native output')
    else:
        output.write_text(data)

if __name__ == '__main__':
    main()
