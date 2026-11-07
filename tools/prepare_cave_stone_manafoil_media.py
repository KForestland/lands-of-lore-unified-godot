#!/usr/bin/env python3
"""Prepare existing Cave Stone/Manafoil images from explicit originals and fresh materials."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image
from lol2 import map_props as props
from lol2_source_format import u32
from prepare_museum_key_locks import icon


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare(game, m, source, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    for path in (game, m, source):
        if not path.exists():
            raise ValueError(f'Missing input: {path}')
        if output == path or output in path.parents or path in output.parents:
            raise ValueError(f'Output overlaps input: {path}')
    if sha(source.read_bytes()) != '9fa7c7af193a78062109d6919d435d051aefb310a1c4832b86a603ff0f357bc0':
        raise ValueError('Unsupported source contract')
    if sha((m / 'material_0086/mip_0_palette.png').read_bytes()) != '7b91a25d45ca53d5703f9ca930e38e267a2b2360fb2beae69194e8032cf2a8b1':
        raise ValueError('Unsupported material86 image')
    tex=(m/'texture.bin').read_bytes();assert sha(tex)=='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
    contract=json.loads(source.read_text())
    out=output/'assets/lol2/generated/cave_stone_manafoil';out.mkdir(parents=True,exist_ok=False)
    scratch=output/'tmp/cave_stone_manafoil';(scratch/'sprites').mkdir(parents=True)
    dac=tex[u32(tex,4):u32(tex,4)+768];rgb=props.mm.rgb_palette(dac,6)
    image=props.build_image(477,tex,props.mm.sections(tex),rgb,scratch/'sprites',scratch,{})
    shutil.copy2(scratch/image['image'],out/'stone.png')
    shutil.copy2(scratch/'sprites/prop_477_index.png',out/'stone_index.png')
    for kind in ('stone','foil'):icon(contract[kind]['item']['definition'],out/(kind+'_icon.png'),game=game)
    pal=[tuple(x*4 for x in dac[i*3:i*3+3]) for i in range(256)]
    foil=Image.open(out/'foil_icon.png').convert('RGBA');indexed=Image.new('L',foil.size,0)
    for y in range(foil.height):
     for x in range(foil.width):
      red,green,blue,alpha=foil.getpixel((x,y))
      if alpha<128:continue
      indexed.putpixel((x,y),min(range(2,256),key=lambda i:(pal[i][0]-red)**2+(pal[i][1]-green)**2+(pal[i][2]-blue)**2))
    indexed.save(out/'foil_index.png')
    shutil.copy2(m/'material_0086/mip_0_palette.png',out/'m0086.png')
    return {'runtime_files': 6}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'materials', 'source', 'output-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = prepare(args.game.resolve(), args.materials.resolve(), args.source.resolve(),
                         args.output_root.resolve())
    except (ValueError, OSError, AssertionError) as error:
        parser.error(str(error) or 'Input/decoder assertion failed')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
