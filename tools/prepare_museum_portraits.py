#!/usr/bin/env python3
"""Rebuild the six original Museum gallery portraits (static assemblies159–164)."""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys, tempfile
ROOT = Path(__file__).resolve().parents[1]
FACE_SHA = "7c1d94f229f03ba8ee33d7be390e06c48d5e27022510966203bfb339028e1a38"
IMAGE_SHA = {'material_0419/mip_0_palette.png': '76b448e08f6bb34998106244c49c9e9f558fec62d018edc75bbd91fe460a729f', 'material_0413/mip_0_palette.png': 'd2642fff0995019c999c09a91cf38e0070f040b86ce69cf878d42c3593850663', 'material_0420/mip_0_palette.png': '3abc7677a3e60c3357d21479c82bd635648e5f6db7e9faed84c8573c5defd893', 'material_0423/mip_0_palette.png': 'a0f4c1d17b4a9b7b38989789504edae23f8bfc74d0d865bd663f586f9dd05604', 'material_0422/mip_0_palette.png': 'beb7d5e6b037dd96345d9447f46805d3c6f85910d01a8f89cc2b70a0552b086f', 'material_0417/mip_0_palette.png': 'ce332b116e29805a6a40827792a4c92e1b474a7d7766ce6026fef9cab4b4c474', 'material_0418/mip_0_palette.png': 'a4cb17dc1525a31d30a5a3e78847c00c09b825562ec072a29fff4070d863f846'}
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
 with tempfile.TemporaryDirectory(prefix='museum-portraits-') as temp:
  report=Path(temp)/'assemblies'
  subprocess.run([sys.executable,str(ROOT/'tools/export_map_movables.py'),'--game-root',str(a.game),'--material-root',str(a.materials),'--re-root',str(a.re_root),'--tools-root',str(ROOT/'tools'),'--area','L3_DH','--placement-kind','static_assembly','--out',str(report)],check=True,stdout=subprocess.DEVNULL)
  data=json.loads((report/'movables.json').read_text())
  faces=[f for f in data['faces'] if f['source_index'] in range(159,165)]
  if sha(json.dumps(faces,sort_keys=True,separators=(',',':')).encode())!=FACE_SHA:raise ValueError('Portrait source geometry changed')
  material_root=Path(data['materials_root'])
  images={name:(material_root/name).read_bytes() for name in IMAGE_SHA}
  for name,content in images.items():
   if sha(content)!=IMAGE_SHA[name]:raise ValueError('Portrait material changed: '+name)
  out.mkdir(parents=True)
  materials={}
  for name,content in images.items():
   dest=name.split('/')[0]+'.png';(out/dest).write_bytes(content);materials[name]=dest
  result={'version':1,'source':data['source'],'placements':[x for x in data['placements'] if x['source_index'] in range(159,165)],'faces':faces,'materials':materials,'scope':'Six original static gallery portraits only. Movable painting54 and its lever retain their existing owner.'}
  (out/'portraits.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
