#!/usr/bin/env python3
"""Prepare the Jungle follow-up gate from original records and fresh materials."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners
from lol2_rotation_table import rotation_table
from export_map_movables import _box_faces, _QUAD_UV, _QUAD_UV_FACE3

ARCHIVE = '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'
GEOMETRY = '445d9b270d3e62574d719851305e3e30867715993f073a2dcd0e888295172aba'
TEXTURE = '98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def model(point, origin, angle, table):
    """Published verify_chain_rotation integer formula, without replay imports."""
    def signed(value):
        value &= 0xffffffff
        return value - 0x100000000 if value & 0x80000000 else value
    def sine(a):
        a &= 65535
        return table[(a & 32767) >> 3] * (-1 if a & 32768 else 1)
    s, c = sine(angle), sine(angle + 16384)
    x, y = point
    def mul(a, b):
        return signed((signed(a) * signed(b)) >> 16)
    return (signed(origin[0] + mul(x, c) + mul(y, s)),
            signed(origin[1] + mul(y, c) - mul(x, s)))


def prepare(game, output):
    require(not output.exists(), 'Output must be fresh')
    require(output != game and output not in game.parents and game not in output.parents,
            'Output overlaps original game')
    archive = (game / 'DAT/L4_HJ.MIX').read_bytes()
    require(sha(archive) == ARCHIVE, 'Unsupported Jungle archive')
    entries = {e['key']: e for e in parse_mix(archive)}
    entry = entries[3710797084]
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    require(sha(raw) == GEOMETRY, 'Unsupported Jungle geometry')
    me = entries[3710142494]
    meta = archive[me['offset']:me['offset'] + me['size']]
    _, _, predicates = section(raw, 0xbc, 0xb8, 5)
    expected = {136:'0604870424',135:'0604890485',137:'0003120001',133:'0002120000',36:'00032e0000',181:'0604860462',134:'0003120000',98:'00021d0000',167:'0002120001',43:'00032e0001'}
    for index, hexed in expected.items():
        require(predicates[index*5:index*5+5].hex() == hexed, 'Predicate differs')
    owners, _ = collect_owners(raw, entry['offset'], u32(raw, 0x58))
    for region, predicate, group in [(3255,136,6380),(3262,181,6498)]:
        require(any(o['owner_kind']=='region' and o['owner']==region and o['predicate']==predicate and o['group']==group for o in owners), 'Region owner differs')
    commands = dict(groups(section(raw,0x3c,0x84,1)[2]))
    require('012046006400' in [d.hex() for _,d in commands[6380]], 'Open command differs')
    require([d.hex() for _,d in commands[6498]] == ['091055000300','c60000001201'], 'Arming commands differ')
    require('012046000000' in [d.hex() for _,d in dict(groups(section(raw,0x44,0x8c,1)[2]))[19638]], 'Close command differs')
    vertices = list(struct.iter_unpack('<ii',section(raw,4,0x50,8)[2]))
    records = list(struct.iter_unpack('<22H',section(raw,12,0x58,44)[2]))
    def polygon(index):
        return [[vertices[v][0]/65536,-vertices[v][1]/65536] for v in records[index][6:10]]
    d = raw[u32(raw,0x24)+70*41:][:41]
    x,y,heading,height = struct.unpack_from('<hhHh',d)
    require((d[32],d[33],heading)==(34,1,0),'Gate placement differs')
    to,nt = u32(meta,12),u32(meta,0x44)
    template = meta[to+34*60:to+35*60]
    require(template[50]==1,'Gate child count differs')
    first = sum(meta[to+i*60+50] for i in range(34))
    offset = to+nt*60+4+first*60
    child = meta[offset:offset+60]
    require(child[59]==0 and u32(child,48)==0xffffffff,'Gate child selection differs')
    resources = [struct.unpack_from('<h',child,i*8)[0] for i in range(6)]
    require(resources==[0,0,92,92,92,92],'Gate surfaces differ')
    bounds = struct.unpack_from('<4b2B',child,52)
    trig = struct.unpack('<4096i',rotation_table(game))
    width,depth,_ = template[47:50]
    corner = (-(width//2)<<16,(depth//2)<<16)
    pivot = model(corner,(x<<16,y<<16),heading,trig)
    travel = d[36]*2*65536//360
    closed = []
    for face,points in enumerate(_box_faces(bounds)):
        if not resources[face]:
            continue
        world = []
        for lx,lz,ly in points:
            wx,wy = model((lx<<16,ly<<16),(x<<16,y<<16),heading,trig)
            world.append([wx/65536,lz+height,-wy/65536])
        closed.append(dict(points=world,uv=[list(v) for v in (_QUAD_UV_FACE3 if face==3 else _QUAD_UV)]))
    frames = []
    for percent in range(101):
        # Preserve the legacy negative-direction rounding: negate after division.
        angle = (heading-(travel*percent//100))&65535
        center = model(tuple(-v for v in corner),pivot,angle,trig)
        faces = []
        for face in closed:
            points = []
            for px,z,negative_y in face['points']:
                wx,wy = model((round((px-x)*65536),round((-negative_y-y)*65536)),center,angle,trig)
                points.append([wx/65536,z,-wy/65536])
            if percent==0:
                require(points==face['points'],'Closed pose differs')
            faces.append(dict(vertices=points,uv=face['uv'],material='material_0092.png'))
        frames.append(faces)
    leaf = dict(index=70,placement_hex=d.hex(),mode=1,travel=travel,pivot=[pivot[0]/65536,height,-pivot[1]/65536],frames=frames)
    payload = dict(region=3255,polygon=polygon(3255),floor=slope_corners(records,3255),ceiling=slope_corners(records,3255,True),leaves=[leaf],scope='Source closed faces and single hinge path. Modern timing/collision, not native event dispatch or pushing.')
    payload['arming_polygon'] = polygon(3262)
    payload['arming_floor'] = slope_corners(records,3262)
    exe = (game/'LOLG.DAT').read_bytes()
    code_hash = sha(exe[0x111d68+0x37000:0x111e21+0x37000])
    require(code_hash=='c70c8bebe00b573dc38c0f81e28778e2bebc8157e813c9db8a111689ab8854db','Rotation code differs')
    source = dict(file='DAT/L4_HJ.MIX',sha256=ARCHIVE,geometry_key=3710797084,geometry_sha256=GEOMETRY)
    # Historical native-replay count retained; this command does not replay code.
    evidence = dict(source=source,movable=70,rotation_checks=101,rotation_code_sha256=code_hash,arming_region=3262,speech_region=3255,predicates=expected,conditions={'arm':'local18==0 AND shared29==0','speak':'local18==1 AND shared18==0 AND local46==0'},scope='Source hinge and control85 region links. Explicit modern clock; other group effects separate.')
    sys.path.insert(0,str(Path(__file__).resolve().parent/'lol2'))
    import map_materials
    with tempfile.TemporaryDirectory(prefix='jungle-followup-materials-') as temp:
        fresh = Path(temp)/'materials'
        map_materials.export_materials(game,'L4_HJ',fresh)
        require(sha((fresh/'texture.bin').read_bytes())==TEXTURE,'Texture differs')
        png = (fresh/'material_0092/mip_0_palette.png').read_bytes()
    out = output/'assets/lol2/generated/jungle_followup'
    out.mkdir(parents=True)
    (out/'material_0092.png').write_bytes(png)
    (out/'gates.json').write_text(json.dumps(payload,separators=(',',':'))+'\n')
    (output/'docs').mkdir()
    (output/'docs/jungle-followup-source.json').write_text(json.dumps(evidence,indent=2)+'\n')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('game','output-root'):
        p.add_argument('--'+name,type=Path,required=True)
    a = p.parse_args()
    try:
        prepare(a.game.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:
        p.error(str(error))
    print('PASS Jungle follow-up gate: 101 poses and original region bindings')

if __name__=='__main__':
    main()
