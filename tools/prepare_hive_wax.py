#!/usr/bin/env python3
"""Stage Hive item0 wax at its source position and original global sprite."""
import json, struct, sys
from pathlib import Path
from PIL import Image
import hashlib
from lol2_source_format import parse_mix, u32
from lol2_material_format import sections, rgb_palette
from lol2_creature_sprite_format import decode_rows
ROOT = Path(__file__).resolve().parents[1]
GAME = Path('~/lol2_out/museum_capture_20260913/game')
SOURCE = ROOT / 'docs/game-source-inventory.json'
def digest(raw): return hashlib.sha256(raw).hexdigest()

def entry(filename,key):
    archive=(GAME/filename).read_bytes()
    row=next(e for e in parse_mix(archive) if e['key']==key)
    return archive[row['offset']:][:row['size']]

def main():
    level=entry('DAT/L5_HC.MIX',3776990464)
    source=json.loads(SOURCE.read_text())
    assert digest(level)==next(a for a in source['areas'] if a['id']=='L5_HC')['source']['geometry_sha256']
    row=level[u32(level,0x20):][:37]
    assert row.hex()=='7cf1251b000049fc0200c804000000000000000024747f00397c5a0024000500cfda5aae00'
    x,y,_,z=struct.unpack_from('<hhHh',row)
    assert (x,y,z)==(-3716,6949,-951) and u32(row,32)==2925189839
    flags=struct.unpack_from('<H',row,8)[0]
    assert flags==2 and not flags&0x1000
    definitions=entry('GLOBAL.MIX',3984507021)
    assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base,count=u32(definitions,4),u32(definitions,0x34)
    state=base+count*91+4;ns=u32(definitions,state-4);view=state+ns*16+4
    si=vi=0;resource=None
    for i in range(count):
        definition=definitions[base+i*91:][:91]
        for selector in range(definition[46]+definition[47]):
            views=max(1,struct.unpack_from('<b',definitions,state+si*16+13)[0])
            if i==73:
                assert selector==0 and u32(definition,24)==2925189839 and definition[50]==4 and views==1
                resource=struct.unpack_from('<h',definitions,view+vi*12)[0]
            si+=1;vi+=views
    assert resource==109
    graphics=entry('LOCAL.MIX',4018716831)
    assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
    sec=sections(graphics);desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
    payload=graphics[sec[3]+desc[7]:][:desc[12]]
    w,h,pixels,marked=decode_rows(payload,allow_special=True);assert (w,h)==desc[1:3]
    palette=rgb_palette(graphics[u32(graphics,4):][:768],6)
    rgba=bytes(c for i in pixels for c in (*palette[i*3:i*3+3],0 if i in (0,1) else 255))
    out=ROOT/'assets/lol2/generated/hive_wax';out.mkdir(parents=True,exist_ok=True)
    Image.frombytes('RGBA',(w,h),rgba).save(out/'wax.png')
    report=dict(id='hive:item0:Wax',position=[x,z,-y],placement_hex=row.hex(),flags=flags,region=1224,
                definition=73,identity=2925189839,resource=resource,size=[w,h],
                level_sha256=digest(level),definitions_sha256=digest(definitions),graphics_sha256=digest(graphics),
                pixels_sha256=digest(pixels),omitted_remap_pixels=pixels.count(1),
                scope='Source item0 position/identity and global artwork. Inactive bit1000 clear; flags2 alone are not dormant. Modern pickup reach/aim and sprite scale/pivot; native pickup admission and full-route reachability not replayed.')
    (out/'wax.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'docs/hive-wax-source.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS: Hive wax item0, definition73/resource109, source position',report['position'],'sprite',w,h)
def explicit_main():
    import argparse
    global GAME, ROOT, SOURCE
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['game','source','output-root']:parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();GAME=args.game.resolve();ROOT=args.output_root.resolve();SOURCE=args.source.resolve()
    if ROOT.exists():parser.error('Output must be a fresh directory')
    for path in [GAME,SOURCE]:
        if ROOT==path or ROOT in path.parents or path in ROOT.parents:parser.error('Output overlaps input')
    try:
        for name,wanted in [('DAT/L5_HC.MIX','a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'),
                            ('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                            ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
            if digest((GAME/name).read_bytes())!=wanted:raise ValueError('Unsupported original '+name)
        profile=next(a for a in json.loads(SOURCE.read_text())['areas'] if a['id']=='L5_HC')
        if profile['source']['geometry_sha256']!='69a9c0dd739ad36691c6513d53cf007204aa3bd35d5762e8f8f4e8c6dbcb9e85':raise ValueError('Unsupported Hive profile')
        (ROOT/'docs').mkdir(parents=True)
        main()
    except (OSError,ValueError,AssertionError,KeyError,StopIteration) as error:parser.error(str(error) or type(error).__name__)

if __name__=='__main__':
    if len(sys.argv)>1:explicit_main()
    else:main()
