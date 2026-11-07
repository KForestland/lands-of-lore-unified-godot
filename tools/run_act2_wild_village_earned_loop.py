#!/usr/bin/env python3
"""Fresh fail-fast STORY028..034 continuation of the pinned milestone1 shore save."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from regression_source import snapshot,changes
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path('tmp/act2_wild_village_qualified'));a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=(root/a.output).resolve();rel=out.relative_to(root).as_posix()
assert rel.startswith('tmp/') and not out.exists(),'Use a fresh tmp output; no stale stage saves'
out.mkdir(parents=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
anchor=root/'tmp/act2_silverleaf_qualified/l8_shore_earned_save.json'
assert sha(anchor)=='389142125824f46570ef4cdc423ad8457ce9b401c9ebdc3b83a7a31df3518c7c'
start=snapshot(root);report=dict(name='act2_wild_village_earned_loop_test',anchor_sha256=sha(anchor),source_before=start,tests=[],complete=False)
receipt=out/'route_report.json'
for name in ['l8_dawn','l8_baccata','l10_silverleaf_growth','l10_silverleaf_harvest','l8_initiation','l8_shaman_trade','l8_clubhouse']:
 source=root/'tests'/f'{name}_earned_test.gd';text=source.read_text().replace('res://tmp/','res://'+rel+'/')
 text=text.replace('res://'+rel+'/act2_silverleaf_qualified/l8_shore_earned_save.json','res://tmp/act2_silverleaf_qualified/l8_shore_earned_save.json')
 driver=out/source.name;driver.write_text(text);log=out/f'{name}.log';began=time.time();print('RUN',name,flush=True)
 with log.open('w') as stream:
  result=subprocess.run(['flatpak','run','org.godotengine.Godot','--headless','--path',str(root),'--script',str(driver)],cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
 raw=log.read_text();drift=changes(start,snapshot(root));passed=result.returncode==0 and 'PASS' in raw and not any(x in raw for x in ['FAIL','SCRIPT ERROR:','ERROR:']) and not drift
 report['tests'].append(dict(name=name,passed=passed,seconds=round(time.time()-began,2),log=str(log.relative_to(root)),source_changes=drift,driver_sha256=sha(driver),source_sha256=sha(source)))
 receipt.write_text(json.dumps(report,indent=1)+'\n');print('PASS' if passed else 'FAIL',name,flush=True)
 if not passed:raise SystemExit(1)
end=json.loads((out/'l8_clubhouse_earned_save.json').read_text());q=end['quests'];carried=q['act2_items']['carried']
assert q['l8_clubhouse']['opened'] and q['l8_tribe']['phase']=='departed'
assert all('act2:L8_SJ:item'+str(i) in carried for i in [32,33,34])
assert 'act2:L8_SJ:shaman_amaranth' in carried
assert len([i for i in carried if i.startswith('act2:L10_DC:silverleaf')])==7
assert not changes(start,snapshot(root))
report.update(complete=True,milestone_passed=True,saves={str(q.relative_to(root)):sha(q) for q in out.glob('*save.json')},source_after=snapshot(root))
receipt.write_text(json.dumps(report,indent=1)+'\n');print('PASS milestone2: seven fresh earned stages, seven remaining leaves, serum and three original stones; source unchanged',flush=True)
