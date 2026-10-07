#!/usr/bin/env python3
"""Stage original Dawn63 E065E VQA segments locally; no published assets."""
import argparse,json,sys
from pathlib import Path
import prepare_jungle_bacatta_media as Media

SOURCE=Media.ROOT/'docs/jungle-dawn-source-audit.json'

def main():
    Media.OUT=Media.ROOT/'assets/lol2/generated/jungle_dawn_media'
    Media.CACHE=Media.ROOT/'tmp/jungle_dawn_media'
    Media.OUT.mkdir(parents=True,exist_ok=True);Media.CACHE.mkdir(parents=True,exist_ok=True)
    source=SOURCE
    contract=json.loads(source.read_text())
    row=next(r for s in contract['selectors'] if s['selector']==10 for r in s['resources'])
    assert row=={'resource':1,'vqa':'E065E.VQA'}
    clip=Media.clip(row['vqa'],'dawn')
    assert clip['frames']==2021 and len(clip['segments'])==14
    result=dict(version=1,source_sha256=Media.sha(source.read_bytes()),selector=10,resource=1,clip=clip)
    (Media.OUT/'media.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(status='PASS',frames=clip['frames'],segments=len(clip['segments']),duration=clip['duration'])))
def cli():
    global SOURCE,GAME
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output-root',type=Path,required=True)
    args=parser.parse_args()
    if args.output_root.exists():parser.error('--output-root must be a fresh directory')
    if not args.source.is_file():parser.error('Missing source contract')
    SOURCE=args.source.resolve();GAME=Media.GAME=args.game.resolve();Media.ROOT=args.output_root.resolve()
    import prepare_jungle_exit_movies as shared
    shared.ROOT=Media.ROOT
    main()
if __name__=='__main__':
    if len(sys.argv)>1:cli()
    else:main()

