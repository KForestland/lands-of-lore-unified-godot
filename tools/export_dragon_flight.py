#!/usr/bin/env python3
"""Convert the DLL-named dragon flight clips for the review player.

  python3 -S tools/export_dragon_flight.py --game-root GAME --re-root RE --out OUT

Production order is cave_video_review indices 6, 7, 8: DRAGON7, DRGNFLGT, DRAGON8.
The original archive, full WOMS path hashes, MIX entry indices and the published
companion-RE converter are checked before any output is written. A failed check
leaves an existing OUT unchanged. Audible playback is not claimed.
"""
import argparse, hashlib, json, shutil, subprocess, sys, tempfile
from pathlib import Path

# Published companion RE 2791eb11e453ad5cbccdce5d5d29efc1850a2d3c.
CONVERTER_SHA256 = 'fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d'
HASH_SHA256 = '35f884e62cd2538f9071ccceb019dbaa37f3daa08b8f6b3b485629c7a25f1796'
GEOMETRY_SHA256 = 'd2e959d2dc2a90f29387158d89e87fda4cdd29951d96f5dd094fef4803fedcba'
ARCHIVE_SHA256 = 'e1f6a78df62620d3b3219f9b4c1b5dcd63696c25851371563cf7e6869214cc39'
# name, MIX entry index, review filename. DLL order DRAGON7, DRGNFLGT, DRAGON8.
CLIPS = (
    ('DRAGON7', 3, 'dragon7.ogv'),
    ('DRGNFLGT', 0, 'drgnflgt.ogv'),
    ('DRAGON8', 4, 'dragon8.ogv'),
)
SCOPE = ('DLL call order and full-path archive name hashes matched; full-frame conversion checked. '
         'Native launch conditions,dialogue and scene integration pending.')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def fail(message):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    pins = {
        args.re_root / 'tools/convert_cave_video_review.py': CONVERTER_SHA256,
        args.re_root / 'tools/lol2_westwood_hash.py': HASH_SHA256,
        args.re_root / 'tools/draracle/lol2_extract_draracle_geometry.py': GEOMETRY_SHA256,
    }
    for path, digest in pins.items():
        if not path.is_file() or sha(path.read_bytes()) != digest:
            parser.error(f'{path}: missing or not the pinned published helper {digest}')
    for tool in ('ffmpeg', 'ffprobe'):
        if shutil.which(tool) is None:
            parser.error(f'{tool} not found on PATH')
    codecs = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], capture_output=True, text=True).stdout
    codecs += subprocess.run(['ffmpeg', '-hide_banner', '-decoders'], capture_output=True, text=True).stdout
    for codec in ('libtheora', 'libvorbis', 'vqavideo'):
        if codec not in codecs:
            parser.error(f'ffmpeg lacks {codec}')
    sys.path[:0] = [str(args.re_root / 'tools'), str(args.re_root / 'tools/draracle')]
    from lol2_extract_draracle_geometry import parse_mix
    from lol2_westwood_hash import ww_hash_v1
    from convert_cave_video_review import convert
    archive_path = args.game_root / 'DAT/DRAGON.MIX'
    if not archive_path.is_file():
        parser.error(f'missing original {archive_path}')
    archive = archive_path.read_bytes()
    if sha(archive) != ARCHIVE_SHA256:
        fail('Dragon archive differs from the pinned DAT/DRAGON.MIX')
    entries = parse_mix(archive)
    prepared = []
    for name, index, filename in CLIPS:
        source_name = f'WOMS\\DRAGON\\{name}.VQA'
        key = ww_hash_v1(source_name)
        matches = [entry for entry in entries if entry['key'] == key]
        if len(matches) != 1 or matches[0]['index'] != index:
            fail(f'{source_name}: expected one MIX entry at index {index}')
        entry = matches[0]
        data = archive[entry['offset']:entry['offset'] + entry['size']]
        if data[:4] != b'FORM' or data[8:12] != b'WVQA':
            fail(f'{source_name}: not a WVQA FORM')
        prepared.append((name, filename, source_name, entry, data))
    args.out.mkdir(parents=True, exist_ok=True)
    rows = []
    staged = []
    with tempfile.TemporaryDirectory(prefix='.dragon-staging-', dir=args.out) as tmp:
        stage = Path(tmp)
        for name, filename, source_name, entry, data in prepared:
            source = stage / f'{name.lower()}.vqa'
            source.write_bytes(data)
            output = stage / filename
            convert(source, output)
            report = json.loads(output.with_suffix('.json').read_text())
            report.update(source=source_name, output=str(args.out / output.name))
            output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
            rows.append(dict(name=name, file=output.name, source_name=source_name, source_entry=entry,
                             source_sha256=sha(data), sha256=sha(output.read_bytes()),
                             frames=report['frames'], fps=report['fps']))
            staged += [(output, args.out / output.name), (output.with_suffix('.json'), args.out / f'{Path(filename).stem}.json')]
        provenance = stage / 'provenance.json'
        provenance.write_text(json.dumps(dict(archive_sha256=sha(archive), clips=rows, scope=SCOPE), indent=2) + '\n')
        staged.append((provenance, args.out / 'provenance.json'))
        for source, target in staged:
            shutil.move(str(source), str(target))
    print('Three DLL-named dragon clips converted and frame counts verified.')


if __name__ == '__main__':
    main()
