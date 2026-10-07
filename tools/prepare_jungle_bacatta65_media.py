#!/usr/bin/env python3
"""Stage original Bacatta65-branch media (local only) from the pinned L4_HJ data.

- prop553 template84 selectors 0-29 are texture type0x342 VQA references (names from
  scripts/lol2/jungle_bacatta65_source.json). Each distinct VQA is decoded once through the Bacatta media helpers
  (every VQFR frame and SND2 sample asserted), keyed to transparency, with its own voice WAV and LINF segments.
- BACL4 definition5 frames through the shared creature preparer (actor65's body; same definition as Bacatta61).
Output: assets/lol2/generated/jungle_bacatta65_media/ (ignored, never published).
"""
import json
import prepare_jungle_bacatta_media as M
from prepare_jungle_exit_movies import sha,res,ROOT,TEXTURE
from prepare_museum_creature_sprites import stage
M.OUT=OUT=ROOT/'assets/lol2/generated/jungle_bacatta65_media'
M.CACHE=ROOT/'tmp/jungle_bacatta65_media'
SOURCE=ROOT/'scripts/lol2/jungle_bacatta65_source.json'

def main():
    OUT.mkdir(parents=True,exist_ok=True);M.CACHE.mkdir(parents=True,exist_ok=True)
    src=json.loads(SOURCE.read_text())
    clips={};names={}
    for selector,row in src['prop']['selectors'].items():
        if row['vqa'] not in names: names[row['vqa']]=M.clip(row['vqa'],'prop553_'+selector)
        clips[selector]=dict(names[row['vqa']],resource=row['resource'],selector=int(selector))
    idle=clips['5']
    assert idle['vqa']=='BC08.VQA' and len(idle['segments'])>=2 and idle['segments'][1]['frames']>0,idle['segments']
    stage('DAT/L4_HJ.MIX',TEXTURE.read_bytes(),[5],OUT/'bacatta_sprites')
    manifest=dict(version=1,archive='DAT/L4_HJI.MIX',source_sha256=sha(SOURCE.read_bytes()),clips=clips,sprites=res(OUT/'bacatta_sprites/sprites.json'),
        note='Original media, local only. Clip duration = max(frames/fps, voice length); a segment lasts its LIND frame span at the clip fps.')
    (OUT/'media.json').write_text(json.dumps(manifest,indent=1)+'\n')
    print('PASS clips',{s:(c['vqa'],c['frames'],round(c['duration'],3),len(c['segments'])) for s,c in clips.items()})
if __name__=='__main__':main()
