#!/usr/bin/env python3
"""Decode supported local VQA movies to raw PNG frames and mono WAV audio.

Shared by encounter preparers. Requires Pillow, NumPy and FFmpeg; no external
research checkout, game path or encounter data is imported. Sprite keying,
atlas packing and story/segment bindings remain caller responsibilities.
"""
import argparse, hashlib, json, subprocess, wave
from pathlib import Path
from PIL import Image
from vqa_v2_decode import header

def decode(path,folder,count,size):
    folder.mkdir(parents=True,exist_ok=True)
    for old in folder.glob('*.png'): old.unlink()
    # VQA v2 with partial codebooks: FFmpeg's partial-codebook decompression stops early in some groups (every vector at
    # or above a cut-off index decodes wrong, leaving key-colour holes). Decode those files with the Python decoder (tools/vqa_v2_decode.py,
    # pixel-identical to FFmpeg on every unaffected frame); everything else still goes through FFmpeg.
    from vqa_v2_decode import frames_to_dir
    if frames_to_dir(path,folder): pass
    # FFmpeg reports a terminal demuxer diagnostic on these files; frame/sample totals are asserted.
    else: subprocess.run(['ffmpeg','-v','quiet','-y','-i',str(path),'-vsync','0',str(folder/'%04d.png')],check=False)
    frames=sorted(folder.glob('*.png'));assert len(frames)==count,(path,len(frames))
    for p in frames: assert Image.open(p).size==size
    return frames

def audio(path,target,samples):
    subprocess.run(['ffmpeg','-v','quiet','-y','-i',str(path),'-vn','-ac','1','-c:a','pcm_s16le',str(target)],check=False)
    with wave.open(str(target)) as w:
        assert w.getnchannels()==1 and w.getnframes()==samples,(path,w.getnframes(),samples)
        return w.getframerate()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='Fresh output directory')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Use a fresh output directory')
    blob = args.input.read_bytes()
    top, fields = header(blob)
    if any(tag.startswith(b'SND') and tag != b'SND2' for tag, _ in top):
        parser.error('Only SND2 audio is supported by this mono preparation path')
    if fields['fps'] <= 0:
        parser.error('Movie frame rate must be positive')
    # Match the existing encounter stagers: SND2 bytes expand to two PCM samples.
    samples = sum(len(payload) * 2 for tag, payload in top if tag == b'SND2')
    frames = decode(args.input, args.output / 'frames', fields['frames'], (fields['width'], fields['height']))
    rate = audio(args.input, args.output / 'voice.wav', samples) if samples else 0
    files = frames + ([args.output / 'voice.wav'] if samples else [])
    report = dict(input_sha256=hashlib.sha256(blob).hexdigest(), header=fields,
                  frames=len(frames), audio_samples=samples, audio_rate=rate,
                  files={str(p.relative_to(args.output)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
                  scope='Raw movie frames and mono SND2 audio; no transparency key, atlas, segment or story binding.')
    (args.output / 'media.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {len(frames)} frames, {samples} audio samples')

if __name__ == '__main__':
    main()
