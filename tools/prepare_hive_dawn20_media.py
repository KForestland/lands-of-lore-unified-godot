#!/usr/bin/env python3
"""Stage Hive Dawn20's original E075E.VQA talk segments locally (selector10/resource1); never published.

Reuses the Bacatta clip decoder (every VQFR frame and SND2 sample asserted, cyan key → alpha) with an L5_HC
movie lookup: SPHERE1 entry in DAT/L5_HCI.MIX, any SPHERE2 twin reported, never chosen.
"""
import argparse,json,sys
from pathlib import Path
import prepare_jungle_bacatta_media as Media
from prepare_jungle_exit_movies import sha,GAME,lookup_movie,parse_vqa_chunks
from lol2.map_video_inventory import vqhd_fields

def fetch(name):
    found=lookup_movie(GAME,'L5_HC',name)
    if found['status']=='exact':
        assert found['archive']=='DAT/L5_HCI.MIX',(name,found)
        hit=dict(sha256=found['sha256'],offset=found['offset'],length=found['length'],twin=None,prefix=found['prefix'])
    else:
        assert found['status']=='ambiguous',(name,found['status'])
        ones=[c for c in found['candidates'] if c['prefix']=='SPHERE1'];twins=[c for c in found['candidates'] if c['prefix']!='SPHERE1']
        assert len(ones)==1 and ones[0]['wvqa'],name
        hit=dict(sha256=ones[0]['sha256'],offset=ones[0]['offset'],length=ones[0]['length'],twin=[(c['prefix'],c['sha256']) for c in twins],prefix='SPHERE1')
    archive=(GAME/'DAT/L5_HCI.MIX').read_bytes();assert sha(archive)==found['archive_sha256']
    blob=archive[hit['offset']:hit['offset']+hit['length']];assert sha(blob)==hit['sha256']
    chunks=parse_vqa_chunks(blob);head=vqhd_fields(blob);assert head
    assert sum(k==b'VQFR' for k,v in chunks)==head['count']
    path=Media.CACHE/name;path.write_bytes(blob)
    return dict(sha256=hit['sha256'],prefix=hit['prefix'],sphere2_twin=hit['twin']),path,head,sum(len(v)*2 for k,v in chunks if k==b'SND2')

SOURCE=Media.ROOT/'scripts/lol2/hive_dawn20_source.json'

def main():
    Media.OUT=Media.ROOT/'assets/lol2/generated/hive_dawn20_media'
    Media.CACHE=Media.ROOT/'tmp/hive_dawn20_media'
    Media.fetch=fetch
    Media.OUT.mkdir(parents=True,exist_ok=True);Media.CACHE.mkdir(parents=True,exist_ok=True)
    source=SOURCE
    src=json.loads(source.read_text());assert src['vqa']=='E075E.VQA' and src['selector']==10
    clip=Media.clip(src['vqa'],'dawn20')
    used=sorted({int(c[12:16][2:]+c[12:16][:2],16) for g in src['groups'] for c in g['commands'] if c[:2]=='08' and c[2:8]=='021400' and c[8:10]=='0a'})
    assert max(used)<len(clip['segments']),(used,len(clip['segments']))
    result=dict(version=1,source_sha256=Media.sha(source.read_bytes()),selector=10,resource=1,segments_used=used,clip=clip)
    (Media.OUT/'media.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(status='PASS',frames=clip['frames'],segments=len(clip['segments']),used=used,duration=clip['duration'],
        durations=[round((s['last']-s['first']+1)/clip['fps'],2) for s in clip['segments']])))
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

