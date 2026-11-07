#!/usr/bin/env python3
"""Stage source jungle collision geometry; neutral review materials are authored.

  python3 tools/prepare_jungle_review.py --game-root GAME --geometry L4_HJ/geometry/geometry.json \
      --material-root JUNGLE_MATERIALS --output-root FRESH

Floor presets, their initial setup, the arrival and the rotation table are read from the original archives with the
published readers (lol2.map_surfaces.source_tables, build_game_atlas.commands, lol2_rotation_table); they reproduce
the former jungle_geometry_20260914 floor_presets/surface_setup/arrival JSON values exactly. The material root keeps the
legacy layout: materials.json (identity.blob_sha256 pinned below) and material_NNNN/mip_0_palette.png.
Required input paths, source bindings and selected material-file existence are checked
before creating --output-root, which must not exist. Image contents are not revalidated.
Use normal Python (not -O): some source checks are assertions. Output writes are sequential.
"""
import argparse,hashlib,json,struct,shutil,math,sys
from collections import Counter
from pathlib import Path
TOOLS=Path(__file__).resolve().parent
sys.path[:0]=[str(TOOLS),str(TOOLS/'lol2')]
from lol2_source_format import parse_mix,u32
from lol2.interior_spans import build
from map_surfaces import source_tables
from build_game_atlas import commands
from lol2_rotation_table import rotation_table
from verify_actor_item_grants import source_area
p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument('--game-root',type=Path,required=True)
p.add_argument('--geometry',type=Path,required=True,help='L4_HJ geometry.json (geometry exporter output)')
p.add_argument('--material-root',type=Path,required=True,help='legacy 92-folder jungle material root with materials.json')
p.add_argument('--output-root',type=Path,required=True)
args=p.parse_args()
if args.output_root.exists():p.error('Use a fresh --output-root')
for need in [args.geometry,args.material_root/'materials.json',args.game_root/'LOLG.DAT',args.game_root/'DAT/L4_HJ.MIX',args.game_root/'DAT/L3_DH.MIX']:
 if not need.is_file():p.error(f'missing input {need}')
out=args.output_root/'assets/lol2/generated/jungle_review'
g=json.loads(args.geometry.read_text())
# Preset table and initial setup: published source reader (former floor_presets.json/surface_setup.json values).
area,_,presets=source_tables(args.game_root,'L4_HJ')
assert g['source']['sha256']==area['source']['sha256'],'geometry belongs to a different archive'
# Arrival: the single Museum transition to level 4 names the entry; the L4_HJ arrival table record whose selector
# byte equals it (else record 0) is the native selection (former arrival.json, equal for all 256 entry ids).
_,_,museum_item,museum_raw,_,_=source_area('L3_DH',game=args.game_root)
to_jungle=[t for t in commands(museum_raw,museum_item)[1] if t['destination_level']==4]
assert len(to_jungle)==1,'expected one Museum transition to the jungle'
material_root=args.material_root
material_report=json.loads((material_root/'materials.json').read_text())
assert material_report['identity']['blob_sha256']=='98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'
available={m['index']:m for m in material_report['materials']}
table_bytes=rotation_table(args.game_root)
assert hashlib.sha256(table_bytes).hexdigest()=='d7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
table=struct.unpack('<4096i',table_bytes)
SCALE_FLAGS={2.:0,1.:1,.5:2,.25:3}
bindings={}
for r in g['regions']:
 selector=struct.unpack('<22H',bytes.fromhex(r['raw_hex']))[16]&255
 if selector!=255:bindings[r['id']]=dict(region=r['id'],preset=selector,resource_index=presets[selector]['resource'])
states={x['index']:dict(preset=x['index'],angle_word=x['angle'],flags=SCALE_FLAGS[x['scale']]<<14,offset_x_fixed=x['offset_x'],
 offset_y_fixed=x['offset_y'],offset_bytes=list(x['offsets'])) for x in presets}
def trig(angle):
 angle &= 65535
 return table[(angle&32767)>>3]*(-1 if angle>=32768 else 1)
