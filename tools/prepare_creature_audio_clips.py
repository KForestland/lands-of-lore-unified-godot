#!/usr/bin/env python3
"""Shared pinned AUD-bank decoding and lossless WAV staging for creature cues."""
import argparse, hashlib, json, os, struct, subprocess, wave
from pathlib import Path
from lol2_source_format import parse_mix

BANK_HASH = 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'
# Preserve existing preparer calls; clean-machine callers pass game explicitly.
LEGACY_GAME = Path('/home/bob/lol2_out/museum_capture_20260913/game')

def sound_bank(game):
    archive = (Path(game) / 'LOCALLNG.MIX').read_bytes()
    rows = [row for row in parse_mix(archive) if row['key'] == 1570429112]
    if len(rows) != 1:
        raise ValueError('Expected exactly one creature sound bank')
    row = rows[0]
    bank = archive[row['offset']:row['offset'] + row['size']]
    if sha(bank) != BANK_HASH:
        raise ValueError('Unsupported creature sound bank hash')
    return bank

def sha(raw): return hashlib.sha256(raw).hexdigest()

def stage_clips(root, folder, requests, names=None, *, game=None):
    root = Path(root)
    folder_path = Path(folder)
    if folder_path.is_absolute() or '..' in folder_path.parts:
        raise ValueError('Audio folder must stay within generated assets')
    requests = list(requests)
    if any(type(request) is not int or not 0 <= request < 1179 for request in requests):
        raise ValueError('Sound requests must be integers from0 through1178')
    bank=sound_bank(game if game is not None else os.environ.get('LOL2_GAME_ROOT', LEGACY_GAME))
    count,table=struct.unpack_from('<II',bank,0x258)
    assert count==1179 and table==24938684
    output=root/'assets/lol2/generated'/folder;output.mkdir(parents=True,exist_ok=True)
    cache=root/'tmp'/folder;cache.mkdir(parents=True,exist_ok=True)
    clips={}
    for request in requests:
        row=bank[table+request*60:table+(request+1)*60]
        name=row[16:].split(b'\0')[0].decode();assert names is None or name==names[request]
        offset,size=struct.unpack_from('<II',row)
        audio=bank[offset:offset+size]
        rate,packed,decoded,flags,codec=struct.unpack_from('<HIIBB',audio)
        assert len(audio)==packed+12 and flags==2 and codec==99 and rate==22050
        cursor=12;expected_pcm=declared=chunks=0
        while cursor<len(audio):
            size_in,size_out,magic=struct.unpack_from('<HHI',audio,cursor)
            assert magic==0xDEAF and cursor+8+size_in<=len(audio)
            assert size_out in (size_in*4,size_in*4+2)
            expected_pcm+=size_in*4;declared+=size_out;chunks+=1
            cursor+=8+size_in
        assert cursor==len(audio) and declared==decoded and decoded-expected_pcm in [0,2]
        source=cache/name;source.write_bytes(audio)
        result=subprocess.run(['ffmpeg','-v','error','-i',str(source),'-f','s16le','-'],capture_output=True,check=True)
        diagnostics=[line.split('] ',1)[-1] for line in result.stderr.decode().splitlines()]
        assert all(line in ['Error during demuxing: Input/output error','Error retrieving a packet from demuxer: Input/output error'] for line in diagnostics)
        pcm=result.stdout;assert len(pcm)==expected_pcm
        target=output/f'{request}.wav'
        with wave.open(str(target),'wb') as wav:
            wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(pcm)
        with wave.open(str(target)) as wav:
            assert wav.getnchannels()==1 and wav.getsampwidth()==2 and wav.getframerate()==rate
            assert wav.readframes(wav.getnframes())==pcm
        clips[str(request)]=dict(name=name,rate=rate,samples=len(pcm)//2,duration=len(pcm)/2/rate,chunks=chunks,
            audio_sha256=sha(audio),pcm_sha256=sha(pcm),wav_sha256=sha(target.read_bytes()),diagnostics=diagnostics,path='res://'+str(target.relative_to(root)))
    return clips


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True, help='Installed original game directory containing LOCALLNG.MIX')
    parser.add_argument('--output-root', type=Path, required=True, help='Project or isolated staging root')
    parser.add_argument('--folder', required=True, help='Subdirectory below assets/lol2/generated')
    parser.add_argument('--request', type=int, action='append', required=True, help='Sound-bank request; repeat for multiple cues')
    args = parser.parse_args()
    clips = stage_clips(args.output_root, args.folder, args.request, game=args.game)
    report = {'sound_bank_sha256': BANK_HASH, 'clips': clips}
    target = args.output_root / 'assets/lol2/generated' / args.folder / 'audio.json'
    target.write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {len(clips)} sound clips staged; manifest: {target}')

if __name__ == '__main__':
    main()
