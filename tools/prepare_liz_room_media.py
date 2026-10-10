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
"""
import json, struct, subprocess, wave
from pathlib import Path
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


def main():
    src = json.loads((ROOT / 'scripts/lol2/liz_room_source.json').read_text())
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


if __name__ == '__main__':
    main()
