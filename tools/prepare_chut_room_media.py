#!/usr/bin/env python3
"""Stage the chief's-hut room CHUT media (docs/jungle-chut-room.md) with the existing room decoders.

Reads scripts/lol2/chut_room_source.json (verify_chut_room_sources.py) and writes assets/lol2/generated/chut_room/ under
--output-root, as local original media that is never published:
- CHUT_.ogv background (30 frames, looped as the other rooms);
- HUT-APR intro (setup load_room("hut-apr",1,1)): 640x400 atlases + wav, as LIZTRAN/TAVERN;
- idle patches 29/999/06 (Kelsrick and the chief) and 29/995/06 (the chief alone, Kelsrick dead);
- first-visit lines29/350..364/06 and Kelsrick-dead lines29/375..379/06: patch atlases + wav.
rooms.json is merged by monastery_room_view.gd. Sequences: CHUT (the intro), CHUT_FIRST (the fifteen lines), CHUT_DEAD (the five death-branch lines).

  python3 tools/prepare_chut_room_media.py --game GAME --re-root RE --source scripts/lol2/chut_room_source.json --output-root FRESH
Published helpers only (tools/monastery_media.py); the RE checkout supplies only the pinned video converter.
"""
import argparse, json, shutil, struct, subprocess, sys, wave
from pathlib import Path
import monastery_media
from monastery_media import extract, digest, movie, parse_vqa_chunks
from PIL import Image

ROOT = GAME = convert = None


def stage_intro(source, target, record):  # as prepare_liz_room_media.stage_intro
    width, height = record['width'], record['height']
    raw = source.with_suffix('.rgba')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-an', '-pix_fmt', 'rgba', '-f', 'rawvideo', str(raw)], check=True)
    assert raw.stat().st_size == width * height * 4 * record['frames']
    atlases = []
    with raw.open('rb') as stream:
        for frame in range(record['frames']):
            if frame % 16 == 0: sheet = Image.new('RGBA', (width * 4, height * 4))
            image = Image.frombytes('RGBA', (width, height), stream.read(width * height * 4))
            sheet.paste(image, ((frame % 4) * width, ((frame % 16) // 4) * height))
            if frame % 16 == 15 or frame == record['frames'] - 1:
                png = target.with_name(target.stem + f'_{len(atlases):03d}.png'); sheet.save(png)
                atlases.append('res://' + str(png.relative_to(ROOT)))
    audio = target.with_suffix('.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-vn', '-ac', '1', '-c:a', 'pcm_s16le', str(audio)], check=True)
    expected = sum(len(d) * 2 for t, d in parse_vqa_chunks(source.read_bytes()) if t == b'SND2')
    with wave.open(str(audio)) as w: assert w.getnframes() == expected
    raw.unlink()
    return dict(record, kind='movie', atlases=atlases, columns=4, rows=4, audio='res://' + str(audio.relative_to(ROOT)),
                audio_samples=expected, duration=max(record['frames'] / 15, expected / 22050))


def main(src):
    archive = (GAME / 'DAT/CHUT.MIX').read_bytes()
    out = ROOT / 'assets/lol2/generated/chut_room'; cache = ROOT / 'tmp/chut_room_source'
    out.mkdir(parents=True, exist_ok=True); cache.mkdir(parents=True, exist_ok=True)

    def cached(name):
        payload, record = extract(archive, name); path = cache / name.split('\\')[-1]; path.write_bytes(payload)
        return path, dict(movie(archive, name))

    path, record = cached(src['media']['background']['name'])
    convert(path, out / 'CHUT_.ogv')
    background = dict(record, path='res://' + str((out / 'CHUT_.ogv').relative_to(ROOT)))
    path, record = cached(src['media']['intro']['name'])
    intro = stage_intro(path, out / 'HUT-APR.ogv', record)
    staged = {}
    for key in ['idle', 'idle_dead']:
        path, record = cached(src['media'][key]['name'])
        staged[key] = monastery_media.stage_patch(path, out / (path.stem + '.ogv'), dict(record, kind='movie'), ROOT)
    lines = []
    for clip in src['clips']:
        path, record = cached(clip['name']); assert record['sha256'] == clip['sha256']
        lines.append(dict(monastery_media.stage_patch(path, out / (path.stem + '.ogv'), dict(record, kind='movie'), ROOT), line=clip['line']))
    room = dict(background=background, movies=[intro], idle=staged['idle'], idle_dead=staged['idle_dead'],
                sequences={'CHUT': [intro], 'CHUT_FIRST': [c for c in lines if c['line'] in src['first_visit']['lines']], 'CHUT_DEAD': [c for c in lines if c['line'] in src['dead_visit']['lines']]})
    (out / 'rooms.json').write_text(json.dumps(dict(version=1, canvas=[640, 400], rooms={'CHUT': room}), indent=1) + '\n')
    print('PASS CHUT media: background %d frames, intro %d frames / %d samples, %d lines (%s)' % (
        background['frames'], intro['frames'], intro['audio_samples'], len(lines),
        ', '.join('%d:%d/%d' % (c['line'], c['frames'], c['audio_samples']) for c in lines)))


def cli():
    global ROOT, GAME, convert
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 're-root', 'source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    try:
        converter = monastery_media.load_converter(a.re_root)
    except ValueError as error:
        p.error(str(error))
    if not a.source.is_file(): p.error('Missing input: ' + str(a.source))
    src = json.loads(a.source.read_text())
    path = a.game / 'DAT/CHUT.MIX'
    if not path.is_file(): p.error('Missing original ' + str(path))
    archive = path.read_bytes()
    if digest(archive) != src['archive_sha256']: p.error(f'{path}: not the pinned original')
    try:
        for record in list(src['media'].values()) + src['clips']:
            got = movie(archive, record['name'])
            assert all(got[k] == record[k] for k in ('sha256', 'frames', 'width', 'height', 'x', 'y')), record['name']
    except (AssertionError, KeyError, StopIteration, ValueError) as error:
        p.error('Originals do not match the CHUT source: ' + str(error))
    convert = converter
    GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main(src)


if __name__ == '__main__':
    cli()
