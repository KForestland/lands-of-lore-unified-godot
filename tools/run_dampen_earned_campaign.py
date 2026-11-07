#!/usr/bin/env python3
"""Reproduce and qualify the separate earned Dawn-charm Act2 branch headlessly."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from regression_source import snapshot,changes
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=Path('tmp/dampen_qualified'));p.add_argument('--generate-only',action='store_true');p.add_argument('--resume',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=(root/a.output).resolve();rel=out.relative_to(root).as_posix();assert rel.startswith('tmp/')
out.mkdir(parents=True,exist_ok=True)
previous=json.loads((out/'qualification_report.json').read_text()) if a.resume else None
if previous:assert not changes(previous['source_before'],snapshot(root)), 'Production source changed since prior stages'
fixture=root/'tests/fixtures/dampen_campaign_drivers.json';spec=json.loads(fixture.read_text());names=[Path(x['source']).name for x in spec['drivers']];manifest=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for row in spec['drivers']:
 src=root/row['source'];assert sha(src)==row['source_sha256'],f'Changed source driver {src}'
 text=src.read_text().replace('res://tmp/','res://tmp/dampen_campaign/')
 for name in names:text=text.replace('extends "res://tests/'+name+'"','extends "res://tmp/dampen_campaign/'+name+'"')
 lines=text.splitlines(True)
 for patch in reversed(row['patches']):
  assert ''.join(lines[patch['start']:patch['end']])==patch['old'];lines[patch['start']:patch['end']]=[patch['new']]
 text=''.join(lines).replace('res://tmp/dampen_campaign/','res://'+rel+'/')
 if src.name=='l9_statue_follow_earned_test.gd':
  anchor=' var walker=scene.get_node("L9StatueWalk")'
  addition=''' var charm=preload("res://scripts/lol2/monastery_conversation.gd").DAMPEN
 if not check(charm in scene.carried_collected and scene.player_form==0,"actual Dawn charm arrived with Human player"):quit(1);return
 if not check(scene.open_inventory(),"open real inventory for earned charm"):quit(1);return
 await process_frame
 var inv=scene.inventory;var choice:=-1
 for i in inv.item_list.item_count:
  if str(inv.item_list.get_item_metadata(i))==charm:choice=i
 if not check(choice>=0,"actual carried charm appears in inventory"):quit(1);return
 inv.select_item(choice);inv.use_button.pressed.emit();await process_frame
 if is_instance_valid(inv):inv.queue_free()
 await process_frame
 check(scene.item_effects.state().get("dampened",false) and charm not in scene.carried_collected,"charm consumed and saved effect set")
'''
  assert text.count(anchor)==1;text=text.replace(anchor,addition+anchor)
  anchor=' check(not walker.begin_fight(),"fight cannot repeat after reload")'
  text=text.replace(anchor,anchor+'\n check(scene.item_effects.state().get("dampened",false) and charm in scene.item_effects.state().spent and charm not in scene.carried_collected,"earned charm consumption persists after follow and reload")')
  text=text.replace('Dampen spell not qualified by this slice','earned Dawn charm consumed and retained as spent; no spontaneous warning or persistent immunity claimed')
 dest=out/src.name;dest.write_text(text);manifest.append(dict(source=row['source'],source_sha256=sha(src),driver=str(dest.relative_to(root)),driver_sha256=sha(dest)))
(out/'driver_manifest.json').write_text(json.dumps(dict(fixture_sha256=sha(fixture),drivers=manifest),indent=1)+'\n')
if a.generate_only:print(f'Generated {len(manifest)} pinned earned drivers in {rel}');raise SystemExit()
ordered=['l10_gate','l10_catacomb','l10_gold','l10_ruins_departure','l8_pit','l9_opening','l9_bridge','l9_tower_approach','l9_tower_upper','l9_bracers','l9_mirror_return','l10_two_empty','l9_two_white','l9_white_return','l10_barrel','l10_oil','l10_blue','l10_priest','l9_chapel','l9_ashes','l10_ashes_return','l10_ankh','l10_emperor_supply','l10_emperor','l9_emperor_arrival','l9_statue','l9_statue_follow']
before=snapshot(root);report=dict(scope='Continuous separate Dawn-charm earned Act2 branch from qualified departure. No save edits/inventory merges. Synthetic warning and spell immunity are not claimed.',source_before=before,drivers=manifest,tests=[],complete=False)
completed=0
if previous:
 for test in previous['tests']:
  if not test['passed']:break
  assert test['name']==ordered[completed];completed+=1
 allowed={str((out/(name+'_earned_test.gd')).relative_to(root)) for name in ordered[completed:]}
 old={x['driver']:x['driver_sha256'] for x in previous['drivers']}
 assert all(x['driver_sha256']==old[x['driver']] or x['driver'] in allowed for x in manifest), 'A completed driver/dependency changed'
 if completed:
  for name,digest in previous['tests'][completed-1]['saves'].items():assert sha(out/name)==digest, f'Earned save changed: {name}'
 report['tests']=previous['tests'][:completed]
 failed=previous['tests'][completed:]
 for test in failed:
  old_log=root/test['log'];saved_log=old_log.with_suffix('.before_resume.log');saved_log.write_bytes(old_log.read_bytes());test['log']=str(saved_log.relative_to(root))
 report['prior_attempts']=previous.get('prior_attempts',[])+[dict(drivers=previous['drivers'],tests=failed)]
 (out/'qualification_report.before_resume.json').write_text(json.dumps(previous,indent=1)+'\n')
for index,name in enumerate(ordered,1):
 if index<=completed:continue
 script=out/(name+'_earned_test.gd');log=out/f'{index:02}_{name}.log';start=time.time();print('RUN',name,flush=True)
 with log.open('w') as f:
  try:code=subprocess.run(['flatpak','run','org.godotengine.Godot','--headless','--path',str(root),'--script',str(script)],cwd=root,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
  except subprocess.TimeoutExpired:code=124
 text=log.read_text();drift=changes(before,snapshot(root));driver_drift=[x['driver'] for x in manifest if sha(root/x['driver'])!=x['driver_sha256']]
 ok=code==0 and 'PASS' in text and not any(x in text for x in ['FAIL','SCRIPT ERROR:','ERROR:']) and not drift and not driver_drift
 report['tests'].append(dict(name=name,passed=ok,returncode=code,seconds=round(time.time()-start,2),log=str(log.relative_to(root)),source_changes=drift,driver_changes=driver_drift,saves={q.name:sha(q) for q in out.glob('*save.json')}))
 (out/'qualification_report.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS' if ok else 'FAIL',name,flush=True)
 if not ok:raise SystemExit(1)
report['complete']=True;report['source_after']=snapshot(root);(out/'qualification_report.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS continuous earned Dawn charm campaign, source stable',flush=True)
