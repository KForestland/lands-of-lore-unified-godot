#!/usr/bin/env python3
"""Compose the approved L10 legacy + OF6 + 362 additions + two named owner-fall bands; no new census."""
import argparse
import hashlib
import json
from pathlib import Path
from prepare_boundary_collision import face_key

# Emperor tomb box tops (lead 2026-11-14, with the L10 EMP floor lowering, DEVIATIONS row): the three colour boxes stand
# 50 high on the -80 floor, their tops at -30 (regions 3839/3833/3826/3832, 3842/3843/3841/3844, 3840/3821/3830/3831).
# On a top the eye (feet + 56) stands 26 above the yard floor (0) that shares the plan, so the body is kept off them: a
# player-only fence on each top's outline from -30 to 10. Boxes are still used from the floor (aims at -37.5 on their fronts).
BOX_TOPS={'127':(2993,3042,-1576,-1545),'126':(3182,3232,-1575,-1544),'125':(3353,3403,-1574,-1543)}
BOX_FENCE=(-30,10)
def box_fences():
    out=[]
    for box,(x0,x1,z0,z1) in sorted(BOX_TOPS.items()):
        lo,hi=BOX_FENCE
        for a,b in (((x0,z0),(x1,z0)),((x1,z0),(x1,z1)),((x1,z1),(x0,z1)),((x0,z1),(x0,z0))):
            out.append({'face':None,'region':None,'box':int(box),'points':[[a[0],lo,a[1]],[a[0],hi,a[1]],[b[0],hi,b[1]],[b[0],lo,b[1]]],
                        'note':'player-only fence on colour box %s top (-30): its eye would stand above the yard floor; the box is used from the floor'%box})
    return out

def compose(root):
    map_path=root/'assets/lol2/generated/maps/L10_DC/area.json'
    legacy_path=root/'scripts/lol2/l10_void_edges.json'
    extra_path=root/'tests/fixtures/l10_boundary_additions_362.json'
    named_path=root/'tests/fixtures/l10_owner_upper_bands_2.json'
    named=json.loads(named_path.read_text())
    if named['inputs']['map']['sha256']!=hashlib.sha256(map_path.read_bytes()).hexdigest():raise ValueError('named owner bands need their reviewed map')
    named_keys=set(named['block_face_keys']);named_matched=set()
    if named['source_face_indices']!=[9150,9179] or len(named_keys)!=2:raise ValueError('only the two owner-approved upper bands are admitted')
    data=json.loads(map_path.read_text());legacy=json.loads(legacy_path.read_text());extra=json.loads(extra_path.read_text())
    wanted={tuple(map(int,row))for row in legacy['edges']}
    wanted.update({(1444,0),(1447,0),(1452,0)})
    additions=set(extra['block_face_keys']);selected=[];legacy_count=0;matched=set()
    for face in data['faces']:
        if face.get('kind')!='source_wall':continue
        key=face_key(face)
        if key in additions:matched.add(key)
        if key in named_keys:named_matched.add(key)
        old=(face.get('region'),face.get('edge'))in wanted
        if old:legacy_count+=1
        if old or key in additions or key in named_keys:selected.append(key)
    if matched!=additions:raise ValueError('approved additional keys do not all match the map')
    if named_matched!=named_keys or named_keys & additions:raise ValueError('named owner keys must match exactly and remain distinct')
    for index,key in zip(named['source_face_indices'],named['block_face_keys']):
        if face_key(data['faces'][index])!=key:raise ValueError('named source face/key changed')
    pin=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    return {'version':1,'area':'L10_DC','rule':'Exact legacy + OF6 + approved362 additions + named owner-fall9150/9179, one shared body; no new geometry or census',
            'inputs':{'map':{'path':str(map_path.relative_to(root)),'sha256':pin(map_path)},'legacy':{'path':str(legacy_path.relative_to(root)),'sha256':pin(legacy_path)},'additional':{'path':str(extra_path.relative_to(root)),'sha256':pin(extra_path)},'owner_named':{'path':str(named_path.relative_to(root)),'sha256':pin(named_path)}},
            'block_face_keys':sorted(set(selected)),'collision_faces':box_fences(),
            'counts':{'selected_faces':len(selected),'selected_keys':len(set(selected)),'legacy_and_OF6_faces':legacy_count,'approved_additional_keys':len(additions),'owner_named_keys':len(named_keys),'box_top_fences':12}}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    path=args.root/'scripts/lol2/height_boundary/L10_DC.json';packet=compose(args.root)
    if args.check:
        if json.loads(path.read_text())!=packet:raise SystemExit('FAIL L10 boundary packet differs from approved inputs')
    else:path.write_text(json.dumps(packet,indent=2)+'\n')
    print('PASS L10 boundary packet',packet['counts'])
if __name__=='__main__':main()
