#!/usr/bin/env python3
"""Build a museum geometry review; UVs and wall appearance remain provisional."""
import argparse,json,hashlib,shutil,struct,math
from export_museum_geometry import ARCHIVE_SHA
from pathlib import Path
from lol2.interior_spans import build


def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game-root',type=Path,required=True)
 p.add_argument('--geometry',type=Path,required=True);p.add_argument('--presets',type=Path,required=True)
 p.add_argument('--materials',type=Path,required=True);p.add_argument('--arrival',type=Path,required=True)
 p.add_argument('--surface-setup',type=Path,required=True);p.add_argument('--rotation-table',type=Path,required=True)
 p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 archive=(a.game_root/'DAT/L3_DH.MIX').read_bytes()
 if hashlib.sha256(archive).hexdigest()!=ARCHIVE_SHA:raise ValueError('Museum archive changed')
 g=json.loads(a.geometry.read_text());pres=json.loads(a.presets.read_text());arrival=json.loads(a.arrival.read_text())
 if hashlib.sha256(a.geometry.read_bytes()).hexdigest()!=arrival['geometry_sha256']:raise ValueError('Arrival geometry mismatch')
 mat=json.loads((a.materials/'materials.json').read_text());available={r['index']:r for r in mat['materials']}
 bindings={r['region']:r['resource_index'] for r in pres['regions']}
 floor_lookup={r['region']:r for r in pres['regions']}
 setup=json.loads(a.surface_setup.read_text())
 if setup['presets_sha256']!=hashlib.sha256(a.presets.read_bytes()).hexdigest():raise ValueError('Setup/preset witness mismatch')
 table_data=a.rotation_table.read_bytes()
 if hashlib.sha256(table_data).hexdigest()!='d7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53':raise ValueError('Rotation table changed')
 table=struct.unpack('<4096i',table_data);states={r['preset']:r for r in setup['results'] if r['initial_flags']==0}
 def trig(angle):
  angle&=65535;return table[(angle&32767)>>3]*(-1 if angle>=32768 else 1)
 def surface_uv(region,selection):
  st=states[selection['preset']];m=available[selection['resource_index']]
  aa,bb=trig(st['angle_word']),trig(st['angle_word']+16384);scale=[2.,1.,.5,.25][(st['flags']>>14)&3]
  uv=[]
  for v in region['vertex_indices']:
   x,y=g['vertices_fixed'][v];x-=st['offset_x_fixed'];y-=st['offset_y_fixed']
   u=(((y*bb)>>16)+((x*aa)>>16))*scale/65536+st['offset_bytes'][0]
   vv=(((x*bb)>>16)-((y*aa)>>16))*scale/65536+st['offset_bytes'][1]
   # A9 PNG rows were converted from source U*height+V storage.
   uv.append([u/m['width'],vv/m['height']])
  return uv
 ceiling_lookup={r['region']:r for r in pres['ceiling_regions']}
 ceiling_bindings=[]
 a.out.mkdir(parents=True,exist_ok=True);materials={};animations={}
 for k,m in available.items():
  name=f'material_{k}.png';shutil.copyfile(a.materials/f'material_{k:04d}/mip_0_palette.png',a.out/name)
  materials[str(k)]=name
  if m.get('animation_frames'):
   frames=[]
   for index,frame in enumerate(m['animation_frames']):
    filename=f'material_{k}_frame_{index}.png';shutil.copyfile(a.materials/f'material_{k:04d}'/frame,a.out/filename);frames.append(filename)
   animations[str(k)]=dict(frames=frames,fps=m['review_fps'],scope='Authored playback rate; source frame order.')
 def point(v,h):
  x,y=g['vertices_fixed'][v];return [x/65536,h,-y/65536]
 entry=g['source']['entry'];raw=archive[entry['offset']:entry['offset']+entry['size']]
 wall_start,wall_count=struct.unpack_from('<I',raw,8)[0],struct.unpack_from('<I',raw,0x54)[0]
 if wall_start+wall_count*8!=struct.unpack_from('<I',raw,12)[0]:raise ValueError('Wall table boundary mismatch')
 boundary_bindings=[]
 faces=[]
 for r in g['regions']:
  if not r['floor_subdivisions']:
   pts=[point(v,h) for v,h in zip(r['vertex_indices'],r['floor_corners'])];k=bindings.get(r['id'])
   faces.append(dict(region=r['id'],kind='floor',points=pts,material=str(k) if k in available else 'unresolved',uv=surface_uv(r,floor_lookup[r['id']]) if k in available else [[0,0]]*4))
  if r['standalone_ceiling']:
   pts=[point(v,h) for v,h in zip(r['vertex_indices'],r['ceiling_corners'])]
   selection=ceiling_lookup.get(r['id']);k=selection['resource_index'] if selection else None
   face=dict(region=r['id'],kind='ceiling',points=pts,material=str(k) if k in available else 'shell')
   if k in available:
    face['uv']=surface_uv(r,selection)
    ceiling_bindings.append(selection)
   faces.append(face)
  if r['standalone_walls']:
   for i,n in enumerate(r['neighbors']):
    if n is not None:continue
    j=(i+1)%4;v0,v1=r['vertex_indices'][i],r['vertex_indices'][j]
    words=struct.unpack('<22H',bytes.fromhex(r['raw_hex']));first,count=words[13],words[15]&255
    if count and first+count>wall_count:raise ValueError('Wall range out of bounds')
    candidates=[]
    for wi in range(first,first+count):
     d=raw[wall_start+wi*8:wall_start+(wi+1)*8]
     if (d[5]&31)==(i|4):candidates.append((wi,struct.unpack_from('<h',d)[0]))
    binding=candidates[0] if len(candidates)==1 and candidates[0][1] in available else None
    pts=[point(v0,r['floor_corners'][i]),point(v1,r['floor_corners'][j]),point(v1,r['ceiling_corners'][j]),point(v0,r['ceiling_corners'][i])]
    face=dict(region=r['id'],kind='boundary',material=str(binding[1]) if binding else 'shell',points=pts)
    if binding:
     # Reuse cave wall review addressing/orientation with original eight-byte record.
     d=raw[wall_start+binding[0]*8:wall_start+(binding[0]+1)*8]
     top=[pts[3],pts[2],pts[1],pts[0]];length=math.dist(top[0][::2],top[1][::2]);height=max(p[1] for p in top)-min(p[1] for p in top)
     mode=(d[6]>>5)&3;anchor,other=[(0,1),(1,0),(3,2),(2,3)][mode];origin=list(top[anchor]);end=top[other]
     origin[1]=max(p[1] for p in top) if mode<2 else min(p[1] for p in top)
     scale=[2.,1.,.5,.25][d[7]&3];addressing=8 if d[6]&16 else (16 if d[6]&8 else 0)
     m=available[binding[1]];w,h=m['width'],m['height']
     if length>0 and height>0:
      dx,dz=(end[0]-origin[0])/length,(end[2]-origin[2])/length
      uscale=scale if addressing else w/length;vscale=scale if addressing==8 else h/height
      face['uv']=[[(((p[0]-origin[0])*dx+(p[2]-origin[2])*dz)*uscale+(d[2] if addressing else 0))/w,((p[1]-origin[1])*(-1 if mode<2 else 1)*vscale+(d[3] if addressing==8 else 0))/h] for p in pts]
     boundary_bindings.append(dict(region=r['id'],edge=i,wall_record=binding[0],descriptor=binding[1]))
    faces.append(face)
 interior,audit=build(g)
 interior_bindings=[]
 for f in interior:
  pts=[[v*64 for v in p] for p in f['points']]
  r=g['regions'][f['region']];words=struct.unpack('<22H',bytes.fromhex(r['raw_hex']));first,count=words[13],words[15]&255
  if count and first+count>wall_count:raise ValueError('Interior wall range out of bounds')
  code=f['edge']|(8 if f['exposure']['kind']=='step' else 0)
  candidates=[]
  for wi in range(first,first+count):
   d=raw[wall_start+wi*8:wall_start+(wi+1)*8]
   if (d[5]&31)==code:candidates.append((wi,struct.unpack_from('<h',d)[0]))
  binding=candidates[0] if len(candidates)==1 and candidates[0][1] in available else None
  face=dict(region=r['id'],kind='interior',material=str(binding[1]) if binding else 'shell',points=pts)
  if binding:
   length=math.dist(pts[0][::2],pts[1][::2])
   face['uv']=[[0,-pts[0][1]/128],[length/128,-pts[1][1]/128],[length/128,-pts[2][1]/128],[0,-pts[3][1]/128]]
   if r['id']==1215 and binding[1]==278:
    # Modern reconstruction: show the complete ornament instead of a tiled fragment.
    face['uv']=[[0,1],[1,1],[1,0],[0,0]]
    face['uv_scope']='Authored full-panel ornament fit; native UV mapping unverified.'
   interior_bindings.append(dict(region=r['id'],edge=f['edge'],kind=f['exposure']['kind'],wall_record=binding[0],descriptor=binding[1]))
  faces.append(face)
 s=arrival['saves'][0];result=dict(animations=animations,interior_bindings=interior_bindings,ceiling_bindings=ceiling_bindings,boundary_bindings=boundary_bindings,faces=faces,materials=materials,start=[s['native_xy'][0],s['floor_height']+34,-s['native_xy'][1]],arrival_region=s['region'],scope='Original geometry and floor texture identities. Source preset surface UVs with provisional final axis interpretation; neutral unresolved walls/ceilings; provisional interior spans. No dynamic objects or native heading/camera proof.',sources={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [a.geometry,a.presets,a.arrival,a.materials/'materials.json',a.surface_setup,a.rotation_table]})
 (a.out/'museum.json').write_text(json.dumps(result,separators=(',',':'))+'\n');(a.out/'interior_audit.json').write_text(json.dumps(audit,indent=2)+'\n');print('textured interior spans',len(interior_bindings),'textured ceilings',len(ceiling_bindings),'textured boundaries',len(boundary_bindings),'faces',len(faces),'materials',len(materials),'start',result['start'])
if __name__=='__main__':main()
