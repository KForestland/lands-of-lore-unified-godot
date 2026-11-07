#!/usr/bin/env python3
"""Prepare the existing Hive warrior pose and two structural actor bindings."""
import argparse,hashlib,io,json,struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections,rgb_palette
from lol2_creature_sprite_format import parse_states,lcw,decode_blocks
from build_game_atlas import section
from audit_game_actor_scripts import groups
from audit_game_transition_owners import events

ARCHIVE='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
TEXTURE='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'

def sha(b):return hashlib.sha256(b).hexdigest()
def require(value,message):
    if not value:raise ValueError(message)

def prepare(game,texture,output):
    require(not output.exists(),'Output must be fresh')
    for source in (game,texture):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps an input')
    arc=(game/'DAT/L5_HC.MIX').read_bytes();blob=texture.read_bytes()
    require(sha(arc)==ARCHIVE and sha(blob)==TEXTURE,'Unsupported Hive archive or texture')
    entries={e['key']:e for e in parse_mix(arc)};ge,me=entries[3776990464],entries[3776335874]
    geo,meta=[arc[e['offset']:e['offset']+e['size']] for e in (ge,me)]
    entity=parse_states(meta)['entities'][0];require(entity['name']=='HIVEW','Warrior definition differs')
    state=entity['states'][0];require(len(state['views'])==1 and state['views'][0]['resource_reference']==1503,'Warrior view differs')
    sec=sections(blob);d=struct.unpack_from('<6H11I',blob,sec[2]+1503*56);require(d[3]==0x1246,'Warrior sprite format differs')
    payload=blob[sec[3]+d[7]:sec[3]+d[7]+d[12]]
    require(sha(payload)=='c523b4c7ed703eb6978d4ff73ed1c8040aefe7449f794cf7d32061fead879735','Pose payload differs')
    ci=struct.unpack_from('<I',payload,8)[0]
    require(sec[9]+ci*12+12<=min(x for x in sec if x>sec[9]),'Codebook index out of bounds')
    offset,allocation,packed=struct.unpack_from('<3I',blob,sec[9]+ci*12)
    require(sec[8]<=offset and offset+allocation<=sec[9] and 0<packed<=allocation,'Codebook extent differs')
    book=lcw(blob[offset:offset+packed]);w,h,pixels,used,tail=decode_blocks(payload,book)
    require((w,h)==d[1:3],'Pose dimensions differ')
    po=u32(blob,4);pal=rgb_palette(blob[po:po+768],6)
    rgba=bytes(c for index in pixels for c in (*pal[index*3:index*3+3],255 if index else 0))
    png=io.BytesIO();Image.frombytes('RGBA',(w,h),rgba).save(png,format='PNG')
    pose=dict(name='HIVEW',resource=1503,file='HIVEW_1503.png',state=state,payload_sha256=sha(payload),codebook=ci,codebook_sha256=sha(book),unread_tail_bytes=tail)
    stream_start,_,stream=section(geo,0x44,0x8c,1)
    parsed={g:dict(offset=g,commands=[dict(offset=o,source_offset=ge['offset']+stream_start+o,opcode=b[0],kind=b[1],target=struct.unpack_from('<H',b,2)[0],raw_hex=b.hex()) for o,b in rows]) for g,rows in groups(stream)}
    event_start,_,triggers=section(geo,0x40,0x88,1);actors=[]
    for index in (32,34):
        start=u32(geo,0x1c)+index*56;raw=geo[start:start+56]
        require(len(raw)==56 and raw[32]==0,'Actor definition differs')
        x,y,heading,z=struct.unpack_from('<hhHh',raw);listing=[]
        for cursor,kind,body,predicate in events(triggers,struct.unpack_from('<H',raw,12)[0]):
            row=dict(offset=cursor,source_offset=ge['offset']+event_start+cursor,kind=kind,raw_hex=body.hex())
            if kind in (2,3,4,5,6,9,10):row['group']=parsed[struct.unpack_from('<H',body,2)[0]]
            row['predicate']=predicate;listing.append(row)
        actors.append(dict(index=index,position=[x,z,-y],region=struct.unpack_from('<H',raw,10)[0],heading=heading,raw_hex=raw.hex(),source_offset=ge['offset']+start,events=listing,definition_candidate=0,name_candidate='HIVEW'))
    require([a['position'] for a in actors]==[[-1052,-235,-8435],[-906,-235,-7308]],'Warrior positions differ')
    result=dict(pose=pose,actors=actors,png_sha256=sha(png.getvalue()),scope='Recovered static selector0 pose and structural source actor placements; review encounter activation, combat rules and event10 defeat timing are authored.')
    target=output/'assets/lol2/generated/hive_warriors';target.mkdir(parents=True)
    (target/'warrior.png').write_bytes(png.getvalue());(target/'provenance.json').write_text(json.dumps(result,indent=2)+'\n')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['game','texture','output-root']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
    print('PASS original Hive warrior pose and two actor bindings')

if __name__=='__main__':main()
