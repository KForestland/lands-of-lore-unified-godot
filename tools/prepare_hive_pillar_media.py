#!/usr/bin/env python3
"""Prepare Hive quest pillar215 using original game and a fresh Hive texture export."""
import argparse, hashlib, io, json, struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections,rgb_palette
from lol2_creature_sprite_format import decode_rows
from build_game_atlas import section
from audit_game_actor_scripts import groups


def prepare(game, texture, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    for source in (game,texture):
        if output == source or output in source.parents or source in output.parents:
            raise ValueError('Output overlaps an input')
    mix=(game/'DAT/L5_HC.MIX').read_bytes()
    blob=texture.read_bytes()
    if hashlib.sha256(mix).hexdigest()!='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8':
        raise ValueError('Unsupported Hive archive')
    if hashlib.sha256(blob).hexdigest()!='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba':
        raise ValueError('Unsupported Hive texture')
    entries=parse_mix(mix)
    def entry(key):
     e=next(e for e in entries if e['key']==key)
     return mix[e['offset']:][:e['size']]
    meta,geo=entry(3776335874),entry(3776990464)
    record=geo[u32(geo,0x14)+215*37:][:37]
    assert struct.unpack_from('<H',record,32)[0]==6
    base,count=u32(meta,8),u32(meta,0x40)
    so=base+count*55+4;fo=so+u32(meta,so-4)*16+4
    state_index=frame_index=0
    for t in range(7):
     template=meta[base+t*55:][:55]
     for _ in range(template[46]+template[47]):
      state=meta[so+state_index*16:][:16]
      frame=meta[fo+frame_index*12:][:12]
      if t==6: break
      c=struct.unpack_from('<b',state,13)[0]
      state_index+=1;frame_index+=1 if c<0 else c
    assert struct.unpack_from('<h',frame)[0]==62
    sec=sections(blob);v=struct.unpack_from('<6H11I',blob,sec[2]+62*56)
    assert v[3]==0x2c6
    payload=blob[sec[3]+v[7]:][:v[12]]
    w,h,indices,_=decode_rows(payload,expected_flags=0x2c6)
    assert (w,h)==(v[1],v[2])
    paloff=u32(blob,4);pal=rgb_palette(blob[paloff:paloff+768],6)
    rgba=bytes(c for i in indices for c in [*pal[i*3:i*3+3],255 if i else 0])
    png=io.BytesIO()
    Image.frombytes('RGBA',(w,h),rgba).save(png,format='PNG')
    _,_,stream=section(geo,0x44,0x8c,1)
    parsed=dict(groups(stream))
    commands=[]
    for group in (10414,10510):
     matches=[b for _,b in parsed[group] if b[0]==18 and b[1]==3 and struct.unpack_from('<H',b,2)[0]==215]
     assert len(matches)==1
     commands.append(matches[0])
    assert commands[0]==commands[1]
    x,y,z=[struct.unpack_from('<h',record,k)[0] for k in (0,2,6)]
    tx,ty=struct.unpack_from('<hh',commands[0],4)
    data=dict(record=215,descriptor=62,position=[x,z,-y],target=[tx,z,-ty],left=-state[14]/2+frame[5],right=state[14]/2-frame[7],bottom=frame[8],top=state[15]-frame[6],frame_flags=frame[2],placement_hex=record.hex(),state_hex=state.hex(),frame_hex=frame.hex(),movement_hex=commands[0].hex(),payload_sha256=hashlib.sha256(payload).hexdigest(),scope='Original sprite/pose/bounds and source XY operands. Fixed-Y billboard, alpha, preserved height and one-second motion are review conventions. No collision or combat callback integration.')
    out=output/'assets/lol2/generated/hive_pillar';out.mkdir(parents=True)
    (out/'pillar.png').write_bytes(png.getvalue())
    (out/'pillar.json').write_text(json.dumps(data,indent=2)+'\n')
    print('PASS Hive pillar215 source sprite and movement endpoints')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--texture',type=Path,required=True)
    p.add_argument('--output-root',type=Path,required=True)
    a=p.parse_args()
    try:
        prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,AssertionError,KeyError,IndexError,struct.error) as error:
        p.error(str(error) or type(error).__name__)


if __name__=='__main__':
    main()
