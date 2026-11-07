#!/usr/bin/env python3
"""Replace provisional Museum static wall spans using original native wall routines.

Preserves legacy face indices and the moving owners' regions. Requires the pinned
R19 baseline packs and original game; produces a fresh museum_review pack.
"""
import argparse,hashlib,json,shutil,sys,tempfile
from pathlib import Path
PINNED={
'museum_review/museum.json':'66016b861f5267f495bc649cde48f555800007ca5087dbeca8adab3e1615396c',
'museum_key_locks/passage78.json':'efd96d4e85b45822ed2ec7c666d2686ffc2003b662ca3a2e37e6424fe92e57c3',
'museum_long_arm/floors.json':'3cabe911afce9cd4fc37ea4f7d554f3960d0be7f0be6f109a1ae0c39f857efe9'}
def sha(data):return hashlib.sha256(data).hexdigest()
def require(ok,message):
 if not ok:raise ValueError(message)
def prepare(game,baseline,out):
 require(not out.exists(),'Output must be fresh')
 for source in (game,baseline):
  a,b=out.resolve(),source.resolve();require(a!=b and a not in b.parents and b not in a.parents,'Output overlaps input')
 for name,want in PINNED.items():require(sha((baseline/name).read_bytes())==want,'Baseline differs: '+name)
 data=json.loads((baseline/'museum_review/museum.json').read_text());dynamic=set()
 for name in ['museum_key_locks/passage78.json','museum_long_arm/floors.json']:
  owner=json.loads((baseline/name).read_text());dynamic.update(data['faces'][i]['region'] for i in owner['closed_face_indices'])
 tools=Path(__file__).resolve().parent;sys.path[:0]=[str(tools),str(tools/'lol2')]
 from lol2 import map_geometry,map_materials,map_source_walls,map_surfaces
 with tempfile.TemporaryDirectory(prefix='museum-source-walls-') as temp:
  temp=Path(temp)
  map_geometry.export_geometry(game,'L3_DH',temp/'geometry')
  native=map_source_walls.export_source_walls(game,'L3_DH',temp/'geometry',temp/'geometry')
  map_materials.export_materials(game,'L3_DH',temp/'materials')
  map_surfaces.bind_surfaces(game,'L3_DH',temp/'geometry',temp/'materials',temp)
  modern=json.loads((temp/'review.json').read_text())
  faces=[f for f in modern['faces'] if f['kind']=='source_wall' and f['region'] not in dynamic]
  require(len(native['faces'])==2832 and len(faces)==2793,'Native wall coverage differs')
  regions={f['region'] for f in faces}
  retired=[i for i,f in enumerate(data['faces']) if f['kind'] in ['boundary','interior'] and f['region'] in regions]
  require(len(retired)==2517,'Legacy replacement coverage differs')
  out.mkdir(parents=True)
  shutil.copytree(baseline/'museum_review',out/'museum_review')
  dest=out/'museum_review/source_walls';dest.mkdir()
  for f in faces:
   k=f['material'];name=k+'.png';source=temp/modern['materials'][k]
   shutil.copy2(source,dest/name)
   key='sourcewall_'+k+'__front';data['materials'][key]='source_walls/'+name
   data['faces'].append(dict(f,material=key))
  data['retired_static_wall_indices']=retired
  (out/'museum_review/museum.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
  (out/'preparation.json').write_text(json.dumps({'native_faces':len(native['faces']),'staged_faces':len(faces),'retired_faces':len(retired),'dynamic_regions':sorted(dynamic),'baseline':PINNED,'files':{str(f.relative_to(out)):sha(f.read_bytes()) for f in sorted((out/'museum_review').rglob('*')) if f.is_file()}},indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game',required=True,type=Path);p.add_argument('--baseline',required=True,type=Path);p.add_argument('--out',required=True,type=Path);a=p.parse_args();prepare(a.game,a.baseline,a.out)
