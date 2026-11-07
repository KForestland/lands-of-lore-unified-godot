#!/usr/bin/env python3
"""Stage the chief's-hut CHUT branch media that docs/jungle-chut-room.md's unhosted branches need
(AI_COMMS CHUT_BRANCHES_DECODE_20261027.md): Anyar's lines (29,365,6) (thrown out), (29,366,6)/(29,367,6) (the refusal),
her death (29,998,6), the two CHUT.SHP stone piles and the sound-bank cues 100:17 (after the death) and 2:30 (the first
stone). Explicit inputs only; nothing is written until every original is checked against its pin:

  python3 tools/prepare_chut_branch_media.py --game GAME --re-root RE --output-root FRESH

Writes assets/lol2/generated/chut_branches/{clips.json, *.png, *.wav} under the output root: local original media,
never published. Published helpers only (tools/monastery_media.py, lol2_source_format, lol2_movie_format,
lol2_creature_sprite_format); the RE checkout supplies only the pinned video converter (checked, unused here).
"""
import argparse, json, shutil, struct, subprocess, sys, wave
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import monastery_media
from monastery_media import digest, extract, movie, stage_patch, parse_vqa_chunks
from lol2_source_format import parse_mix, u32
from lol2_creature_sprite_format import lcw
from PIL import Image

ORIGINALS = {'DAT/CHUT.MIX': 'd623157008700d95e3e09cd7462c7d7032a06bfdff48b15ece11fc7c79dc4be7',
             'LOCALLNG.MIX': '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'}
CLIPS = {'29:365:6': ('WOMS\\CHUT\\2936506E.VQA', 'ee6c64e6f411167c92c8d07cfb63f99c44fdb4d43e404559a2f78127eedd41b9', 103),
         '29:366:6': ('WOMS\\CHUT\\2936606E.VQA', 'd2e8186ae007cb5fe6e1b5d26ac3fcdd0b30047d0bfbab11dec788f57e818108', 59),
         '29:367:6': ('WOMS\\CHUT\\2936706E.VQA', '05dc7e46aa49439b54062b8a4c6e93a595b84159e07bada40fb337ef0184ea17', 73),
         '29:998:6': ('WOMS\\CHUT\\2999806E.VQA', '45510a012bbc41767559f17a4bfc6cc5c6031f6b61bce8bba787ac14bcf7ce10', 63)}
SHAPE = ('WOMS\\CHUT\\CHUT.SHP', '449f34849b512ae49c666e3a447b3e2fb3de2adb0da91fd43cc69b8b3919e529')
BACKGROUND = ('WOMS\\CHUT\\CHUT_.VQA', '1d735f260ad403c4c2fae2649d28fab8c539c4f17f37ce82571764e292b92cdc')  # palette source
SOUND_BANK = (1570429112, 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')
# speaker:line:24 -> (bias, request, sha256, bytes); speaker 100 bias 268 and speaker 2 bias 141 (tools/prepare_hive_rune_speech.py)
CUES = {'100:17:24': (268, 268, 'ac6683f7e3e8eb059cdf32b0d379d6d4c4e42fe82e0cdde80a22375d7c504248', 29172),
        '2:30:24': (141, 307, 'e62b0e82fcbbdc94539cd58f1cad6d73c2aa738db398237d9814669ae0a84f3a', 6612)}
ROOT = GAME = None


def rel(path): return 'res://' + str(path.relative_to(ROOT))


def shape(shp, i):  # as prepare_magic_shop.shape
    offset = struct.unpack_from('<I', shp, 2 + 4 * i)[0] + 2
    flags, h, w, h2, size, unc = struct.unpack_from('<HBHBHH', shp, offset)
    assert flags in (0, 2) and h == h2 and offset + size <= len(shp)
    raw = shp[offset + 10:offset + size]
    raw = raw if flags & 2 else lcw(raw)
    assert len(raw) == unc
    pixels = bytearray(); pos = 0
    while pos < len(raw):
        value = raw[pos]; pos += 1
        if value: pixels.append(value)
        else:
            assert pos < len(raw); pixels.extend(bytes(raw[pos])); pos += 1
    assert len(pixels) == w * h
    return w, h, bytes(pixels)


def palette_of(vqa):
    for tag, payload in parse_vqa_chunks(vqa):
        if tag == b'VQFR':
            parts = dict(parse_vqa_chunks(b'FORM' + bytes(4) + b'WVQA' + payload))
            if b'CPL0' in parts: return parts[b'CPL0']
    raise AssertionError('no palette')


def stage_cue(bank, key, target):
    bias, request, sha, size = CUES[key]
    line = int(key.split(':')[1])
    assert struct.unpack_from('<H', bank, len(bank) - 808 + (line + bias) * 2)[0] == request, key
    row = bank[u32(bank, 0x25c) + request * 60:][:60]; audio = bank[u32(row, 0):][:u32(row, 4)]
    assert digest(audio) == sha and len(audio) == size, key
    rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio); assert len(audio) == packed + 12 and codec == 99
    source = target.with_suffix('.aud'); source.write_bytes(audio)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-ac', '1', '-c:a', 'pcm_s16le', str(target)], check=True)
    with wave.open(str(target)) as w:
        assert w.getframerate() == rate and w.getnframes() * 2 == decoded, key
        samples = w.getnframes()
    source.unlink()
    return dict(kind='audio_only', frames=0, fps=15, audio=rel(target), audio_samples=samples, rate=rate, duration=samples / rate,
                request=request, trailer_index=line + bias, source_name=row[16:].split(b'\0')[0].decode(), audio_sha256=sha)


