#!/usr/bin/env python3
"""Stage Museum control96 media from originals, fresh assembly and published contract.

No native replay or source-contract writes. Later decoder failures may leave
partial fresh output. Presentation adapters match the existing runtime pack.
"""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from prepare_jungle_exit_movies import decode
from lol2_creature_sprite_format import sections
from lol2_rotation_table import EXE_SHA256

SOURCE_SHA = 'deec4f2b42b8adb4978f057f974644b723ac14a6b1b48338b9b61a1454471ec1'
TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game','assembly','texture','source','output-root']:
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    if args.output_root.exists():
        parser.error('--output-root must be fresh')
    output = args.output_root.resolve()
    roots = [args.game, args.assembly.parent, args.texture.parent, args.source.parent, Path(__file__).parent]
    for root in roots:
        root = root.resolve()
        if output == root or output in root.parents or root in output.parents:
            parser.error('Output overlaps an input directory')
    require(sha(args.source.read_bytes()) == SOURCE_SHA, 'Unsupported control96 contract')
    contract = json.loads(args.source.read_text())
    archive = (args.game/contract['source']['file']).read_bytes()
    require(sha(archive) == contract['source']['sha256'], 'Unsupported Museum archive')
    assembly = json.loads(args.assembly.read_text())
    require(assembly['area_id'] == 'L3_DH' and assembly['placement_kind'] == 'static_assembly', 'Wrong assembly area or kind')
    require(assembly['source']['sha256'] == contract['source']['sha256'], 'Wrong assembly source')
    placements = [p for p in assembly['placements'] if p['source_index'] in [96,179]]
    require(placements == contract['placements'], 'Assembly placement mismatch')
    for p in placements:
        raw = bytes.fromhex(p['placement_hex'])
        require(archive[p['placement_offset']:p['placement_offset']+len(raw)] == raw, 'Original placement mismatch')
    template = bytes.fromhex(assembly['source_templates'][50]['raw_hex'])
    require(struct.unpack_from('<h',template,0x24)[0] == 837, 'Wrong movie descriptor')
    texture = args.texture.read_bytes()
    require(sha(texture) == TEXTURE_SHA, 'Unsupported Museum texture')
    sec = sections(texture)
    descriptor = struct.unpack_from('<6H11I',texture,sec[2]+837*56)
    payload = texture[sec[3]+descriptor[7]:sec[3]+descriptor[7]+descriptor[12]]
    require(payload.hex() == contract['binding']['descriptor_hex'], 'Movie descriptor mismatch')
    exe = (args.game/'LOLG.DAT').read_bytes()
    require(sha(exe) == EXE_SHA256, 'Unsupported executable')
    require(sha(exe[0x5d904+0x37000:0x5d934+0x37000]) == contract['binding']['code_sha256'], 'Receiver code mismatch')
    movie = lookup_movie(args.game,'L3_DH','SG17.VQA')
    require({k:v for k,v in movie.items() if k not in ['blob','candidates']} == contract['movie'], 'Movie binding mismatch')
    faces = [dict(f,texture='material_%d.png'%f['resource_id']) for f in assembly['faces'] if f['source_index'] in [96,179]]
    require(faces == contract['faces'], 'Assembly face mismatch')
    root = Path(assembly['materials_root']).resolve()
    for face in faces:
        p = (root/face['material']).resolve()
        require(root in p.parents and p.is_file(), 'Missing or invalid material image')
    out = args.output_root/'assets/lol2/generated/museum_control96'
    cache = args.output_root/'tmp/museum_control96'
    out.mkdir(parents=True);cache.mkdir(parents=True)
    movie_path = cache/'sg17.vqa';movie_path.write_bytes(movie['blob'])
    frames = decode(movie_path,cache/'frames',68,(240,320));files=[]
    for i,path in enumerate(frames):
        im = Image.open(path).convert('RGBA').transpose(Image.Transpose.ROTATE_270)
        im.putdata([(r,g,b,0 if (r,g,b)==(0,251,251) else 255) for r,g,b,_ in im.getdata()])
        dest=out/f'frame_{i:03d}.png';im.save(dest);files.append(dest.name)
    for face in faces:
        dest=out/face['texture']
        if not dest.exists():shutil.copyfile(root/face['material'],dest)
    result={k:contract[k] for k in ['version','source','placements','faces','handlers','groups','movie']}
    result['frames']=files
    result.update({k:contract[k] for k in ['fps','ranges','binding','adapters']})
    (out/'source.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Prepared control96: 68 movie frames and source assembly faces')


if __name__=='__main__':
    main()
