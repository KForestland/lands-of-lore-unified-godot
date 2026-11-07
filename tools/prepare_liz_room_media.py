#!/usr/bin/env python3
"""Stage the village LIZ room media (docs/liz-room.md) with the existing room decoders.

Reads scripts/lol2/liz_room_source.json (verify_liz_room_sources.py). It writes the following to
assets/lol2/generated/liz_room/, as local original media that is never published:
- LIZ_.ogv background;
- LIZTRAN intro: atlases + wav, as the TAVERN intro;
- the two sound-bank cues as wav: 100:2 = the wax pickup, 2:59 = the first update after entry.
rooms.json is merged by monastery_room_view.gd. Sequences:
- LIZ: the intro (movies[0]);
- LIZ_WAX / LIZ_ENTRY: the audio-only cues.

Explicit inputs (fresh output root; nothing is written until every input and original is checked):
  python3 tools/prepare_liz_room_media.py --game GAME --re-root RE --source scripts/lol2/liz_room_source.json --output-root FRESH
Published helpers only (tools/monastery_media.py, lol2_source_format); the RE checkout supplies only the pinned video
converter. No native audit module is imported. Without arguments the historical repository-root behaviour is unchanged.
"""
import json, struct, subprocess, sys, wave
from pathlib import Path
if __name__ == '__main__' and len(sys.argv) > 1:
    import argparse, shutil
    import monastery_media
    from monastery_media import extract, digest, movie, parse_vqa_chunks
    from lol2_source_format import parse_mix, u32  # u32: the build_game_atlas/audit_hive_rune_rooms re-export
    from PIL import Image
    ROOT = GAME = convert = None  # set by cli()

    def entry(filename, key):  # as prepare_hive_wax.entry
        archive = (GAME/filename).read_bytes()
        row = next(e for e in parse_mix(archive) if e['key'] == key)
        return archive[row['offset']:][:row['size']]

    def stage_intro(source, target, record):  # as prepare_bacatta_rooms.stage_intro, with this module's ROOT
        width,height=record['width'],record['height']
        raw=source.with_suffix('.rgba')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-an','-pix_fmt','rgba','-f','rawvideo',str(raw)],check=True)
        assert raw.stat().st_size==width*height*4*record['frames']
        atlases=[]
        with raw.open('rb') as stream:
            for frame in range(record['frames']):
                if frame%16==0: sheet=Image.new('RGBA',(width*4,height*4))
                image=Image.frombytes('RGBA',(width,height),stream.read(width*height*4))
                sheet.paste(image,((frame%4)*width,((frame%16)//4)*height))
                if frame%16==15 or frame==record['frames']-1:
                    png=target.with_name(target.stem+f'_{len(atlases):03d}.png');sheet.save(png)
                    atlases.append('res://'+str(png.relative_to(ROOT)))
        audio=target.with_suffix('.wav')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(audio)],check=True)
        expected=sum(len(d)*2 for t,d in parse_vqa_chunks(source.read_bytes()) if t==b'SND2')
        with wave.open(str(audio)) as w: assert w.getnframes()==expected
        raw.unlink()
        return dict(record,kind='movie',atlases=atlases,columns=4,rows=4,audio='res://'+str(audio.relative_to(ROOT)),audio_samples=expected,duration=max(record['frames']/15,expected/22050))
else:
    from audit_monastery_rooms import ROOT, GAME, extract, digest, movie
    from prepare_monastery_rooms import convert
    from prepare_bacatta_rooms import stage_intro
    from prepare_hive_wax import entry
    from audit_hive_rune_rooms import u32


def cue(raw, row, out, name):
    audio = raw[u32(row, 0):][:u32(row, 4)]
    rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio); assert len(audio) == packed + 12 and codec == 99
    source = ROOT / 'tmp/liz_room_source' / (name + '.aud'); source.write_bytes(audio); target = out / (name + '.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-ac', '1', '-c:a', 'pcm_s16le', str(target)], check=True)
    with wave.open(str(target)) as w:
        assert w.getframerate() == rate and w.getnframes() * 2 == decoded; samples = w.getnframes()
    return dict(kind='audio_only', audio='res://' + str(target.relative_to(ROOT)), audio_samples=samples, duration=samples / rate, frames=0, fps=15,
                audio_sha256=digest(audio))


# Originals (explicit path): archive/entry pins; the source contract itself carries the cue sha256 values.
SOURCE_SHA256 = 'c941a0066dbf40753e7d4bab961780426eb28910ff27cdcf635e4ef0b00cecf5'  # scripts/lol2/liz_room_source.json
ORIGINALS = {'DAT/LIZ.MIX': '0b81a4fb6ec55ca2c4dc88ff2ec7f89c8012d76b98375c33022c56f83c653c3d',
             'LOCALLNG.MIX': '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'}
