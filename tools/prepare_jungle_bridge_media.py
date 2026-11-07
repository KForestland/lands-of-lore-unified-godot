#!/usr/bin/env python3
"""Stage original plank-break props961..965 and sounds452/777/779/781 into a fresh project media root."""
import argparse, json, shutil, struct, tempfile
from pathlib import Path
from lol2.map_props import export_props
from prepare_creature_audio_clips import stage_clips

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--project',type=Path,required=True)
    a=p.parse_args()
    target=a.project/'assets/lol2/generated/jungle_bridge_break'
    if target.exists(): raise SystemExit('Use a fresh media output directory')
    with tempfile.TemporaryDirectory(prefix='lol2-plank-media-') as temp:
        root=Path(temp)/'props'
        report=export_props(a.game,'L4_HJ',root)
        rows=[row for row in report['props'] if row['record'] in range(961,966)]
        assert sorted(r['record'] for r in rows)==list(range(961,966))
        materials={}
        for r in rows:
            assert not r['animated'] and r['frame_flags']==0
            assert struct.unpack_from('<H',bytes.fromhex(r['placement_hex']),8)[0]&0x1000
            materials[r['material']]=report['materials'][r['material']]
        target.mkdir(parents=True)
        for key,file in materials.items():
            shutil.copyfile(root/file,target/(key+'.png'))
        data={'version':1,'source':report['source'],'props':rows,'materials':{k:k+'.png' for k in materials},'scope':'Original placed sprites, source selector/bounds; all five initially absent. Fixed-Y billboards use existing port presentation.'}
        (target/'media.json').write_text(json.dumps(data,indent=2)+'\n')
    stage_clips(a.project,'jungle_bridge_break/sounds',[452,777,779,781],game=a.game)
    print('PASS plank media: five absent props, two original sprite images, four decoded source sounds')
if __name__=='__main__':main()
