#!/usr/bin/env python3
"""Recheck the pinned original statue placement, path and fight groups."""
import json,struct,hashlib
from pathlib import Path
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];archive=(a.game/'DAT/L9_DR.MIX').read_bytes();assert hashlib.sha256(archive).hexdigest()=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7';raw=archive[22719810:22719810+823367]
u=lambda x:struct.unpack_from('<I',raw,x)[0]
first,count,flags=struct.unpack_from('<HBB',raw,u(0xdc));assert(first,count,flags)==(0,12,0)
pts=[]
for i in range(count):
 x,z,r,f=struct.unpack_from('<hhHH',raw,u(0xc8)+i*8);pts.append(dict(position=[x,-z],region=r,flags=f))
actor=json.loads((root/'scripts/lol2/act2_populations/L9_DR.json').read_text())['actors'];actor=next(a for a in actor if a['actor']==76);b=bytes.fromhex(actor['placement_hex']);assert b[37]==7 and b[41]==0
nav=json.loads((root/'assets/lol2/generated/creature_nav/L9_DR.json').read_text())['regions'];source=json.loads((root/'scripts/lol2/native_scripts/L9_DR.json').read_text())
regions=[dict(region=i,polygon=nav[i][0],floor=nav[i][1:3]) for i in [5940,5945,5946,5947]]
out=dict(version=1,source_sha256=hashlib.sha256(archive).hexdigest(),actor=actor,path=dict(index=0,first=first,count=count,flags=flags,points=pts),fight_regions=regions,groups=[g for g in source['groups'] if g['group'] in [5918,6054,6190,6326,12766]],movie=json.loads((root/'scripts/lol2/movie_table.json').read_text())['entries'][54],scope='Original actor76 placement behavior7/path0 and twelve source markers; source region predicates and movie54 retained. Modern physical steering/speed and Human encounter admission, not native callback replay.')
(root/'scripts/lol2/l9_statue_path_source.json').write_text(json.dumps(out,indent=1)+'\n')
print('PASS original actor76 path0 twelve markers, fight movie54')
