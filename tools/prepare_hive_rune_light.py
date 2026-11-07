#!/usr/bin/env python3
"""Stage prop377's original unlit sprite and eight lit frames."""
import json,struct
from pathlib import Path
from PIL import Image
from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32

TEXTURE=Path('~/lol2_out/all_maps_20260922/L5_HC/texture.bin')

def main():
    raw=entry('DAT/L5_HC.MIX',3776990464);row=raw[u32(raw,0x14)+377*37:][:37]
    assert row.hex()=='50f3a3180000a3f982464503e207064c067c0615fc95fc16001e0000020002002400000003'
    meta=entry('DAT/L5_HC.MIX',3776335874);base,count=u32(meta,8),u32(meta,0x40);so=base+count*55+4;fo=so+u32(meta,so-4)*16+4;si=fi=0;states=[]
    for i in range(count):
        d=meta[base+i*55:][:55]
        for selector in range(d[46]+d[47]):
            s=meta[so+si*16:][:16];views=max(1,struct.unpack_from('<b',s,13)[0])
            if i==36:
                assert views==1
                f=meta[fo+fi*12:][:12]
                states.append(dict(selector=selector,resource=struct.unpack_from('<h',f)[0],state_hex=s.hex(),frame_hex=f.hex(),bounds=[-s[14]/2+f[5],s[14]/2-f[7],f[8],s[15]-f[6]]))
            si+=1;fi+=views
    assert [s['resource'] for s in states]==[293,285]
    blob=TEXTURE.read_bytes()
    assert digest(blob)=='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    sec=sections(blob);pal=rgb_palette(blob[u32(blob,4):][:768],6);out=ROOT/'assets/lol2/generated/hive_rune_light';out.mkdir(parents=True,exist_ok=True)
    for state in states:
        desc=struct.unpack_from('<6H11I',blob,sec[2]+state['resource']*56);expected=1 if state['selector']==0 else 8
        assert desc[4]==expected and desc[3]==(0x28e if expected==1 else 0x2c6)
        pos=sec[3]+desc[7];state['images']=[]
        for frame in range(expected):
            size=8+struct.unpack_from('<H',blob,pos+6)[0];payload=blob[pos:pos+size]
            w,h,pixels,_=decode_rows(payload,expected_flags=desc[3],allow_special=True);assert (w,h)==desc[1:3]
            rgba=bytes(c for i in pixels for c in (*pal[i*3:i*3+3],0 if i in [0,1] else 255))
            name=f'state{state["selector"]}_{frame}.png';Image.frombytes('RGBA',(w,h),rgba).save(out/name)
            state['images'].append(dict(file=name,pixels_sha256=digest(pixels),payload_sha256=digest(payload)));pos+=size
        if expected>1:assert pos==sec[3]+desc[8]
    x,y,_,z=struct.unpack_from('<hhHh',row)
    report=dict(placement_hex=row.hex(),position=[x,z,-y],geometry_sha256=digest(raw),metadata_sha256=digest(meta),blob_sha256=digest(blob),states=states,scope=__doc__,limits='Source state resources and bounds; sprite billboarding, aim proxy and looping rate are modern presentation adapters. Special remap index1 omitted consistently with other staged sprites.')
    (out/'light.json').write_text(json.dumps(report,indent=2)+'\n');(ROOT/'docs/hive-rune-light-source.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS original prop377 unlit sprite/eight lit frames at',report['position'])
def explicit_main():
    import argparse
    import prepare_hive_wax as wax
    global ROOT,TEXTURE
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['game','texture','output-root']:parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();game=args.game.resolve();ROOT=args.output_root.resolve();TEXTURE=args.texture.resolve()
    if ROOT.exists():parser.error('Output must be a fresh directory')
    for path in [game,TEXTURE]:
        if ROOT==path or ROOT in path.parents or path in ROOT.parents:parser.error('Output overlaps input')
    try:
        if digest((game/'DAT/L5_HC.MIX').read_bytes())!='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8':raise ValueError('Unsupported Hive archive')
        if digest(TEXTURE.read_bytes())!='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba':raise ValueError('Unsupported Hive texture')
        wax.GAME=game
        (ROOT/'docs').mkdir(parents=True)
        main()
    except (OSError,ValueError,AssertionError) as error:parser.error(str(error) or type(error).__name__)

if __name__=='__main__':
    import sys
    if len(sys.argv)>1:explicit_main()
    else:main()
