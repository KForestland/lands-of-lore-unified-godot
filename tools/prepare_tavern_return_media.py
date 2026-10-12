#!/usr/bin/env python3
"""Stage the CAN later-visit clips (docs/tavern-return.md) with the existing room decoder.

Reads scripts/lol2/tavern_return_source.json (from verify_tavern_return_sources.py). It stages the maid lines
700..709, Bacatta's second visit 662..666 and line 675 into assets/lol2/generated/bacatta_revisit/. These are local
original media and are never published. clips.json maps the named sequences CAN_MAID / CAN_REVISIT / CAN_REVISIT_LATE
to clip records in the same format as bacatta_rooms (patch atlases + wav, or audio only).
"""
import json, struct, subprocess, wave
from pathlib import Path
from audit_monastery_rooms import ROOT, GAME, extract, digest, movie
from prepare_monastery_rooms import stage_patch

CAN_ARCHIVE = '55395c6cfa2f846f4edb360877ab9c68002dce1367a5109624e1c3feba634675'


def main():
    source = json.loads((ROOT / 'scripts/lol2/tavern_return_source.json').read_text())
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


if __name__ == '__main__':
    main()