def surface(r):
 binding=bindings.get(r['id'])
 if not binding or binding['resource_index'] not in available:return {}
 k=binding['resource_index'];st=states[binding['preset']];m=available[k]
 aa,bb=trig(st['angle_word']),trig(st['angle_word']+16384)
 scale=[2.,1.,.5,.25][(st['flags']>>14)&3];uv=[]
 for i in r['vertex_indices']:
  x,y=g['vertices_fixed'][i];x-=st['offset_x_fixed'];y-=st['offset_y_fixed']
  u=(((y*bb)>>16)+((x*aa)>>16))*scale/65536+st['offset_bytes'][0]
  vv=(((x*bb)>>16)-((y*aa)>>16))*scale/65536+st['offset_bytes'][1]
  uv.append([u/m['width'],vv/m['height']])
 return dict(material=str(k),uv=uv)
archive=(args.game_root/'DAT/L4_HJ.MIX').read_bytes()
assert hashlib.sha256(archive).hexdigest()==g['source']['sha256']
entry=next(e for e in parse_mix(archive) if e['key']==3710797084)
raw=archive[entry['offset']:entry['offset']+entry['size']]
arrival_start,arrival_count=u32(raw,0x48),u32(raw,0x90)
arrival_records=[struct.unpack_from('<hhHHBBH',raw,arrival_start+i*12) for i in range(arrival_count)]
entry_id=to_jungle[0]['destination_entry']
arrival_x,arrival_y,_,arrival_region,_,_,_=arrival_records[next((i for i,rec in enumerate(arrival_records) if rec[4]==entry_id),0)]
a=dict(archive_sha256=area['source']['sha256'],region=arrival_region,godot_xz=[arrival_x,-arrival_y])
wall_start,wall_count=u32(raw,8),u32(raw,0x54)
assert wall_start+wall_count*8==u32(raw,12)
wall_bindings=[]
wall_unresolved=[]
def wall_surface(r,edge,code,pts):
 words=struct.unpack('<22H',bytes.fromhex(r['raw_hex']))
 first,count=words[13],words[15]&255
 assert count==0 or first+count<=wall_count
 candidates=[]
 for i in range(first,first+count):
  d=raw[wall_start+i*8:wall_start+(i+1)*8]
  if d[5]&31==code:candidates.append((i,struct.unpack_from('<h',d)[0],d))
 reason = ('missing_record' if not candidates else 'ambiguous_records') if len(candidates)!=1 else ('negative_resource' if candidates[0][1]<0 else 'unsupported_resource')
 if len(candidates)!=1 or candidates[0][1] not in available:
  wall_unresolved.append(dict(region=r['id'],edge=edge,code=code,reason=reason,candidates=[dict(wall_record=i,resource=k,raw_hex=d.hex()) for i,k,d in candidates]))
  return {}
 i,k,d=candidates[0];m=available[k]
 top=[pts[3],pts[2],pts[1],pts[0]]
 length=math.dist(top[0][::2],top[1][::2]);height=max(p[1] for p in top)-min(p[1] for p in top)
 if length<=0 or height<=0:
  wall_unresolved.append(dict(region=r['id'],edge=edge,code=code,reason='degenerate_span',candidates=[dict(wall_record=i,resource=k,raw_hex=d.hex())]))
  return {}
 mode=(d[6]>>5)&3;anchor,other=[(0,1),(1,0),(3,2),(2,3)][mode]
 origin=list(top[anchor]);end=top[other]
 origin[1]=max(p[1] for p in top) if mode<2 else min(p[1] for p in top)
 scale=[2.,1.,.5,.25][d[7]&3];addressing=8 if d[6]&16 else (16 if d[6]&8 else 0)
 w,h=m['width'],m['height'];dx,dz=(end[0]-origin[0])/length,(end[2]-origin[2])/length
 uscale=scale if addressing else w/length;vscale=scale if addressing==8 else h/height
 uv=[[(((p[0]-origin[0])*dx+(p[2]-origin[2])*dz)*uscale+(d[2] if addressing else 0))/w,((p[1]-origin[1])*(-1 if mode<2 else 1)*vscale+(d[3] if addressing==8 else 0))/h] for p in pts]
 assert all(math.isfinite(c) for p in uv for c in p)
 wall_bindings.append(dict(region=r['id'],edge=edge,code=code,wall_record=i,resource=k,raw_hex=d.hex()))
 return dict(material=str(k),uv=uv)
