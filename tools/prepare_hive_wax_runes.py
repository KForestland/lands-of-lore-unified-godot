#!/usr/bin/env python3
"""Stage original wax-rune inventory artwork (definition74/resource108)."""
import json,struct
from PIL import Image
from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32

def main():
    definitions=entry('GLOBAL.MIX',3984507021);assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base,count=u32(definitions,4),u32(definitions,0x34);so=base+count*91+4;fo=so+u32(definitions,so-4)*16+4;si=vi=0;resource=None
    for i in range(count):
        d=definitions[base+i*91:][:91]
        for selector in range(d[46]+d[47]):
            views=max(1,struct.unpack_from('<b',definitions,so+si*16+13)[0])
            if i==74:
                assert selector==0 and views==1 and d[50]==4 and u32(d,24)==0xb45b2813
                resource=struct.unpack_from('<h',definitions,fo+vi*12)[0]
            si+=1;vi+=views
    assert resource==108
    graphics=entry('LOCAL.MIX',4018716831);assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
    sec=sections(graphics);desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56);payload=graphics[sec[3]+desc[7]:][:desc[12]]
    w,h,pixels,_=decode_rows(payload,allow_special=True);assert (w,h)==desc[1:3]
    palette=rgb_palette(graphics[u32(graphics,4):][:768],6)
    rgba=bytes(c for i in pixels for c in (*palette[i*3:i*3+3],0 if i in (0,1) else 255))
    out=ROOT/'assets/lol2/generated/hive_wax_runes';out.mkdir(parents=True,exist_ok=True);Image.frombytes('RGBA',(w,h),rgba).save(out/'runes.png')
    (out/'runes.json').write_text(json.dumps(dict(definition=74,identity=0xb45b2813,resource=resource,size=[w,h],definitions_sha256=digest(definitions),graphics_sha256=digest(graphics),pixels_sha256=digest(pixels),omitted_remap_pixels=pixels.count(1)),indent=2)+'\n')
    print('PASS wax-rune definition74/resource108 artwork',w,h)
def explicit_main():
    import argparse
    from pathlib import Path
    import prepare_hive_wax as wax
    global ROOT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--output-root',type=Path,required=True)
    args=parser.parse_args();game=args.game.resolve();ROOT=args.output_root.resolve()
    if ROOT.exists():parser.error('Output must be a fresh directory')
    if ROOT==game or ROOT in game.parents or game in ROOT.parents:parser.error('Output overlaps original game')
    try:
        for name,wanted in [('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                            ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
            if digest((game/name).read_bytes())!=wanted:raise ValueError('Unsupported original '+name)
        wax.GAME=game
        main()
    except (OSError,ValueError,AssertionError) as error:parser.error(str(error) or type(error).__name__)

if __name__=='__main__':
    import sys
    if len(sys.argv)>1:explicit_main()
    else:main()