ENTRIES = {'WOMS\\LIZ\\LIZ_.VQA': '9bc7243cd3a62d49fa296d8727348c868de8351bfc18206d074aea45e379913f',
           'WOMS\\LIZ\\LIZTRAN.VQA': '28be770c9d70fa80917a489a2d15f5d00f95320c497c8a618a0b90b103080708'}
SOUND_BANK = (1570429112, 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')  # LOCALLNG.MIX entry key, sha256


def main(source_path=None):
    src = json.loads((source_path or ROOT / 'scripts/lol2/liz_room_source.json').read_text())
    archive = (GAME / 'DAT/LIZ.MIX').read_bytes()
    out = ROOT / 'assets/lol2/generated/liz_room'; cache = ROOT / 'tmp/liz_room_source'
    out.mkdir(parents=True, exist_ok=True); cache.mkdir(parents=True, exist_ok=True)
    payload, rec = extract(archive, src['background']); bg = cache / 'LIZ_.VQA'; bg.write_bytes(payload)
    convert(bg, out / 'LIZ_.ogv')
    background = dict(movie(archive, src['background']), path='res://' + str((out / 'LIZ_.ogv').relative_to(ROOT)))
    payload, rec = extract(archive, src['intro']['movie']); intro = cache / 'LIZTRAN.VQA'; intro.write_bytes(payload)
    record = movie(archive, src['intro']['movie']); assert record['frames'] == 160
    staged_intro = stage_intro(intro, out / 'LIZTRAN.ogv', record)
    raw = entry('LOCALLNG.MIX', 1570429112)
    rows = {k: raw[u32(raw, 0x25c) + v['request'] * 60:][:60] for k, v in src['cues'].items()}
    wax = cue(raw, rows['100:2'], out, '0100224e'); enter = cue(raw, rows['2:59'], out, '0120224e')
    assert wax['audio_sha256'] == src['cues']['100:2']['sha256'] and enter['audio_sha256'] == src['cues']['2:59']['sha256']
    manifest = dict(version=1, canvas=[640, 400], rooms={'LIZ': dict(background=background, movies=[staged_intro],
                                                                     sequences={'LIZ_WAX': [wax], 'LIZ_ENTRY': [enter]})})
    (out / 'rooms.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS LIZ media: background %d frames, intro %d frames / %d samples, cues %d + %d samples' % (
        background['frames'], staged_intro['frames'], staged_intro['audio_samples'], wax['audio_samples'], enter['audio_samples']))


def cli():
    global ROOT, GAME, convert
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 're-root', 'source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    codecs = subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
    for codec in ['libtheora', 'libvorbis', 'vqavideo', 'pcm_s16le', 'rawvideo', 'adpcm_ima_ws']:
        if codec not in codecs: p.error('ffmpeg lacks ' + codec)
    try:
        converter = monastery_media.load_converter(a.re_root)
    except ValueError as error:
        p.error(str(error))
    if not a.source.is_file(): p.error('Missing input: ' + str(a.source))
    if digest(a.source.read_bytes()) != SOURCE_SHA256: p.error(f'{a.source}: not the pinned LIZ room source ({SOURCE_SHA256})')
    src = json.loads(a.source.read_text())
    blobs = {}
    for rel, want in ORIGINALS.items():
        if not (a.game/rel).is_file(): p.error('Missing original ' + str(a.game/rel))
        blobs[rel] = (a.game/rel).read_bytes()
        if digest(blobs[rel]) != want: p.error(f'{a.game/rel}: not the pinned original')
    try:
        assert (src['background'], src['intro']['movie']) == tuple(ENTRIES), 'source names'
        for name, want in ENTRIES.items():
            assert extract(blobs['DAT/LIZ.MIX'], name)[1]['sha256'] == want, name
        assert movie(blobs['DAT/LIZ.MIX'], src['intro']['movie'])['frames'] == 160, 'intro frames'
        row = next(e for e in parse_mix(blobs['LOCALLNG.MIX']) if e['key'] == SOUND_BANK[0])
        raw = blobs['LOCALLNG.MIX'][row['offset']:][:row['size']]; assert digest(raw) == SOUND_BANK[1], 'sound bank'
        for key in ['100:2', '2:59']:
            cue = src['cues'][key]; r = raw[u32(raw, 0x25c) + cue['request'] * 60:][:60]; audio = raw[u32(r, 0):][:u32(r, 4)]
            assert digest(audio) == cue['sha256'] and len(audio) == cue['bytes'] and struct.unpack_from('<HIIBB', audio)[4] == 99, key
    except (AssertionError, KeyError, StopIteration, ValueError) as error:
        p.error('Originals do not match the LIZ room source: ' + str(error))
    convert = converter
    GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main(a.source.resolve())


if __name__ == '__main__':
    if len(sys.argv) > 1: cli()
    else: main()
