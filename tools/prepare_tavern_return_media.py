#!/usr/bin/env python3
"""Stage the CAN later-visit clips (docs/tavern-return.md) with the existing room decoder.

Reads scripts/lol2/tavern_return_source.json (from verify_tavern_return_sources.py). It stages the maid lines
700..709, Bacatta's second visit 662..666 and line 675 into assets/lol2/generated/bacatta_revisit/. These are local
original media and are never published. clips.json maps the named sequences CAN_MAID / CAN_REVISIT / CAN_REVISIT_LATE
to clip records in the same format as bacatta_rooms (patch atlases + wav, or audio only).

Explicit inputs (fresh output root; nothing is written until every input is checked; published decoders only via
tools/monastery_media.py, no native audit module):
  python3 tools/prepare_tavern_return_media.py --game GAME --source scripts/lol2/tavern_return_source.json --output-root FRESH
Without arguments the historical repository-root behaviour is unchanged.
"""
import json, struct, subprocess, sys, wave
from pathlib import Path
if __name__ == '__main__' and len(sys.argv) > 1:
    import argparse, shutil
    import monastery_media
    from monastery_media import extract, digest, movie
    ROOT = GAME = None  # set by cli()

    def stage_patch(source, target, record):
        return monastery_media.stage_patch(source, target, record, ROOT)
else:
    from audit_monastery_rooms import ROOT, GAME, extract, digest, movie
    from prepare_monastery_rooms import stage_patch

CAN_ARCHIVE = '55395c6cfa2f846f4edb360877ab9c68002dce1367a5109624e1c3feba634675'


SOURCE_SHA256 = '850f337ffd64b1b71b9691704e319d0fb80e99c7c8463b4000cec5b5f8bd1e01'  # scripts/lol2/tavern_return_source.json


def main(source_path=None):
    source = json.loads((source_path or ROOT / 'scripts/lol2/tavern_return_source.json').read_text())
    archive = (GAME / 'DAT/CAN.MIX').read_bytes(); assert digest(archive) == CAN_ARCHIVE
    root = ROOT / 'assets/lol2/generated/bacatta_revisit'; cache = ROOT / 'tmp/bacatta_revisit_source'
    root.mkdir(parents=True, exist_ok=True); cache.mkdir(parents=True, exist_ok=True)
    out = {}
    for sequence, clips in source['sequences'].items():
        staged = []
        for clip in clips:
            payload, binding = extract(archive, clip['name']); assert binding['sha256'] == clip['sha256'], clip['name']
            name = clip['name'].split('\\')[-1]; src = cache / name; src.write_bytes(payload)
            target = root / (Path(name).stem + '.ogv')
            if clip['kind'] == 'audio_only':
                audio = target.with_suffix('.wav')
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(src), '-ac', '1', '-c:a', 'pcm_s16le', str(audio)], check=True)
                rate, _, decoded, _, _ = struct.unpack_from('<HIIBB', payload)
                with wave.open(str(audio)) as w:
                    assert w.getframerate() == rate and w.getnframes() * w.getsampwidth() == decoded
                    samples = w.getnframes()
                staged.append(dict(name=clip['name'], sha256=clip['sha256'], kind='audio_only', audio='res://' + str(audio.relative_to(ROOT)),
                                   audio_samples=samples, duration=samples / rate, frames=0, fps=15))
            else:
                record = movie(archive, clip['name']); assert record['sha256'] == clip['sha256']
                staged.append(stage_patch(src, target, dict(record, kind='movie')))
        out[sequence] = staged
    manifest = dict(version=1, room='CAN', sequences=out)
    (root / 'clips.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS tavern return media: ' + ', '.join(f'{k} {len(v)}' for k, v in out.items()))


def cli():
    global ROOT, GAME
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if shutil.which('ffmpeg') is None: p.error('ffmpeg not found on PATH')
    if not a.source.is_file(): p.error('Missing input: ' + str(a.source))
    if digest(a.source.read_bytes()) != SOURCE_SHA256: p.error(f'{a.source}: not the pinned tavern return source ({SOURCE_SHA256})')
    path = a.game / 'DAT/CAN.MIX'
    if not path.is_file(): p.error('Missing original ' + str(path))
    archive = path.read_bytes()
    if digest(archive) != CAN_ARCHIVE: p.error(f'{path}: not the pinned original')
    for clips in json.loads(a.source.read_text())['sequences'].values():
        for clip in clips:
            try:
                ok = extract(archive, clip['name'])[1]['sha256'] == clip['sha256'] and (clip['kind'] == 'audio_only' or movie(archive, clip['name'])['sha256'] == clip['sha256'])
            except (StopIteration, ValueError, AssertionError):
                ok = False
            if not ok: p.error('Original CAN entry does not match the source: ' + clip['name'])
    GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main(a.source.resolve())


if __name__ == '__main__':
    if len(sys.argv) > 1: cli()
    else: main()
