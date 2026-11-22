#!/usr/bin/env python3
"""Export actual recorded physics poses to Opus's walked-ground replay format.
No interpolated or planned poses. Host changes, map changes and discontinuities
split the output so loading/travel never invents a walked segment.
"""
import argparse
import hashlib
import json
from pathlib import Path


def split_poses(rows, area):
    groups=[];current=[];host=None
    for row in rows:
        if row.get('area')!=area:
            if current:groups.append(current)
            current=[];host=None
            continue
        if row.get('discontinuity') or row.get('host')!=host:
            if current:groups.append(current)
            current=[]
        host=row.get('host')
        point=row['position']
        current.append({'x':point[0],'h':point[1],'z':point[2],
                        'area':area,'t':row['msec']/1000,'body':row.get('body',{}),
                        'on_floor':row.get('on_floor'),'resets':row.get('resets'),
                        'source_sample':row['sample']})
    if current:groups.append(current)
    return [group for group in groups if len(group)>=2]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--area',required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    raw=args.input.read_bytes();lines=raw.decode().splitlines()
    header=json.loads(lines[0])
    if header.get('format')!='lol2-walked-ground-v1':parser.error('not an actual walked-ground recorder file')
    rows=[json.loads(line) for line in lines[1:] if line.strip()]
    groups=split_poses(rows,args.area)
    if not groups:parser.error('no actual continuous walked series for this area')
    args.out.mkdir(parents=True,exist_ok=True)
    sets=[]
    for index,poses in enumerate(groups):
        path=args.out/f'{args.area}_{index:04d}.json'
        path.write_text(json.dumps({'scope':'actual recorded physics poses; no planned/interpolated points','poses':poses},separators=(',',':'))+'\n')
        sets.append({'path':str(path.resolve()),'poses':len(poses),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest={'scope':'Actual pose export, not a walking PASS or full-chain acceptance','source':str(args.input.resolve()),
              'source_sha256':hashlib.sha256(raw).hexdigest(),'header':header,'area':args.area,'sets':sets}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'sets':len(sets),'poses':sum(s['poses'] for s in sets)}))


if __name__=='__main__':main()
