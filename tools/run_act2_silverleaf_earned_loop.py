#!/usr/bin/env python3
"""Qualify milestone1: continuous earned Dawn Act2 branch through flood and shore."""
import argparse, hashlib, json, subprocess, time
from pathlib import Path
from regression_source import snapshot, changes
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,default=Path('tmp/act2_silverleaf_qualified'))
p.add_argument('--resume',action='store_true')
a=p.parse_args();root=Path(__file__).resolve().parents[1];out=(root/a.output).resolve();rel=out.relative_to(root).as_posix()
assert rel.startswith('tmp/');out.mkdir(parents=True,exist_ok=True)
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
departure=root/"tmp/dampen_darker_arrival_earned_save.json"
assert sha(departure)=="3f41667fc5ea5e39e92fd964083d4ec1247dd5269a13afba73f49c2e3475c53d", "Earned departure changed"
start=snapshot(root)
receipt=out/'route_report.json'
old=json.loads(receipt.read_text()) if a.resume and receipt.exists() else None
if old:assert not changes(old['source_before'],start),'Production changed since route start'
report=dict(name='act2_silverleaf_earned_loop_test',scope='Milestone1 through STORY027, not the later nine-silverleaf return. Continuous earned Dawn departure; no seeds or inventory merges.',source_before=start,tests=[],complete=False)
receipt.write_text(json.dumps(report,indent=1)+'\n')
command=['python3',str(root/'tools/run_dampen_earned_campaign.py'),'--output',str(out/'campaign')]
if a.resume and (out/'campaign/qualification_report.json').exists():command.append('--resume')
subprocess.run(command,cwd=root,check=True)
prefix=json.loads((out/'campaign/qualification_report.json').read_text())
assert prefix['complete'] and len(prefix['tests'])==27 and all(t['passed'] for t in prefix['tests'])
assert not changes(start,snapshot(root))
report['tests']=prefix['tests'];report['campaign_report_sha256']=sha(out/'campaign/qualification_report.json')
for name in ['l9_flood_escape','l8_shore']:
 source=root/'tests'/f'{name}_earned_test.gd'
 text=source.read_text().replace('res://tmp/','res://'+rel+'/').replace('res://'+rel+'/dampen_qualified/','res://'+rel+'/campaign/')
 driver=out/source.name;driver.write_text(text);log=out/f'{name}.log';began=time.time()
 print('RUN',name,flush=True)
 with log.open('w') as stream:
  result=subprocess.run(['flatpak','run','org.godotengine.Godot','--headless','--path',str(root),'--script',str(driver)],cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
 raw=log.read_text();drift=changes(start,snapshot(root))
 passed=result.returncode==0 and 'PASS' in raw and not any(x in raw for x in ['FAIL','SCRIPT ERROR:','ERROR:']) and not drift
 report['tests'].append(dict(name=name,passed=passed,seconds=round(time.time()-began,2),log=str(log.relative_to(root)),source_changes=drift,driver_sha256=sha(driver),source_sha256=sha(source)))
 receipt.write_text(json.dumps(report,indent=1)+'\n');print('PASS' if passed else 'FAIL',name,flush=True)
 if not passed:raise SystemExit(1)
report['source_after']=snapshot(root);assert not changes(start,report['source_after'])
report['saves']={str(q.relative_to(root)):sha(q) for q in out.glob('*save.json')}
report['complete']=True;receipt.write_text(json.dumps(report,indent=1)+'\n')
with (out/'milestone_assertions.log').open('w') as log:
 result=subprocess.run(['flatpak','run','org.godotengine.Godot','--headless','--path',str(root),'--script','tests/act2_silverleaf_earned_loop_test.gd','--','--receipt=res://'+rel+'/route_report.json'],cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=120)
raw=(out/'milestone_assertions.log').read_text()
assert result.returncode==0 and 'PASS' in raw and not any(x in raw for x in ['FAIL','SCRIPT ERROR:','ERROR:'])
assert not changes(start,snapshot(root))
report['milestone_passed']=True;receipt.write_text(json.dumps(report,indent=1)+'\n')
print('PASS act2_silverleaf_earned_loop_test:29 earned stages, source stable; receipt',receipt,flush=True)
