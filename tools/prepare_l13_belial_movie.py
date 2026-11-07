#!/usr/bin/env python3
"""Stage the exact original movie31 HV1-V-RL for the L13 control103 encounter."""
import argparse,hashlib,json
from pathlib import Path
from lol2.map_video_inventory import lookup_movie
from prepare_cave_entrance_death import encode
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=a.output_root.resolve()
f=lookup_movie(a.game,'L13_RC','hv1-v-rl.vqa');assert f['status']=='exact' and f['sha256']=='e38244a1af76b39cedaf71395bc50992ba919efd1ad9404a021037834a99bf62'
cache=root/'tmp/l13_belial_media';cache.mkdir(parents=True,exist_ok=True);vqa=cache/'hv1-v-rl.vqa';vqa.write_bytes(f['blob'])
out=root/'assets/lol2/generated/l13_belial';out.mkdir(parents=True,exist_ok=True);target=out/'belial.ogv'
media=encode(vqa,cache,1008,target);media.update(index=31,source_sha256=f['sha256'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),path='res://assets/lol2/generated/l13_belial/belial.ogv',scope='Original1008frames at15fps; Ogg encoding and skip UI modern presentation')
(out/'movie.json').write_text(json.dumps(media,indent=1)+'\n');print('PASS original HV1-V-RL movie31',media['seconds'],'seconds')
