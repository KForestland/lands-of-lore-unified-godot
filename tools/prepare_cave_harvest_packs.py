#!/usr/bin/env python3
"""Rebuild complete Cave Aloe and stalagmite packs from original data and fresh texture."""
import argparse
import hashlib
import json
import runpy
import sys
from pathlib import Path
from PIL import Image
from lol2 import map_props as props
from lol2_source_format import u32
from prepare_museum_key_locks import icon


def prepare(game, texture, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    for path in (game, texture):
        if not path.exists():
            raise ValueError(f'Missing input: {path}')
        if output == path or output in path.parents or path in output.parents:
            raise ValueError(f'Output overlaps input: {path}')
    arc = (game / 'DAT/L1_DC.MIX').read_bytes()
    if hashlib.sha256(arc).hexdigest() != '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345':
        raise ValueError('Unsupported Cave archive')
    tex = texture.read_bytes()
    if hashlib.sha256(tex).hexdigest() != '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97':
        raise ValueError('Unsupported decoded Cave texture')
    maproot=output/'tmp/cave_harvest_map';(maproot/'sprites').mkdir(parents=True,exist_ok=False)
    sec=props.mm.sections(tex);rgb=props.mm.rgb_palette(tex[u32(tex,4):][:768],6)
    review={}
    for descriptor in [122,123,124,125,188,189,190,191]:
     props.build_image(descriptor,tex,sec,rgb,maproot/'sprites',maproot,{})
     review[f'prop_{descriptor}']=f'sprites/prop_{descriptor}_index.png'
     assert (maproot/review[f'prop_{descriptor}']).is_file()
    (maproot/'review.json').write_text(json.dumps({'indexed_materials':review}))
    for pack in ('cave_aloe','cave_stalagmite'):
     out=output/'assets/lol2/generated'/pack
     sys.argv=[str(Path(__file__).with_name('prepare_'+pack+'.py')),'--game',str(game),'--map',str(maproot),'--out',str(out)]
     runpy.run_path(sys.argv[0],run_name='__main__')
     if pack=='cave_stalagmite':
      icon(0,out/'icon.png',game=game)
      # F1EB8 chains124/125; frameflag0x10 dispatches the upper blend half.
      # Native loader binds texture header+0x1c to object4+0x4200; plotter uses+0xc200.
      offset=u32(tex,0x1c)+0x8000
      table=tex[offset:offset+0x8000]
      assert len(table)==0x8000
      Image.frombytes('L',(256,128),table).save(out/'blend_upper.png')
      binding={'source_sha256':hashlib.sha256(tex).hexdigest(),'offset':offset,'size':len(table),
       'table_sha256':hashlib.sha256(table).hexdigest(),'image_sha256':hashlib.sha256((out/'blend_upper.png').read_bytes()).hexdigest(),
       'binding':'verify_crystal_blend.py/.json; original object4+0xc200',
       'adapter':'Current port reference indices are unshaded. This uses source index directly; native shade-row choice is not implemented.'}
      (out/'blend_upper.json').write_text(json.dumps(binding,indent=2)+'\n')
    return {'cave_aloe': 5, 'cave_stalagmite': 8}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'texture', 'output-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    original_argv = sys.argv[:]
    try:
        result = prepare(args.game.resolve(), args.texture.resolve(), args.output_root.resolve())
    except (ValueError, OSError, AssertionError) as error:
        parser.error(str(error) or 'Source assertion failed')
    finally:
        sys.argv = original_argv
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
