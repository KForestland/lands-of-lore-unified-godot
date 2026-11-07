#!/usr/bin/env python3
"""Explicit room-media helpers for clean checkouts: published decoders only (no capstone, no RE checkout on sys.path).

- digest/extract/movie: as audit_monastery_rooms (WOMS entries by Westwood name hash; VQHD frames/size/fps/x/y).
- stage_patch(source, target, record, root): the prepare_monastery_rooms patch stager (4x4 RGBA atlases + mono wav)
  with an explicit res:// root. chunks/decompress select the VQA chunk parser and LCW decoder; the defaults are the
  published ones, and prepare_monastery_rooms passes its own (legacy) decoders so its behaviour is unchanged.
- load_converter(re_root): the companion-RE convert_cave_video_review.convert, loaded by path and pinned.
"""
import hashlib
import importlib.util
import struct
import subprocess
import wave
from PIL import Image
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1, parse_vqa_chunks
from lol2_creature_sprite_format import lcw
from decode_monastery_vectors import decode_vectors

CONVERTER_SHA256 = 'fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d'  # RE 2791eb1 tools/convert_cave_video_review.py


def digest(b):
    return hashlib.sha256(b).hexdigest()


def extract(archive, name):
    row = next(e for e in parse_mix(archive) if e['key'] == ww_hash_v1(name))
    data = archive[row['offset']:][:row['size']]
    return data, dict(row, name=name, sha256=digest(data))


def movie(archive, name):
    data, result = extract(archive, name)
    at = data.index(b'VQHD')
    header = data[at+8:at+8+42]
    frames, width, height = struct.unpack_from('<HHH', header, 4)
    x, y = struct.unpack_from('<HH', header, 18)
    result.update(frames=frames, width=width, height=height, fps=header[12], x=x, y=y)
    assert frames and width and height and result['fps'] == 15
    return result


def load_converter(re_root):
    """Return convert(source, target) from RE_ROOT/tools/convert_cave_video_review.py, or raise ValueError."""
    path = re_root/'tools/convert_cave_video_review.py'
    if not path.is_file() or digest(path.read_bytes()) != CONVERTER_SHA256:
        raise ValueError(f'{path}: missing or not the pinned converter {CONVERTER_SHA256}')
    spec = importlib.util.spec_from_file_location('convert_cave_video_review', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module.convert


def stage_patch(source, target, record, root, chunks=parse_vqa_chunks, decompress=lcw):
    width, height = record['width'], record['height']
    parsed = chunks(source.read_bytes())
    palette = codebook = None
    frames = 0
    atlases = []
    sheet = None
    for tag, payload in parsed:
        if tag != b'VQFR': continue
        parts = dict(chunks(b'FORM'+bytes(4)+b'WVQA'+payload))
        if b'CPL0' in parts: palette = parts[b'CPL0']
        if b'CBFZ' in parts: codebook = decompress(parts[b'CBFZ'])
        if b'CBF0' in parts: codebook = parts[b'CBF0']
        assert not any(k in parts for k in [b'CBPZ',b'CBP0']), 'Partial codebooks not supported here'
        assert palette is not None and codebook is not None
        vectors = decompress(parts[b'VPRZ']) if b'VPRZ' in parts else parts[b'VPTR']
        indices = decode_vectors(vectors,codebook,width,height)
        picture = Image.frombytes('P',(width,height),indices)
        picture.putpalette(bytes((v & 63)*4 for v in palette))
        picture.info['transparency'] = 0
        if frames%16 == 0: sheet = Image.new('RGBA',(width*4,height*4))
        sheet.paste(picture.convert('RGBA'),((frames%4)*width,((frames%16)//4)*height))
        frames += 1
        if frames%16 == 0 or frames == record['frames']:
            png = target.with_name(target.stem+f'_{len(atlases):03d}.png')
            png.parent.mkdir(parents=True,exist_ok=True)
            sheet.save(png)
            atlases.append('res://'+str(png.relative_to(root)))
    assert frames == record['frames']
    audio = target.with_suffix('.wav')
    expected = sum(len(data)*2 for tag,data in parsed if tag == b'SND2')
    if expected:
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(audio)],check=True)
        with wave.open(str(audio)) as decoded:
            assert decoded.getnchannels() == 1 and decoded.getnframes() == expected, 'Audio samples dropped'
    print(target.stem,frames,'source patch frames and audio sample count verified',flush=True)
    return dict(record,atlases=atlases,columns=4,rows=4,audio=('res://'+str(audio.relative_to(root))) if expected else '',video_duration=frames/record['fps'],audio_samples=expected,duration=max(frames/record['fps'],expected/22050.0))
