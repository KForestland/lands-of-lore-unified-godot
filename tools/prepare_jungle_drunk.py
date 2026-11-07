#!/usr/bin/env python3
"""Extract the direct drunk-villager source contract using explicit original-data inputs."""
import argparse,hashlib,json,struct
from pathlib import Path
from build_game_atlas import parse_mix,section
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from prepare_jungle_bacatta import predicate
from lol2.map_video_inventory import lookup_movie
from prepare_jungle_bacatta_media import segments
p=argparse.ArgumentParser(description=__doc__)
for name in ['game','geometry','texture','assemblies','output']:p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1]
area=next(x for x in json.loads((root/'docs/game-source-inventory.json').read_text())['areas'] if x['id']=='L4_HJ')
arc=(a.game/area['source']['file']).read_bytes();assert hashlib.sha256(arc).hexdigest()==area['source']['sha256']
entry=next(e for e in parse_mix(arc) if e['key']==area['source']['geometry_key']);raw=arc[entry['offset']:entry['offset']+entry['size']];assert hashlib.sha256(raw).hexdigest()==area['source']['geometry_sha256']
owners,_=collect_owners(raw,entry['offset'],area['counts']['regions']);_,_,table=section(raw,0xbc,0xb8,5);streams=[]
for of,sf in [(0x3c,0x84),(0x44,0x8c)]:
 start,_,blob=section(raw,of,sf,1);streams.append({g:[dict(archive_offset=entry['offset']+start+off,raw_hex=b.hex()) for off,b in commands] for g,commands in groups(blob)})
records=[]
for owner in owners:
 commands=streams[owner['stream']][owner['group']];incoming=[];local7=False
 for c in commands:
  b=bytes.fromhex(c['raw_hex'])
  if len(b)>=4 and b[1]==16 and int.from_bytes(b[2:4],'little')==110:incoming.append(c)
  if len(b)>=6 and b[0]==198 and b[4]==7:local7=True
 if incoming or local7 or (owner['owner_kind']=='control' and owner['owner']==110) or (owner['owner_kind']=='prop' and owner['owner'] in [484,485]):
  records.append(dict(owner,predicate_expression=predicate(table,owner['predicate']) if owner['predicate'] is not None else None,commands=commands,incoming_control_commands=incoming))
assert len(records)==30
geo=json.loads(a.geometry.read_text())
def region(n):
 row=geo['regions'][n];assert row['id']==n
 return dict(id=n,polygon=[[geo['vertices_fixed'][v][0]/65536,-geo['vertices_fixed'][v][1]/65536] for v in row['vertex_indices']],floor_min=min(row['floor_corners']),floor_max=max(row['floor_corners']))
_,_,props=section(raw,0x14,0x60,37);_,_,controls=section(raw,0x18,0x64,33)
def placement(blob,n,size):
 row=blob[n*size:(n+1)*size];x,z,h,y=struct.unpack_from('<hhHh',row);return dict(id=n,position=[x,y,-z],heading=h,raw=row.hex())
control=placement(controls,110,33);assert bytes.fromhex(control['raw'])[32]==53
assembly=next(t for t in json.loads(a.assemblies.read_text())['source_templates'] if t['index']==53);template=bytes.fromhex(assembly['raw_hex']);assert arc.count(template)==1
resource=struct.unpack_from('<H',template,36)[0];assert resource==496
from lol2_material_format import sections
tex=a.texture.read_bytes();sec=sections(tex);d=struct.unpack_from('<6H11I',tex,sec[2]+resource*56);payload=tex[sec[3]+d[7]:sec[3]+d[7]+d[12]];assert d[3]==0x143 and payload[8:].rstrip(b'\0').upper()==b'E105E.VQA'
found=lookup_movie(a.game,'L4_HJ','E105E.VQA');assert found['status']=='exact' and found['sha256']=='eb14f0f7bc6309dc6ebf15e17f0332c8540742c5c53b9f13fe3159683e0064a7'
control.update(template=53,dimensions=assembly['dimensions'],movie_resource=496,movie='E105E.VQA',template_raw=template.hex())
result=dict(version=1,source=area['source'],control=control,starters=[placement(props,n,37) for n in [484,485]],blocked_region=region(3355),regions=[region(n) for n in sorted({g['owner'] for g in records if g['owner_kind']=='region'})],records=records,movie=dict(sha256=found['sha256'],segments=segments(found['blob'],15)),shared_local_owner='jungle_village_alarm.state.locals[7]',scope='Direct source events; modern visibility, collision and presentation clocks are supplied by live owner.')
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');print('PASS drunk contract:30 groups,17 regions, assembly53→E105E,3 segments')
