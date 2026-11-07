#!/usr/bin/env python3
"""Stage the Thieves' Den media (docs/thieves-den.md) from the pinned originals, as local original media that is
never published. Explicit inputs only (a fresh output root; nothing is written until every input and original is
checked):

  python3 tools/prepare_thieves_den_media.py --game GAME --re-root RE --source scripts/lol2/thieves_den_source.json \\
      --output-root FRESH

Writes assets/lol2/generated/thieves_den/ under the output root:
- TEXT_/TCEL_/TDOOR_/TINT_ backgrounds as .ogv (the pinned RE video converter, as every hosted room);
- CELLAR (117 frames) and TINTTRAN (271 frames): full-screen partial-codebook VQA v2 clips decoded by
  tools/vqa_v2_decode.py into 4x4 RGBA atlases + mono wav (the LIZTRAN/TAVERN intro shape);
- every talking-head request of TDOOR and TINT (speaker 31 VQA patches: atlases + wav through
  tools/monastery_media.stage_patch), Mauri's idle (31,999,6) included;
- every AUD request (Luther's door answers, his opener (1,401,10)) and the 22 Luther replies after Mauri's
  0x80-flagged lines (19 by their own name hash, 3 under a hash a requested Mauri line also matches: see the source
  JSON's ambiguous_replies and docs/thieves-den.md);
- the three sound-bank cues 2:26, 2:29 and 2:32 (speaker-2 bias 141, as the LIZ/Rashar cues);
- THFSHAPE.SHP frames 0 (Poison Paint) and 1 (Skull Key) with the TINT background palette.
rooms.json is merged into the shared room view by thieves_den_rooms.gd.
Published helpers only (tools/monastery_media.py, lol2_source_format, lol2_movie_format, vqa_v2_decode); the RE checkout
supplies only the pinned video converter.
"""
import argparse, json, shutil, struct, subprocess, sys, wave
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import monastery_media
from monastery_media import digest, extract, movie, stage_patch, parse_vqa_chunks
from lol2_source_format import parse_mix, u32
from lol2_movie_format import ww_hash_v1
from lol2_creature_sprite_format import lcw
import vqa_v2_decode
from PIL import Image

SOURCE_SHA256 = '9bc782058f0b3e64380a8788b91f8ded338f5e303dc43c07da3270a98071744e'  # scripts/lol2/thieves_den_source.json
SOURCE_PIN = 'scripts/lol2/thieves_den_source.json'
ORIGINALS = {'DAT/TEXT.MIX': 'a2ba8ba8e18c5ebeaea51ec8e8c36eae865f839341b16b7597ece01272f51302',
             'DAT/TCEL.MIX': '27614f82095f3319344c8e4dcccdfe5be7ceeb1d2aa0f6b0dd06ae4c04b4be5d',
             'DAT/TDOOR.MIX': '36672526f1295e3ed86f01eee167f883e76d4d12ed976262c1c5048ed75f23f0',
             'DAT/TINT.MIX': '838c78763aabeb13c48bcfb4ec2804423a333eba535f9c0371c884af7a89c37f',
             'LOCALLNG.MIX': '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'}
