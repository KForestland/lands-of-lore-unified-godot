#!/usr/bin/env python3
"""Export original Glad_Hey_you audio, preserving source provenance and decoded length."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import wave


def sha(data):
    return hashlib.sha256(data).hexdigest()


def export(game_root, re_tools, out):
    from lol2_source_format import parse_mix, u32
    archive = (game_root / 'LOCALLNG.MIX').read_bytes()
    if sha(archive) != '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8':
        raise ValueError('Localized archive differs from supported source')
    entry = next(e for e in parse_mix(archive) if e['key'] == 1570429112)
    blob = archive[entry['offset']:entry['offset'] + entry['size']]
    count, table = u32(blob, 0x258), u32(blob, 0x25c)
    if count != 1179 or table + count * 60 > len(blob):
        raise ValueError('Audio metadata extent differs')
    request = 920
    row = blob[table + request * 60:table + (request + 1) * 60]
    name = row[16:29].split(b'\0')[0].decode('ascii')
    label = row[32:58].split(b'\0')[0].decode('ascii')
    if (name, label) != ('0935001e.aud', 'Glad_Hey_you'):
        raise ValueError('Original warning identity differs')
    offset, length = u32(row, 0), u32(row, 4)
    if offset < 0x264 or offset + length > table:
        raise ValueError('Audio payload exceeds data extent')
    aud = blob[offset:offset + length]
    rate, packed, declared, flags, codec = struct.unpack_from('<HIIBB', aud)
    if (rate, flags, codec) != (22050, 2, 99) or packed + 12 != len(aud):
        raise ValueError('Unsupported or truncated AUD stream')
    cursor, decoded_bytes, chunks = 12, 0, 0
    while cursor < len(aud):
        if cursor + 8 > len(aud):
            raise ValueError('Truncated chunk header')
        size, unpacked, magic = struct.unpack_from('<HHI', aud, cursor)
        if magic != 0xDEAF or cursor + 8 + size > len(aud):
            raise ValueError('Invalid AUD chunk')
        if unpacked not in (size * 4, size * 4 + 2):
            raise ValueError('Unexpected mono ADPCM chunk output length')
        decoded_bytes += size * 4
        chunks += 1
        cursor += 8 + size
    # This source declares one extra sample; do not synthesize or pad it.
    if (chunks, decoded_bytes, declared) != (70, 141820, 141822):
        raise ValueError('Source sample-length witness differs')
    with tempfile.TemporaryDirectory(prefix='lol2-bridge-voice-') as temporary:
        path = Path(temporary) / name
        path.write_bytes(aud)
        result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 's16le', '-'],
                                check=True, capture_output=True)
        pcm = result.stdout
        diagnostics = [line.split('] ', 1)[-1] for line in result.stderr.decode('utf-8', errors='replace').splitlines()]
        expected_eof = ('Error during demuxing: Input/output error',
                        'Error retrieving a packet from demuxer: Input/output error')
        if len(pcm) != decoded_bytes or any(not any(message in line for message in expected_eof) for line in diagnostics):
            raise ValueError('AUD decoding failed validation')
    if sha(pcm) != '8b0f0d49031f5a451916f5809ed739c3cdf022aae1cc1055a9f3b805f55566dd':
        raise ValueError('Decoded PCM differs from reviewed FFmpeg output')
    out.mkdir(parents=True, exist_ok=True)
    path = out / 'hey_you.wav'
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm)
    with wave.open(str(path), 'rb') as wav:
        if wav.readframes(wav.getnframes()) != pcm or wav.getnframes() != 70910:
            raise ValueError('WAV round-trip differs')
    report = dict(archive='LOCALLNG.MIX', archive_sha256=sha(archive), entry=entry,
                  request_id=request, original_filename=name, original_label=label,
                  metadata_entry_offset=table + request * 60, metadata_hex=row.hex(),
                  payload_entry_offset=offset, payload_size=length, payload_sha256=sha(aud),
                  sample_rate=rate, channels=1, sample_width=2, samples=70910,
                  duration_seconds=70910 / rate, chunks=chunks, declared_output_bytes=declared,
                  decoded_output_bytes=len(pcm), decoder_diagnostics=diagnostics, pcm_sha256=sha(pcm), wav_sha256=sha(path.read_bytes()),
                  scope='Original labelled warning voice matched to user-observed Hey, you! bridge headfake. '
                        'Native bridge trigger binding not established. FFmpeg IMA-ADPCM decode; source '
                        'declares one more sample than encoded nibbles supply. No padding applied. '
                        'Existing Python AUD decoder has different rounding and is not used here.')
    (out / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-tools', type=Path, help='Legacy accepted argument; local readers are used')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists(): parser.error('--out must be a fresh directory')
    export(args.game_root, args.re_tools, args.out)
