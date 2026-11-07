#!/usr/bin/env python3
"""Prepare both Jungle village gate leaves directly from original records."""
import argparse,json,struct,sys,tempfile
from pathlib import Path
from prepare_jungle_followup_gate_media import model,require,sha,ARCHIVE,GEOMETRY,TEXTURE
from lol2_source_format import parse_mix,u32
from lol2_geometry_format import slope_corners
from lol2_rotation_table import rotation_table
from build_game_atlas import section
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from export_map_movables import _box_faces,_QUAD_UV,_QUAD_UV_FACE3

def prepare(game,output):
    require(not output.exists(),'Output must be fresh')
    require(output!=game and output not in game.parents and game not in output.parents,'Output overlaps input')
    arc=(game/'DAT/L4_HJ.MIX').read_bytes();require(sha(arc)==ARCHIVE,'Unsupported Jungle archive')
    entries={e['key']:e for e in parse_mix(arc)}
    ge,me=entries[3710797084],entries[3710142494]
    raw,meta=[arc[e['offset']:e['offset']+e['size']] for e in (ge,me)]
    require(sha(raw)==GEOMETRY,'Geometry differs')
    owners,_=collect_owners(raw,ge['offset'],u32(raw,0x58))
    require(any(o['owner_kind']=='region' and o['owner']==2443 and o['predicate']==154 and o['group']==4354 and o['event']==2 for o in owners),'Admission owner differs')
    table=section(raw,0xbc,0xb8,5)[2]
    for index,want in {97:'0002260001',98:'00021d0000',99:'0604610462',153:'0003180000',154:'0604630499'}.items():
        require(table[index*5:index*5+5].hex()==want,'Admission predicate differs')
    commands=[b.hex() for _,b in dict(groups(section(raw,0x3c,0x84,1)[2]))[4354]]
    require(commands[-2:]==['01204f006400','01204e006400'] and 'c60000001801' in commands,'Gate commands differ')
    vertices=list(struct.iter_unpack('<ii',section(raw,4,0x50,8)[2]))
    records=list(struct.iter_unpack('<22H',section(raw,12,0x58,44)[2]))
    polygon=[[vertices[v][0]/65536,-vertices[v][1]/65536] for v in records[2443][6:10]]
    to,nt=u32(meta,12),u32(meta,0x44);co=to+nt*60+4
    require(sum(meta[to+i*60+50] for i in range(nt))==u32(meta,co-4),'Child table differs')
    trig=struct.unpack('<4096i',rotation_table(game));leaves=[];resources=set()
    for index,expected_template,expected_mode,expected_faces in [(78,6,4,4),(79,5,3,5)]:
        d=raw[u32(raw,0x24)+index*41:][:41]
        x,y,heading,height=struct.unpack_from('<hhHh',d);mode=d[33]
        require((d[32],mode,heading)==(expected_template,expected_mode,16384),'Gate placement differs')
        template=meta[to+d[32]*60:to+(d[32]+1)*60]
        first=sum(meta[to+i*60+50] for i in range(d[32]));closed=[]
        for child_index in range(first,first+template[50]):
            child=meta[co+child_index*60:co+(child_index+1)*60]
            if not u32(child,48)&1:continue
            require(child[59]==0,'Unsupported gate child')
            for face,points in enumerate(_box_faces(struct.unpack_from('<4b2B',child,52))):
                resource=struct.unpack_from('<h',child,face*8)[0]
                if resource==0:continue
                require(resource in (514,742),'Gate material differs');resources.add(resource)
                world=[]
                for lx,lz,ly in points:
                    wx,wy=model((lx<<16,ly<<16),(x<<16,y<<16),heading,trig)
                    world.append([wx/65536,lz+height,-wy/65536])
                closed.append(dict(points=world,uv=[list(v) for v in (_QUAD_UV_FACE3 if face==3 else _QUAD_UV)],material=f'material_{resource:04d}.png'))
        require(len(closed)==expected_faces,'Closed face count differs')
        width,depth,_=template[47:50];hx,hy=(width//2)<<16,(depth//2)<<16
        corner=[(-hx,hy),(hx,hy),(-hx,-hy),(hx,-hy)][mode//2]
        pivot=model(corner,(x<<16,y<<16),heading,trig);travel=d[36]*2*65536//360;frames=[]
        for percent in range(101):
            angle=(heading+(-1 if mode&1 else 1)*(travel*percent//100))&65535
            center=model(tuple(-v for v in corner),pivot,angle,trig);faces=[]
            for face in closed:
                points=[]
                for px,z,negative_y in face['points']:
                    wx,wy=model((round((negative_y+y)*65536),round((px-x)*65536)),center,angle,trig)
                    points.append([wx/65536,z,-wy/65536])
                if percent==0:require(points==face['points'],'Closed pose differs')
                faces.append(dict(vertices=points,uv=face['uv'],material=face['material']))
            frames.append(faces)
        leaves.append(dict(index=index,placement_hex=d.hex(),mode=mode,travel=travel,pivot=[pivot[0]/65536,height,-pivot[1]/65536],frames=frames))
    payload=dict(region=2443,polygon=polygon,floor=slope_corners(records,2443),ceiling=slope_corners(records,2443,True),leaves=leaves,scope='Source closed faces and paired hinge path. Modern timing/collision, not native event dispatch or pushing.')
    sys.path.insert(0,str(Path(__file__).resolve().parent/'lol2'))
    import map_materials
    with tempfile.TemporaryDirectory(prefix='jungle-village-gates-') as temp:
        fresh=Path(temp)/'materials';map_materials.export_materials(game,'L4_HJ',fresh)
        require(sha((fresh/'texture.bin').read_bytes())==TEXTURE,'Texture differs')
        files={f'material_{k:04d}.png':(fresh/f'material_{k:04d}/mip_0_palette.png').read_bytes() for k in resources}
    files['gates.json']=(json.dumps(payload,separators=(',',':'))+'\n').encode()
    out=output/'assets/lol2/generated/jungle_village';out.mkdir(parents=True)
    for name,data in files.items():(out/name).write_bytes(data)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('game','output-root'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
    print('PASS Jungle village gates78/79: 101 poses each')
if __name__=='__main__':main()