def main():
    archive = (GAME / 'DAT/CHUT.MIX').read_bytes()
    out = ROOT / 'assets/lol2/generated/chut_branches'; cache = ROOT / 'tmp/chut_branches_source'
    out.mkdir(parents=True); cache.mkdir(parents=True)
    manifest = dict(version=1, canvas=[640, 400], clips={}, sprites={}, cues={})
    for key, (name, sha, frames) in CLIPS.items():
        payload, binding = extract(archive, name); assert binding['sha256'] == sha, name
        record = movie(archive, name); assert record['frames'] == frames, name
        path = cache / name.split('\\')[-1]; path.write_bytes(payload)
        manifest['clips'][key] = dict(stage_patch(path, out / (path.stem + '.ogv'), dict(record, kind='movie'), ROOT), line=int(key.split(':')[1]))
    shp, binding = extract(archive, SHAPE[0]); assert binding['sha256'] == SHAPE[1]
    background, binding = extract(archive, BACKGROUND[0]); assert binding['sha256'] == BACKGROUND[1]
    rgb = bytes((v & 63) * 4 for v in palette_of(background))
    assert struct.unpack_from('<H', shp)[0] == 2
    for i in range(2):
        w, h, pixels = shape(shp, i)
        image = Image.frombytes('P', (w, h), pixels); image.putpalette(rgb); image.info['transparency'] = 0
        png = out / f'chut_shape_{i}.png'; image.convert('RGBA').save(png)
        manifest['sprites'][str(i)] = dict(path=rel(png), width=w, height=h, indices_sha256=digest(pixels))
    locallng = (GAME / 'LOCALLNG.MIX').read_bytes()
    row = next(e for e in parse_mix(locallng) if e['key'] == SOUND_BANK[0]); bank = locallng[row['offset']:][:row['size']]
    assert digest(bank) == SOUND_BANK[1]
    for key in CUES: manifest['cues'][key] = stage_cue(bank, key, out / ('cue_' + key.replace(':', '_') + '.wav'))
    (out / 'clips.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS CHUT branch media:', {k: (v['frames'], v['audio_samples']) for k, v in manifest['clips'].items()}, 'sprites', {k: (v['width'], v['height']) for k, v in manifest['sprites'].items()}, 'cues', {k: v['audio_samples'] for k, v in manifest['cues'].items()})


def cli():
    global ROOT, GAME
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 're-root', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    try: monastery_media.load_converter(a.re_root)
    except ValueError as error: p.error(str(error))
    for rel_path, want in ORIGINALS.items():
        if not (a.game / rel_path).is_file(): p.error('Missing original ' + str(a.game / rel_path))
        if digest((a.game / rel_path).read_bytes()) != want: p.error(f'{a.game / rel_path}: not the pinned original')
    GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main()


if __name__ == '__main__': cli()