v=g['vertices_fixed'];faces=[]
def point(i,h):return [v[i][0]/65536,h,-v[i][1]/65536]
for r in g['regions']:
 faces.append(dict(region=r['id'],kind='floor',**surface(r),points=[point(i,h) for i,h in zip(r['vertex_indices'],r['floor_corners'])]))
 for j,n in enumerate(r['neighbors']):
  if n is not None:continue
  k=(j+1)%4
  pts=[point(r['vertex_indices'][j],r['floor_corners'][j]),point(r['vertex_indices'][k],r['floor_corners'][k]),point(r['vertex_indices'][k],r['ceiling_corners'][k]),point(r['vertex_indices'][j],r['ceiling_corners'][j])]
  faces.append(dict(region=r['id'],kind='wall',points=pts,**wall_surface(r,j,j|4,pts)))
spans,audit=build(g)
for span in spans:
 pts=[[c*64 for c in p] for p in span['points']];r=g['regions'][span['region']]
 code=span['edge']|(8 if span['exposure']['kind']=='step' else 0)
 faces.append(dict(region=r['id'],kind='wall',points=pts,**wall_surface(r,span['edge'],code,pts)))
assert audit['span_count']==len(spans)
r=g['regions'][a['region']]
# Start just above the highest arrival floor corner; physics settles on its triangle.
start=[a['godot_xz'][0],max(r['floor_corners'])+34,a['godot_xz'][1]]
used_materials=sorted({f['material'] for f in faces if 'material' in f})
for key in used_materials:
 image=material_root/f'material_{int(key):04d}'/'mip_0_palette.png'
 if not image.is_file():p.error(f'missing material image {image}')
out.mkdir(parents=True,exist_ok=True)
materials={}
for k in used_materials:
 name=f'material_{k}.png';shutil.copyfile(material_root/f'material_{int(k):04d}'/'mip_0_palette.png',out/name);materials[k]=name
(out/'jungle.json').write_text(json.dumps(dict(materials=materials,alpha_cutout_materials=[k for k in materials if available[int(k)].get('alpha_cutout',False)],faces=faces,start=start,arrival_region=a['region'],
 wall_bindings=wall_bindings,wall_unresolved=wall_unresolved,interior_audit=audit,source_sha256=g['source']['sha256'],geometry_sha256=hashlib.sha256(args.geometry.read_bytes()).hexdigest(),
 scope='Original floor corners and outer boundary spans. Neutral colors, capsule height, camera and open sky authored. Reciprocal-edge step/upper spans use geometric exposure; special connectors deferred. Floor textures use source selectors and preset UV setup with provisional final axis interpretation. Supported wall textures use source record bindings and inherited provisional UV addressing. Unsupported materials, objects and gameplay absent. Native heading not applied.'),separators=(',',':'))+'\n')
wall_total=sum(f['kind']=='wall' for f in faces)
assert len(wall_bindings)+len(wall_unresolved)==wall_total
coverage=dict(source_sha256=g['source']['sha256'],wall_spans=wall_total,
 textured_walls=len(wall_bindings),unresolved_reasons=dict(Counter(r['reason'] for r in wall_unresolved)),
 unsupported_resources=dict(Counter(str(c['resource']) for r in wall_unresolved if r['reason']=='unsupported_resource' for c in r['candidates'])),
 scope='Missing record means no match under current edge/kind binding rules; it does not prove the original engine renders an opaque wall here. Degenerate spans retained for stable geometry ordering.')
# Written beside the output (formerly into the input geometry folder; inputs are never modified).
(args.output_root/'wall_coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')
print(len(faces),'source floor/boundary faces; start',start)
