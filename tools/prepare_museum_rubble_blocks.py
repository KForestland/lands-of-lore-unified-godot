#!/usr/bin/env python3
"""Rebuild the original Museum rubble-room blocks (static assemblies 64-76 and 95)."""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, tempfile
ROOT = Path(__file__).resolve().parents[1]
PLACEMENTS = (64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 95)
FACE_SHA = "498ad77b821fd850f527bc7df653738ab5899b91e2f05bfd0abf3f6f8abb8655"
IMAGE_SHA = {'material_0227/mip_0_palette.png': 'fe4b4a88a580b69094e25d43ca01c0615541e727539d5b63938d48179cf5c764', 'material_0236/mip_0_palette.png': '8c1ad08e67dfd2953b0c645482309f5a26f534916356932aeb1634bcca6a5186', 'material_0259/mip_0_palette.png': '3be13937e501455f2f061dadde75b80e3861ea45090fddc2aaaf114345c5246d', 'material_0319/mip_0_palette.png': 'e9aecce5ad1385b42ff92f1561d2a676a5ec3c6a78f4a5bee5e335f1bc903d30'}
def sha(data): return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game',required=True,type=Path)
 p.add_argument('--materials',required=True,type=Path)
 p.add_argument('--re-root',required=True,type=Path)
 p.add_argument('--out',required=True,type=Path)
 a=p.parse_args()
 out=a.out.resolve()
 for source in [a.game.resolve(),a.materials.resolve(),a.re_root.resolve()]:
  if out==source or out in source.parents or source in out.parents:p.error('Output overlaps an input')
 if out.exists():p.error('Output must be fresh')
 with tempfile.TemporaryDirectory(prefix='museum-rubble-blocks-') as temp:
  report=Path(temp)/'assemblies'
  subprocess.run([sys.executable,str(ROOT/'tools/export_map_movables.py'),'--game-root',str(a.game),'--material-root',str(a.materials),'--re-root',str(a.re_root),'--tools-root',str(ROOT/'tools'),'--area','L3_DH','--placement-kind','static_assembly','--out',str(report)],check=True,stdout=subprocess.DEVNULL)
  data=json.loads((report/'movables.json').read_text())
  faces=[f for f in data['faces'] if f['source_index'] in PLACEMENTS]
  if sha(json.dumps(faces,sort_keys=True,separators=(',',':')).encode())!=FACE_SHA:raise ValueError('Rubble block source geometry changed')
  if any(f.get('source_index') in PLACEMENTS for f in data['state_faces']+data['inactive_children']):raise ValueError('Rubble block has state-dependent children')
  material_root=Path(data['materials_root'])
  images={name:(material_root/name).read_bytes() for name in IMAGE_SHA}
  for name,content in images.items():
   if sha(content)!=IMAGE_SHA[name]:raise ValueError('Rubble block material changed: '+name)
  out.mkdir(parents=True)
  materials={}
  for name,content in images.items():
   dest=name.split('/')[0]+'.png';(out/dest).write_bytes(content);materials[name]=dest
  result={'version':1,'source':data['source'],'placements':[x for x in data['placements'] if x['source_index'] in PLACEMENTS],'faces':faces,'materials':materials,'scope':'Fourteen original static blocks in and beside the rubble room behind control96 (regions 329-335). Block179 retains its control96 owner. No source use record: no motion, pickup or interaction.'}
  (out/'blocks.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
