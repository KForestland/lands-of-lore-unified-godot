#!/usr/bin/env python3
"""Extract pinned Act1 texture blobs directly from original level MIX archives.

Requires Python standard library and the system liblzo2, no runtime cache or
external RE checkout. Does not decode individual sprites or world materials.
"""
import argparse, hashlib, json
from pathlib import Path
from lol2_source_format import parse_mix
from lol2_texture_container import decode_lzo_container
ROOT=Path('/home/bob/lol2_out/museum_capture_20260913/game')
PROFILES={'L5_HC': ('a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8', 3777974535), 'L3_DH': ('bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 3107535131), 'L4_HJ': ('517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f', 3711781155), 'L1_DC': ('6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345', 2972657927)}

def decode(name, *, game=None):
    archive=((Path(game) if game is not None else ROOT)/'DAT'/f'{name}.MIX').read_bytes()
    expected,key=PROFILES[name]
    if hashlib.sha256(archive).hexdigest()!=expected:
        raise ValueError('Original area archive hash differs from supported profile')
    entries=[e for e in parse_mix(archive) if e['key']==key]
    if len(entries)!=1:raise ValueError('Expected exactly one texture entry')
    entry=entries[0];blob,details=decode_lzo_container(archive,entry)
    return blob,dict(archive_sha256=expected,entry=entry,blocks=details['blocks'],
                     decoded_sha256=details['decoded_sha256'],size=len(blob))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--area',choices=sorted(PROFILES),required=True)
    parser.add_argument('--output',type=Path,required=True,help='Fresh directory for texture.bin and texture_decode.json')
    args=parser.parse_args()
    if args.output.exists():parser.error('Use a fresh output directory')
    blob,report=decode(args.area,game=args.game)
    args.output.mkdir(parents=True)
    (args.output/'texture.bin').write_bytes(blob)
    report['area']=args.area
    report['scope']='Hash-pinned archive and bounded liblzo2 block decode; no rendered or gameplay acceptance.'
    (args.output/'texture_decode.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS {args.area}: {len(blob)} texture bytes')

if __name__=='__main__':main()
