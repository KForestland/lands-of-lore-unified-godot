#!/usr/bin/env python3
"""Stage the Hive boulder audio pack from explicit original archives.

Install this file as tools/prepare_hive_boulder_audio.py. With no arguments,
main() is the legacy boulder-audio dispatch: its first three statements import the
executioner verifier, the atlas reader, and the wax preparer, and the
remaining statements match the boulder-audio preparer. Any other invocation calls
portable_main().

--tools-root is the tools directory containing this program,
prepare_creature_audio_clips.py, and lol2_source_format.py. It is not a
repository root. The portable path does not import the executioner verifier,
the wax preparer, or the atlas module. That atlas module inserts an external
helper checkout onto the module path; the portable path calls published
parse_mix, u32, sound_bank, and stage_clips instead.

--source is the published docs/game-geometry-profiles.json contract. The
L5_HC source pin supplies the archive file, archive sha256, geometry key, and
geometry sha256. Command payload bytes stay pinned. Their archive offsets and
the prop positions are recomputed from those archives.

The portable path does not change clip lengths. close, exit, and the two roll
cues stay 32256, 47616, and 7616 samples at 22050 Hz.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK_HASH = 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'


def digest(data):
    return hashlib.sha256(data).hexdigest()


CUES = (
    (704, 'stone4.aud', ('1403ea00c00296000c06',)),
    (701, 'stone6.aud', ('14034d00bd0296000c06',)),
    (709, 'stonel1.aud', ('14021e00c502ff020306', '14021f00c502ff020306')),
)
PROP_IDS = (77, 234)
SCOPE = (
    'Four exact command payloads occur once each in the pinned Hive archive. '
    'Their sound words select three named bank records; decoded mono PCM16 counts '
    'match the encoded nibble counts; declared extra samples are not padded. Native playback, looping, attenuation and owner removal '
    'are not established by this extraction. Original media remains local.'
)

parse_mix = u32 = sound_bank = stage_clips = None


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def section(raw: bytes, offset_field: int, count_field: int, stride: int):
    """Published atlas section read via lol2_source_format.u32."""
    offset, count = u32(raw, offset_field), u32(raw, count_field)
    if offset + count * stride > len(raw):
        raise ValueError(f'Section {offset_field:X}/{count_field:X} exceeds geometry')
    return offset, count, raw[offset:offset + count * stride]


def bind(tools_root: Path) -> None:
    """Load published MIX, geometry-word, bank, and clip readers."""
    global parse_mix, u32, sound_bank, stage_clips
    tools_root = tools_root.resolve()
    needed = (
        tools_root / 'prepare_creature_audio_clips.py',
        tools_root / 'lol2_source_format.py',
    )
    missing = [str(path) for path in needed if not path.is_file()]
    if missing:
        raise ValueError('Missing published helper: ' + missing[0])
    entry = str(tools_root)
    if entry not in sys.path:
        sys.path.insert(0, entry)
    from lol2_source_format import parse_mix as mix
    from lol2_source_format import u32 as read_u32
    from prepare_creature_audio_clips import BANK_HASH as published_bank
    from prepare_creature_audio_clips import sound_bank as bank_reader
    from prepare_creature_audio_clips import stage_clips as stage
    require(published_bank == BANK_HASH, 'Published sound-bank pin does not match the legacy pack')
    parse_mix, u32 = mix, read_u32
    sound_bank, stage_clips = bank_reader, stage


def _overlaps(left: Path, right: Path) -> bool:
    left, right = left.resolve(), right.resolve()
    return left == right or left in right.parents or right in left.parents


def hive_source(source_path: Path) -> dict:
    profile = json.loads(source_path.read_text())
    areas = profile.get('areas')
    require(isinstance(areas, list), f'{source_path}: geometry profile has no areas')
    rows = [area for area in areas if isinstance(area, dict) and area.get('id') == 'L5_HC']
    require(len(rows) == 1, f'{source_path}: expected one L5_HC geometry profile')
    source = rows[0].get('source')
    require(isinstance(source, dict), f'{source_path}: L5_HC profile has no source pin')
    for key in ('file', 'sha256', 'geometry_key', 'geometry_sha256'):
        require(key in source, f'{source_path}: L5_HC source misses {key}')
    require(source['file'] == 'DAT/L5_HC.MIX', f'{source_path}: L5_HC archive file is not DAT/L5_HC.MIX')
    require(source['geometry_key'] == 3776990464, f'{source_path}: L5_HC geometry key is not the pinned Hive entry')
    return source


def prop_positions(geo: bytes) -> dict:
    offset, count, props = section(geo, 0x14, 0x60, 37)
    require(count > max(PROP_IDS), 'Hive prop section does not reach the pinned boulder props')
    require(offset + count * 37 == offset + len(props), 'Hive prop section is short')
    positions = {}
    for prop in PROP_IDS:
        require(prop * 37 + 8 <= len(props), f'Hive prop {prop} is outside the prop section')
        x, z, _heading, y = struct.unpack_from('<hhHh', props, prop * 37)
        positions[str(prop)] = [x, y, -z]
    return positions


def command_rows(archive: bytes) -> list:
    commands = []
    for request, _name, payloads in CUES:
        for payload in payloads:
            raw = bytes.fromhex(payload)
            found = archive.count(raw)
            require(found == 1, f'command payload {payload} occurs {found} times')
            word = struct.unpack_from('<H', raw, 4)[0]
            require(word == request, f'command payload {payload} sound word is {word}')
            commands.append(dict(payload=payload, archive_offset=archive.index(raw),
                                 request=request, config=list(raw[6:])))
    return commands


def bank_records(bank: bytes) -> dict:
    count, table = struct.unpack_from('<II', bank, 0x258)
    require(count == 1179 and table == 24938684, 'Creature sound bank table is not the pinned 1179-row table')
    records = {}
    for request, name, _payloads in CUES:
        row = bank[table + request * 60:table + (request + 1) * 60]
        require(len(row) == 60, f'sound request {request} row is short')
        got = row[16:].split(b'\0')[0].decode()
        require(got == name, f'sound request {request} name is {got}')
        offset, size = struct.unpack_from('<II', row)
        audio = bank[offset:offset + size]
        rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio)
        require(len(audio) == size == packed + 12 and flags == 2 and codec == 99 and rate == 22050,
                f'sound request {request} is not a pinned 22050 Hz AUD record')
        cursor, pcm_bytes, declared_chunks, chunks = 12, 0, 0, 0
        while cursor < len(audio):
            require(cursor + 8 <= len(audio), f'sound request {request} chunk header is truncated')
            size_in, size_out, magic = struct.unpack_from('<HHI', audio, cursor)
            require(magic == 0xDEAF and cursor + 8 + size_in <= len(audio),
                    f'sound request {request} chunk is truncated')
            require(size_out in (size_in * 4, size_in * 4 + 2),
                    f'sound request {request} chunk size is not a PCM16 expansion')
            pcm_bytes += size_in * 4
            declared_chunks += size_out
            chunks += 1
            cursor += 8 + size_in
        require(cursor == len(audio) and declared_chunks == decoded and decoded - pcm_bytes in (0, 2),
                f'sound request {request} declared PCM does not match the chunk sizes')
        records[request] = dict(name=name, rate=rate, chunks=chunks, declared_bytes=decoded,
                                pcm_bytes=pcm_bytes, audio_sha256=digest(audio))
    return records


def prepare(game_root: Path, source_path: Path, output_root: Path) -> dict:
    pin = hive_source(source_path)
    archive_path = game_root / pin['file']
    require(archive_path.is_file(), f'missing archive: {archive_path}')
    archive = archive_path.read_bytes()
    require(digest(archive) == pin['sha256'], f'{pin["file"]}: unsupported or changed archive')
    entries = [row for row in parse_mix(archive) if row['key'] == pin['geometry_key']]
    require(len(entries) == 1, f'{pin["file"]}: expected one geometry entry')
    geometry = entries[0]
    geo = archive[geometry['offset']:geometry['offset'] + geometry['size']]
    require(digest(geo) == pin['geometry_sha256'],
            f'{pin["file"]}: geometry does not match the published source contract')
    positions = prop_positions(geo)
    commands = command_rows(archive)
    bank = sound_bank(game_root)
    records = bank_records(bank)
    staged = stage_clips(
        output_root, 'hive_boulder_audio', [request for request, _name, _payloads in CUES],
        {request: name for request, name, _payloads in CUES}, game=game_root)
    output = output_root / 'assets/lol2/generated/hive_boulder_audio'
    clips = {}
    for request, name, _payloads in CUES:
        info = records[request]
        target = output / f'{request}.wav'
        with wave.open(str(target)) as wav:
            samples = wav.getnframes()
            pcm = wav.readframes(samples)
        require(samples * 2 == info['pcm_bytes'] and len(pcm) == info['pcm_bytes'],
                f'sound request {request} WAV frame count does not match the AUD PCM count')
        produced = staged[str(request)]
        require(produced['diagnostics'] == [
            'Error during demuxing: Input/output error',
            'Error retrieving a packet from demuxer: Input/output error',
        ], f'sound request {request} decoder diagnostics are not the known terminal pair')
        require(produced['pcm_sha256'] == digest(pcm), f'sound request {request} PCM hash changed')
        clips[str(request)] = dict(
            source_name=name, rate=info['rate'], samples=samples, chunks=info['chunks'],
            declared_bytes=info['declared_bytes'], pcm_bytes=info['pcm_bytes'],
            pcm_sha256=produced['pcm_sha256'], decoder_diagnostics=produced['diagnostics'],
            duration=samples / info['rate'], audio_sha256=info['audio_sha256'],
            wav_sha256=digest(target.read_bytes()),
            path='res://' + str(target.relative_to(output_root)))
    report_audio = dict(version=1, clips=clips, positions=positions)
    (output / 'audio.json').write_text(json.dumps(report_audio, indent=2) + '\n')
    source_report = dict(
        archive_sha256=pin['sha256'], sound_bank_sha256=BANK_HASH, commands=commands,
        clips=clips, positions=positions, scope=SCOPE)
    doc = output_root / 'docs/hive-boulder-audio-source.json'
    doc.parent.mkdir(parents=True, exist_ok=True)
    doc.write_text(json.dumps(source_report, indent=2) + '\n')
    return {
        'archive_sha256': pin['sha256'],
        'geometry_sha256': pin['geometry_sha256'],
        'commands': len(commands),
        'positions': positions,
        'clips': len(clips),
    }


def main():
    from verify_hive_executioner import GAME, ARCHIVE_SHA
    from build_game_atlas import parse_mix, section
    from prepare_hive_wax import entry
    archive = (GAME / 'DAT/L5_HC.MIX').read_bytes()
    assert digest(archive) == ARCHIVE_SHA
    bank = entry('LOCALLNG.MIX', 1570429112)
    assert digest(bank) == BANK_HASH
    count, table = struct.unpack_from('<II', bank, 0x258)
    assert count == 1179 and table == 24938684
    out = ROOT / 'assets/lol2/generated/hive_boulder_audio'
    cache = ROOT / 'tmp/hive_boulder_audio'
    out.mkdir(parents=True, exist_ok=True)
    cache.mkdir(parents=True, exist_ok=True)
    ge = next(e for e in parse_mix(archive) if e['key'] == 3776990464)
    geo = archive[ge['offset']:ge['offset'] + ge['size']]
    props = section(geo, 0x14, 0x60, 37)[2]
    positions = {}
    for prop in [77, 234]:
        x, z, heading, y = struct.unpack_from('<hhHh', props, prop * 37)
        positions[str(prop)] = [x, y, -z]
    clips = {}
    commands = []
    for request, name, payloads in [
        (704, 'stone4.aud', ['1403ea00c00296000c06']),
        (701, 'stone6.aud', ['14034d00bd0296000c06']),
        (709, 'stonel1.aud', ['14021e00c502ff020306', '14021f00c502ff020306']),
    ]:
        for payload in payloads:
            raw = bytes.fromhex(payload)
            assert archive.count(raw) == 1, payload
            assert struct.unpack_from('<H', raw, 4)[0] == request
            commands.append(dict(payload=payload, archive_offset=archive.index(raw),
                                 request=request, config=list(raw[6:])))
        row = bank[table + request * 60:table + (request + 1) * 60]
        assert row[16:].split(b'\0')[0].decode() == name
        offset, size = struct.unpack_from('<II', row)
        audio = bank[offset:offset + size]
        rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio)
        assert len(audio) == size == packed + 12 and flags == 2 and codec == 99
        cursor, pcm_bytes, declared_chunks, chunks = 12, 0, 0, 0
        while cursor < len(audio):
            assert cursor + 8 <= len(audio)
            size_in, size_out, magic = struct.unpack_from('<HHI', audio, cursor)
            assert magic == 0xDEAF and cursor + 8 + size_in <= len(audio)
            assert size_out in (size_in * 4, size_in * 4 + 2)
            pcm_bytes += size_in * 4
            declared_chunks += size_out
            chunks += 1
            cursor += 8 + size_in
        assert declared_chunks == decoded and decoded - pcm_bytes in (0, 2)
        source = cache / name
        target = out / f'{request}.wav'
        source.write_bytes(audio)
        result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source),
                                 '-f', 's16le', '-'], check=True, capture_output=True)
        pcm = result.stdout
        diagnostics = [line.split('] ', 1)[-1] for line in result.stderr.decode().splitlines()]
        expected = ['Error during demuxing: Input/output error',
                    'Error retrieving a packet from demuxer: Input/output error']
        assert all(line in expected for line in diagnostics), diagnostics
        assert len(pcm) == pcm_bytes
        with wave.open(str(target), 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(rate)
            wav.writeframes(pcm)
        with wave.open(str(target)) as wav:
            samples = wav.getnframes()
            assert samples * 2 == pcm_bytes and wav.readframes(samples) == pcm
        clips[str(request)] = dict(source_name=name, rate=rate, samples=samples,
                                  chunks=chunks, declared_bytes=decoded, pcm_bytes=pcm_bytes,
                                  pcm_sha256=digest(pcm), decoder_diagnostics=diagnostics,
                                  duration=samples / rate, audio_sha256=digest(audio),
                                  wav_sha256=digest(target.read_bytes()),
                                  path='res://' + str(target.relative_to(ROOT)))
    (out / 'audio.json').write_text(json.dumps(dict(version=1, clips=clips, positions=positions), indent=2) + '\n')
    report = dict(archive_sha256=ARCHIVE_SHA, sound_bank_sha256=BANK_HASH,
                  commands=commands, clips=clips, positions=positions,
                  scope='Four exact command payloads occur once each in the pinned Hive archive. '
                  'Their sound words select three named bank records; decoded mono PCM16 counts '
                  'match the encoded nibble counts; declared extra samples are not padded. Native playback, looping, attenuation and owner removal '
                  'are not established by this extraction. Original media remains local.')
    (ROOT / 'docs/hive-boulder-audio-source.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS four source command payloads, three bank records and exact decoded PCM counts')


def portable_main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True,
                        help='Original game directory containing LOCALLNG.MIX and DAT/L5_HC.MIX.')
    parser.add_argument('--source', type=Path, required=True,
                        help='Published docs/game-geometry-profiles.json contract.')
    parser.add_argument('--tools-root', type=Path, required=True,
                        help='Tools directory containing this program and the two published helpers. No default checkout.')
    parser.add_argument('--output-root', type=Path, required=True,
                        help='Fresh directory. The pack is written at assets/lol2/generated/hive_boulder_audio/.')
    args = parser.parse_args()
    if args.output_root.exists():
        parser.error('--output-root must be a fresh directory')
    for label, path in (('game', args.game_root), ('source', args.source), ('tools', args.tools_root)):
        if not path.exists():
            parser.error(f'Missing {label} path: {path}')
        if _overlaps(args.output_root, path):
            parser.error(f'--output-root overlaps the {label} path')
    try:
        bind(args.tools_root)
        summary = prepare(args.game_root, args.source, args.output_root)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f'prepare_hive_boulder_audio.py: error: {exc}', file=sys.stderr)
        raise SystemExit(1) from None
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    if len(sys.argv) == 1:
        main()
    else:
        portable_main()
