#!/usr/bin/env python3
"""Rebuild Kelsrick's complete local media pack from explicit inputs and the checked source contract."""
import argparse,json
from pathlib import Path
import prepare_jungle_bacatta_media as media
import prepare_jungle_exit_movies as shared
from prepare_museum_creature_sprites import stage

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ['game','texture','source','output-root']:p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for path in [a.texture,a.source]:
  if not path.is_file():p.error('Missing input: '+str(path))
 root=a.output_root.resolve();media.GAME=a.game.resolve();media.ROOT=shared.ROOT=root
 out=root/'assets/lol2/generated/jungle_kelsrick';out.mkdir(parents=True)
 source=json.loads(a.source.read_text());assert list(source['poses'])==list(map(str,range(9,16)))
 assert shared.sha(a.texture.read_bytes())==source['texture_sha256']
 stage('DAT/L4_HJ.MIX',a.texture.read_bytes(),[7],out/'sprites',game=media.GAME)
 media.OUT=out;media.CACHE=root/'tmp/jungle_kelsrick';media.CACHE.mkdir(parents=True)
 clips={selector:dict(media.clip(row['vqa'],'pose_'+selector),resource=row['resource'],selector=int(selector)) for selector,row in source['poses'].items()}
 (out/'media.json').write_text(json.dumps(dict(version=1,clips=clips,sprites='res://assets/lol2/generated/jungle_kelsrick/sprites/sprites.json'),indent=1)+'\n')
 print('PASS complete Kelsrick media',[(k,v['frames']) for k,v in clips.items()])
if __name__=='__main__':main()
