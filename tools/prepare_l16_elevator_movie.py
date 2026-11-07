#!/usr/bin/env python3
"""Stage original movie27 ELEVATOR; default output stays outside frozen runtime assets."""
import argparse, hashlib, json
from pathlib import Path
from lol2.map_video_inventory import lookup_movie
from prepare_cave_entrance_death import encode

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--game', type=Path, required=True)
p.add_argument('--output', type=Path, default=Path('tmp/l16_elevator_staged'))
p.add_argument('--cache', type=Path, default=Path('tmp/l16_elevator_media'))
a = p.parse_args()
f = lookup_movie(a.game, 'L16_CA', 'elevator.vqa')
assert f['status'] == 'exact' and f['sha256'] == 'e1cbd9e3a97a695733efbb1d9122e99ff856ee14eb1b295701b85079654f62c2'
assert f['archive_sha256'] == '8da2db1a99c3a8f79d6ff92c7e1afbf1db7ad11b9faf7f7af013f0115bc531d4'
assert f['vqhd']['count'] == 255 and f['vqhd']['fps'] == 15
a.cache.mkdir(parents=True, exist_ok=True)
a.output.mkdir(parents=True, exist_ok=True)
vqa = a.cache / 'elevator.vqa'
vqa.write_bytes(f['blob'])
target = a.output / 'elevator.ogv'
media = encode(vqa, a.cache / 'frames', 255, target)
media.update(index=27, source_sha256=f['sha256'], sha256=hashlib.sha256(target.read_bytes()).hexdigest(), path='res://assets/lol2/generated/l16_elevator/elevator.ogv', scope='Original255frames at15fps; encoding/skip presentation modern. Gameplay not qualified.')
(a.output / 'movie.json').write_text(json.dumps(media, indent=1) + '\n')
print('PASS original ELEVATOR movie27', media['seconds'], 'seconds', media['sha256'])
