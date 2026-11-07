#!/usr/bin/env python3
"""Stage the exact original movie13 CITADEL for the L12 control74 entrance."""
import argparse,hashlib,json
from pathlib import Path
from lol2.map_video_inventory import lookup_movie
from prepare_cave_entrance_death import encode
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=a.output_root.resolve()
f=lookup_movie(a.game,'L12_CM','citadel.vqa');assert f['status']=='exact' and f['sha256']=='1194e316d7bde1d9c0b82a4519450c92f7ed558d328dbb02ea484dd07a45ff6d'
cache=root/'tmp/l12_citadel_media';cache.mkdir(parents=True,exist_ok=True);vqa=cache/'citadel.vqa';vqa.write_bytes(f['blob'])
out=root/'assets/lol2/generated/l12_citadel';out.mkdir(parents=True,exist_ok=True);target=out/'citadel.ogv'
media=encode(vqa,cache,591,target);media.update(index=13,source_sha256=f['sha256'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),path='res://assets/lol2/generated/l12_citadel/citadel.ogv',scope='Original591frames at15fps; Ogg encoding and skip UI modern presentation')
(out/'movie.json').write_text(json.dumps(media,indent=1)+'\n');print('PASS original CITADEL movie13',media['seconds'],'seconds')
