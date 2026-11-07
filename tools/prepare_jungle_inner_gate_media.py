#!/usr/bin/env python3
"""Prepare the Jungle inner gate leaves directly from original records."""
import argparse,json,math,struct,sys,tempfile
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
    streams=[dict(groups(section(raw,o,c,1)[2])) for o,c in [(0x3c,0x84),(0x44,0x8c)]]
    for stream,group,want in [(0,5160,['01204a006400','01204b006400']),(1,21138,['01204b000000','01204a000000']),(1,21156,['01204b006400','01204a006400']),(1,27916,['01204a006400','01204a006400']),(1,27934,['01204a006400','01204b006400'])]:
        require([b.hex() for _,b in streams[stream][group]]==want,'Inner gate commands differ')
    to,nt=u32(meta,12),u32(meta,0x44);co=to+nt*60+4
    require(sum(meta[to+i*60+50] for i in range(nt))==u32(meta,co-4),'Child table differs')
    trig=struct.unpack('<4096i',rotation_table(game));leaves=[];resources=set()
    for index,expected_template,expected_mode,expected_faces in [(74,43,4,4),(75,43,1,4)]:
        d=raw[u32(raw,0x24)+index*41:][:41]
        x,y,heading,height=struct.unpack_from('<hhHh',d);mode=d[33]
        require((d[32],mode)==(expected_template,expected_mode),'Gate placement differs')
        template=meta[to+d[32]*60:to+(d[32]+1)*60]
        first=sum(meta[to+i*60+50] for i in range(d[32]));closed=[]
        for child_index in range(first,first+template[50]):
            child=meta[co+child_index*60:co+(child_index+1)*60]
            if not u32(child,48)&1:continue
            require(child[59]==0,'Unsupported gate child')
            for face,points in enumerate(_box_faces(struct.unpack_from('<4b2B',child,52))):
                resource=struct.unpack_from('<h',child,face*8)[0]
                if resource==0:continue
                require(resource in (522,742),'Gate material differs');resources.add(resource)
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
            delta=((-1 if mode&1 else 1)*(travel*percent//100))&65535
            faces=[]
            for face in closed:
                points=[]
                for px,z,negative_y in face['points']:
                    wx,wy=model((round(px*65536)-pivot[0],round(-negative_y*65536)-pivot[1]),pivot,delta,trig)
                    points.append([wx/65536,z,-wy/65536])
                if percent==0:require(all(abs(a-b)<1e-3 for v,q in zip(points,face['points']) for a,b in zip(v,q)),'Rest pose differs')
                faces.append(dict(vertices=points,uv=face['uv'],material=face['material']))
            frames.append(faces)
        leaves.append(dict(index=index,mode=mode,travel=travel,pivot=[pivot[0]/65536,0,-pivot[1]/65536],frames=frames,faces=len(closed)))
    def far(leaf):
        points=[v for f in leaf['frames'][0] for v in f['vertices']]
        return max(points,key=lambda v:(v[0]-leaf['pivot'][0])**2+(v[2]-leaf['pivot'][2])**2)
    a,b=far(leaves[0]),far(leaves[1]);gap=math.hypot(a[0]-b[0],a[2]-b[2]);require(gap<6,'Shut gap differs')
    payload=dict(leaves=leaves,shut_gap=gap)
    sys.path.insert(0,str(Path(__file__).resolve().parent/'lol2'))
    import map_materials
    with tempfile.TemporaryDirectory(prefix='jungle-inner-gates-') as temp:
        fresh=Path(temp)/'materials';map_materials.export_materials(game,'L4_HJ',fresh)
        require(sha((fresh/'texture.bin').read_bytes())==TEXTURE,'Texture differs')
        files={f'material_{k:04d}.png':(fresh/f'material_{k:04d}/mip_0_palette.png').read_bytes() for k in resources}
    files['leaves.json']=(json.dumps(payload,separators=(',',':'))+'\n').encode()
    out=output/'assets/lol2/generated/jungle_inner_gate';out.mkdir(parents=True)
    for name,data in files.items():(out/name).write_bytes(data)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('game','output-root'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
    print('PASS Jungle inner gates74/75: 101 poses each')
if __name__=='__main__':main()
