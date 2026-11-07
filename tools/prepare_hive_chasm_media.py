#!/usr/bin/env python3
"""Prepare complete Hive chasm pack from originals and explicit scene/prop inputs."""
import argparse,shutil,tempfile
from pathlib import Path
from PIL import Image
from lol2_material_format import sections,rgb_palette
from lol2_creature_sprite_format import decode_rows
import json
import hashlib,struct
from build_game_atlas import parse_mix,u32,section
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners,s16

def sha(b):return hashlib.sha256(b).hexdigest()
def source_report(game):
    archive=(game/'DAT/L5_HC.MIX').read_bytes();exe=(game/'LOLG.DAT').read_bytes()
    assert sha(archive)=='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
    assert sha(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
    e=next(e for e in parse_mix(archive) if e['key']==3776990464);geo=archive[e['offset']:e['offset']+e['size']]
    po=u32(geo,0x14)+233*37;placement=geo[po:po+37];assert struct.unpack_from('<H',placement,32)[0]==32
    eo=u32(geo,0x40)+struct.unpack_from('<H',placement,12)[0];event=geo[eo:eo+16]
    assert event.hex()=='0a099006ff09000001840606f4070700'
    so,_,stream=section(geo,0x44,0x8c,1)
    group=dict(offset=1680,commands=[dict(offset=o,source_offset=e['offset']+so+o,opcode=b[0],kind=b[1],target=struct.unpack_from('<H',b,2)[0],raw_hex=b.hex()) for o,b in dict(groups(stream))[1680]])
    code=[]
    for start,end,pin in [(0x64ddc,0x6527e,'abf7dbfc3623fc4cfceaea688e98f0707402da169fe7b07791daee65e6951f92'),(0xae2c8,0xae503,'d01ce3421fb20d1ee659183428f78b196f43a7f9f8f863838e64204f21a05d71')]:
        actual=sha(exe[start+0x37000:end+0x37000]);assert actual==pin;code.append(dict(start=start,end=end,sha256=actual))
    _,_,rows=section(geo,12,0x58,44);records=list(struct.iter_unpack('<22H',rows));floor_commands=[]
    for command in group['commands']:
        if command['opcode']!=196:continue
        b=bytes.fromhex(command['raw_hex']);region=command['target'];assert slope_corners(records,region)==[-600]*4 and b[6]==0
        target=struct.unpack_from('<h',b,4)[0];difference=target-s16(records[region][10]);assert difference>0
        # native_write_checks/filter_cases are the historical verifier's metadata.
        floor_commands.append(dict(**command,initial_floor=-600,target_floor=target,delta=difference,speed_byte=b[7],native_write_checks=4))
    assert len(floor_commands)==13
    return dict(archive_sha256=sha(archive),executable_sha256=sha(exe),code=code,rock=233,placement_hex=placement.hex(),placement_source_offset=e['offset']+po,event_hex=event.hex(),event_source_offset=e['offset']+eo,filter_cases=170,floor_commands=floor_commands,group=group,scope='Pinned rock233 kind9 mask09FF and remaining<=1 queues group1680 at boundary, tested in level0 and Hive5. Native floor initializer computes signed target-minus-current and sets moving flag; floor-write slice changes +20 without changing ceiling+22. Accepted increments supplied; cache invalidation skipped. Physical hit/context production, full event caller, scheduler, obstruction admission, clock rate and other group effects not replayed.')


def prepare(game, texture, review, props_path, output):
    if output.exists():raise ValueError('Output must be fresh')
    for source in (game,texture,review,props_path):
        if source==output or source in output.parents or output in source.parents:raise ValueError('Output overlaps an input')
    proof=source_report(game)
    archive=(game/'DAT/L5_HC.MIX').read_bytes()
    if sha(texture.read_bytes())!='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba':raise ValueError('Wrong Hive texture')
    scene=json.loads(review.read_text());props=json.loads(props_path.read_text())
    if not isinstance(scene,dict) or scene.get('source_sha256')!=proof['archive_sha256']:raise ValueError('Wrong Hive scene')
    if not isinstance(props,dict) or props.get('mix_sha256')!=proof['archive_sha256'] or props.get('blob_sha256')!=sha(texture.read_bytes()):raise ValueError('Wrong Hive props')
    with tempfile.TemporaryDirectory(prefix='hive-chasm-') as work:
        out=Path(work)
        build(archive,texture,review,props_path,proof,out)
        target=output/'assets/lol2/generated/hive_chasm'
        target.parent.mkdir(parents=True)
        shutil.copytree(out,target)


def build(archive,texture,review,props_path,proof,out):
    entries = parse_mix(archive)
    def entry(key):
        row = next(e for e in entries if e['key'] == key)
        return archive[row['offset']:row['offset'] + row['size']]
    meta, geo = entry(3776335874), entry(3776990464)
    blob = texture.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    base, count = u32(meta, 8), u32(meta, 0x40)
    state_start = base + count * 55 + 4
    frame_start = state_start + u32(meta, state_start - 4) * 16 + 4
    si = fi = 0
    selected = None
    for template_index in range(count):
        template = meta[base + template_index * 55:base + (template_index + 1) * 55]
        for state_index in range(template[46] + template[47]):
            state = meta[state_start + si * 16:state_start + (si + 1) * 16]
            frame = meta[frame_start + fi * 12:frame_start + (fi + 1) * 12]
            if template_index == 54 and state_index == 0:
                selected = (state, frame)
            views = struct.unpack_from('<b', state, 13)[0]
            si += 1
            fi += 1 if views < 0 else views
    state, frame = selected
    assert struct.unpack_from('<h', frame)[0] == 81
    section = sections(blob)
    descriptor = struct.unpack_from('<6H11I', blob, section[2] + 81 * 56)
    assert descriptor[3:5] == (0x2c6, 73)
    w, h = descriptor[1:3]
    palette_offset = u32(blob, 4)
    palette = rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    atlas = Image.new('RGBA', (w * 10, h * 8))
    cursor = section[3] + descriptor[7]
    frame_hashes = []
    for i in range(73):
        size = struct.unpack_from('<H', blob, cursor + 6)[0] + 8
        payload = blob[cursor:cursor + size]
        width, height, pixels, _ = decode_rows(payload, expected_flags=0x2c6)
        assert (width, height) == (w, h)
        rgba = bytes(c for index in pixels for c in [*palette[index * 3:index * 3 + 3], 255 if index else 0])
        atlas.paste(Image.frombytes('RGBA', (w, h), rgba), ((i % 10) * w, (i // 10) * h))
        frame_hashes.append(hashlib.sha256(payload).hexdigest())
        cursor += size
    assert cursor == section[3] + descriptor[8]
    atlas.save(out / 'rubble.png')
    rubble = []
    for index in range(188, 199):
        record = geo[u32(geo, 0x14) + index * 37:][:37]
        assert struct.unpack_from('<H', record, 32)[0] == 54
        x, y, _, z = struct.unpack_from('<hhHh', record)
        rubble.append(dict(record=index, position=[x, z, -y], placement_hex=record.hex()))
    staged = json.loads(review.read_text())
    floors = []
    for command in proof['floor_commands']:
        faces = [f for f in staged['faces'] if f['region'] == command['target'] and f['kind'] == 'floor']
        assert len(faces) == 1 and all(p[1] == -600 for p in faces[0]['points'])
        region = struct.unpack_from('<22H', geo, u32(geo,12) + command['target'] * 44)
        expected = [[x/65536,-600,-y/65536] for x,y in [struct.unpack_from('<ii',geo,u32(geo,4)+i*8) for i in region[6:10]]]
        assert faces[0]['points'] == expected, 'Scene floor differs from original polygon'
        floors.append(dict(**faces[0], target_height=command['target_floor']))
    props = json.loads(props_path.read_text())
    trigger = next(p for p in props['props'] if p['record'] == 233)
    assert trigger['placement_hex'] == proof['placement_hex'] and trigger['placement_offset'] == proof['placement_source_offset']
    raw = bytes.fromhex(trigger['placement_hex'])
    x,y,heading,z = struct.unpack_from('<hhHh',raw)
    assert trigger['position'] == [x,z,-y] and trigger['template'] == 32
    for field in ('state','frame'):
        data=bytes.fromhex(trigger[field+'_hex']);start=trigger[field+'_offset']
        assert archive[start:start+len(data)] == data, 'Prop record differs from original'
    assert bytes.fromhex(trigger['template_hex']) == meta[u32(meta,8)+32*55:u32(meta,8)+33*55]

    result = dict(archive_sha256=proof['archive_sha256'], trigger=trigger, floors=floors,
                  rubble=rubble, rubble_size=[state[14] - frame[7] - frame[5], state[15] - frame[6] - frame[8]],
                  frame_size=[w, h], frame_count=73, atlas_columns=10, frame_hashes=frame_hashes,
                  scope='Original floor target heights, existing floor UV/materials, rock233 pose/bounds and 73 rubble frames. '
                  '15fps/one-sequence movement duration, simultaneous motion, hit cylinder and single melee hit are authored. '
                  'Native dynamic wall rebuilding, projectile state, executioner response and damage/clock timing not reproduced.')
    (out / 'chasm.json').write_text(json.dumps(result, indent=2) + '\n')
    (out / 'provenance.json').write_text(json.dumps(proof, indent=2) + '\n')
    print('Staged 13 floor patches, 11 source rubble positions and all73 source frames')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['game','texture','review','props','output-root']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.review.resolve(),a.props.resolve(),a.output_root.resolve())
    except (ValueError,OSError,AssertionError,KeyError,IndexError,struct.error) as error:p.error(str(error) or type(error).__name__)

if __name__=='__main__':main()