SOUND_BANK = (1570429112, 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')
ROOMS = ['TEXT', 'TCEL', 'TDOOR', 'TINT']
ROOT = GAME = convert = None


def rel(path): return 'res://' + str(path.relative_to(ROOT))


def stage_fullscreen(source, target, record):
    """Full-screen clip (CELLAR/TINTTRAN): partial-codebook VQA v2 through the published decoder, else FFmpeg."""
    width, height = record['width'], record['height']
    raw = source.with_suffix('.rgba')
    if not vqa_v2_decode.rgba_raw(source, raw):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-an', '-pix_fmt', 'rgba', '-f', 'rawvideo', str(raw)], check=True)
    assert raw.stat().st_size == width * height * 4 * record['frames'], 'frame count'
    atlases = []
    with raw.open('rb') as stream:
        for frame in range(record['frames']):
            if frame % 16 == 0: sheet = Image.new('RGBA', (width * 4, height * 4))
            sheet.paste(Image.frombytes('RGBA', (width, height), stream.read(width * height * 4)), ((frame % 4) * width, ((frame % 16) // 4) * height))
            if frame % 16 == 15 or frame == record['frames'] - 1:
                png = target.with_name(target.stem + f'_{len(atlases):03d}.png'); sheet.save(png); atlases.append(rel(png))
    raw.unlink()
    expected = sum(len(d) * 2 for t, d in parse_vqa_chunks(source.read_bytes()) if t == b'SND2')
    audio = ''
    if expected:
        wav_path = target.with_suffix('.wav')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-vn', '-ac', '1', '-c:a', 'pcm_s16le', str(wav_path)], check=True)
        with wave.open(str(wav_path)) as w: assert w.getnframes() == expected and w.getnchannels() == 1, 'audio samples'
        audio = rel(wav_path)
    print(target.stem, record['frames'], 'full-screen frames and', expected, 'audio samples verified', flush=True)
    return dict(record, kind='movie', atlases=atlases, columns=4, rows=4, audio=audio, audio_samples=expected, x=0, y=0,
                video_duration=record['frames'] / record['fps'], duration=max(record['frames'] / record['fps'], expected / 22050))


def stage_aud(payload, binding, target):
    rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', payload); assert len(payload) == packed + 12 and codec == 99
    source = target.with_suffix('.aud'); source.write_bytes(payload)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-ac', '1', '-c:a', 'pcm_s16le', str(target)], check=True)
    with wave.open(str(target)) as w:
        assert w.getframerate() == rate and w.getnframes() * 2 == decoded, 'AUD samples'
        samples = w.getnframes()
    source.unlink()
    return dict(binding, frames=0, audio=rel(target), audio_samples=samples, rate=rate, duration=samples / rate)


def stage_cue(bank, cue, target):
    row = bank[u32(bank, 0x25c) + cue['request'] * 60:][:60]; audio = bank[u32(row, 0):][:u32(row, 4)]
    assert digest(audio) == cue['sha256'] and len(audio) == cue['bytes'], 'cue'
    return dict(stage_aud(audio, dict(source_name=cue['source_name'], request=cue['request'], trailer_index=cue['trailer_index'], audio_sha256=cue['sha256']), target), kind='audio_only')


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


def main(src):
    out = ROOT / 'assets/lol2/generated/thieves_den'; cache = ROOT / 'tmp/thieves_den_source'
    out.mkdir(parents=True); cache.mkdir(parents=True)
    manifest = dict(version=1, canvas=[640, 400], rooms={}, cues={}, source_sha256=src['_sha256'])
    locallng = (GAME / 'LOCALLNG.MIX').read_bytes()
    bank_row = next(e for e in parse_mix(locallng) if e['key'] == SOUND_BANK[0]); bank = locallng[bank_row['offset']:][:bank_row['size']]
    for room in ROOMS:
        r = src['rooms'][room]; archive = (GAME / r['archive']).read_bytes()
        fixed = r['fixed_entries']
        payload, rec = extract(archive, fixed[f'{room}_.VQA']['name']); assert rec['sha256'] == fixed[f'{room}_.VQA']['sha256']
        bg = cache / f'{room}_.VQA'; bg.write_bytes(payload); convert(bg, out / f'{room}_.ogv')
        background = dict(movie(archive, rec['name']), path=rel(out / f'{room}_.ogv'))
        staged = dict(background=background, movies=[], clips={}, replies={}, sprites={})
        for name in ('CELLAR.VQA', 'TINTTRAN.VQA'):
            if name not in fixed: continue
            payload, rec = extract(archive, fixed[name]['name']); assert rec['sha256'] == fixed[name]['sha256']
            path = cache / name; path.write_bytes(payload)
            staged['movies'].append(stage_fullscreen(path, out / (Path(name).stem + '.ogv'), movie(archive, rec['name'])))
        for key, req in r['requests'].items():
            if 'sound_bank' in req:
                if key not in manifest['cues']: manifest['cues'][key] = stage_cue(bank, req['sound_bank'], out / ('cue_' + key.replace(':', '_') + '.wav'))
                continue
            if 'vqa' in req:
                rec = movie(archive, req['vqa']['name']); assert rec['sha256'] == req['vqa']['sha256']
                assert rec['codebook_parts' if 'codebook_parts' in rec else 'frames'] is not None
                payload, _ = extract(archive, rec['name']); path = cache / rec['name'].split('\\')[-1]; path.write_bytes(payload)
                # Full-screen requests (TDOOR 475/476: 640x400 VPTZ frames) take the CELLAR/TINTTRAN path; patches take
                # the monastery stager (VPRZ/VPTR vectors, no partial codebooks).
                if rec['width'] == 640 and rec['height'] == 400: clip = stage_fullscreen(path, out / (path.stem + '.ogv'), rec)
                else: clip = stage_patch(path, out / (path.stem + '.ogv'), rec, ROOT)
                if req['kind'] == 'idle': staged['idle'] = clip
                staged['clips'][key] = clip
            elif 'aud' in req:
                payload, binding = extract(archive, req['aud']['name']); assert binding['sha256'] == req['aud']['sha256']
                staged['clips'][key] = stage_aud(payload, binding, out / (req['aud']['name'].split('\\')[-1][:-4] + '.wav'))
        for line, reply in list(r['luther_replies'].items()) + [(l, dict(name=a['name'], sha256=r['requests'][a['also']]['aud']['sha256'])) for l, a in r['ambiguous_replies'].items()]:
            payload, binding = extract(archive, reply['name']); assert binding['sha256'] == reply['sha256'], reply['name']
            staged['replies'][line] = stage_aud(payload, binding, out / (f'reply_{room}_{int(line):03d}.wav'))
        if 'THFSHAPE.SHP' in fixed:
            shp, binding = extract(archive, fixed['THFSHAPE.SHP']['name']); assert binding['sha256'] == fixed['THFSHAPE.SHP']['sha256']
            assert struct.unpack_from('<H', shp)[0] >= 2, 'THFSHAPE frames'
            rgb = bytes((v & 63) * 4 for v in palette_of(archive[next(e for e in parse_mix(archive) if e['key'] == fixed[f'{room}_.VQA']['key'])['offset']:]))
            for i in range(2):
                w, h, pixels = shape(shp, i)
                image = Image.frombytes('P', (w, h), pixels); image.putpalette(rgb); image.info['transparency'] = 0
                png = out / f'thfshape_{i}.png'; image.convert('RGBA').save(png)
                staged['sprites'][str(i)] = dict(path=rel(png), width=w, height=h, indices_sha256=digest(pixels))
        manifest['rooms'][room] = staged
    (out / 'rooms.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS thieves den media:', {room: (len(m['clips']), len(m['replies']), len(m['movies'])) for room, m in manifest['rooms'].items()}, 'cues', len(manifest['cues']))


def cli():
    global ROOT, GAME, convert
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 're-root', 'source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    codecs = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], capture_output=True, text=True).stdout + subprocess.run(['ffmpeg', '-hide_banner', '-decoders'], capture_output=True, text=True).stdout
    for codec in ['libtheora', 'libvorbis', 'vqavideo', 'pcm_s16le', 'rawvideo', 'adpcm_ima_ws']:
        if codec not in codecs: p.error('ffmpeg lacks ' + codec)
    try: converter = monastery_media.load_converter(a.re_root)
    except ValueError as error: p.error(str(error))
    if not a.source.is_file(): p.error('Missing input: ' + str(a.source))
    source_sha = digest(a.source.read_bytes())
    if SOURCE_SHA256 is not None and source_sha != SOURCE_SHA256: p.error(f'{a.source}: not the pinned Thieves\' Den source ({SOURCE_SHA256})')
    src = json.loads(a.source.read_text()); src['_sha256'] = source_sha
    for rel_path, want in ORIGINALS.items():
        if not (a.game / rel_path).is_file(): p.error('Missing original ' + str(a.game / rel_path))
        if digest((a.game / rel_path).read_bytes()) != want: p.error(f'{a.game / rel_path}: not the pinned original')
    try:
        for room in ROOMS:
            r = src['rooms'][room]; archive = (a.game / r['archive']).read_bytes(); assert digest(archive) == r['archive_sha256'], room
            for rec in r['fixed_entries'].values(): assert extract(archive, rec['name'])[1]['sha256'] == rec['sha256'], rec['name']
            for req in r['requests'].values():
                for kind in ('vqa', 'aud'):
                    if kind in req: assert extract(archive, req[kind]['name'])[1]['sha256'] == req[kind]['sha256'], req[kind]['name']
        locallng = (a.game / 'LOCALLNG.MIX').read_bytes()
        row = next(e for e in parse_mix(locallng) if e['key'] == SOUND_BANK[0]); assert digest(locallng[row['offset']:][:row['size']]) == SOUND_BANK[1], 'sound bank'
    except (AssertionError, KeyError, StopIteration, ValueError) as error:
        p.error('Originals do not match the Thieves\' Den source: ' + str(error))
    convert = converter; GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main(src)


if __name__ == '__main__': cli()
