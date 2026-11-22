#!/usr/bin/env python3
"""Throwaway ownership probes. No production files or golden saves are mutated."""
import importlib.util,json,tempfile
from pathlib import Path
p=Path(__file__).with_name('check_item_grant_ownership.py');spec=importlib.util.spec_from_file_location('guard',p);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
root=p.parents[1];policy=json.loads((root/'tools/item_grant_ownership_policy.json').read_text())
probes=[
 ('direct','host.carried_collected.append(id)','fail'),
 ('alias','var p = host.carried_collected\n p.append(id)','fail'),
 ('argument','unlisted(host.carried_collected)','fail'),
 ('api_alias','Alias.pack(host).append(id)','fail'),
 ('erase','Alias.pack(host).erase(id)','remove'),
 ('get_alias','var p = host.get("carried_collected")\n p.append(id)','fail'),
 ('get_hive','host.get("carried_inventory").collected.append(id)','fail'),
 ('builder','x.duplicate().append(id)','pass'),
 ('fresh_copy','var p = host.carried_collected.duplicate()\n p.append(id)','pass'),
 ('stringname','var p = host.get(&"carried_collected")\n p.push_back(id)','fail'),
 ('dictionary_wrapper','unlisted({"odd_parameter":host.carried_collected})','fail'),
 ('shallow_dictionary','var p = host.carried_inventory.duplicate()\n p.collected.append(id)','fail'),
 ('deep_dictionary','var p = host.carried_inventory.duplicate(true)\n p.collected.append(id)','pass'),
 ('shallow_field_replace','var p = host.carried_inventory.duplicate()\n p.collected = []','pass'),
 ('array_index','var p = host.carried_collected\n p[0] = id','fail'),
 ('assign_plus','host.carried_collected += [id]','fail'),
 ('deferred','host.set_deferred(&"carried_collected",[id])','fail'),
 ('comments_strings','var text = "host.carried_collected.append(id)" # host.carried_inventory.collected.append(id)','pass'),
]
def main():
 failed,_,_=g.check(root,policy);assert not failed,failed
 with tempfile.TemporaryDirectory(prefix='lol2-item-ownership-') as tmp:
  mirror=Path(tmp)
  for source in (root/'scripts/lol2').rglob('*.gd'):
   target=mirror/source.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(source)
  probe=mirror/'scripts/lol2/f08_throwaway_owner.gd'
  for name,body,expect in probes:
   probe.write_text('extends RefCounted\nconst Alias=preload("res://scripts/lol2/item_grants.gd")\nfunc run(host,id,x):\n '+body.replace('\n','\n ')+'\n')
   failed,removed,_=g.check(mirror,policy)
   own=[row for key,row in failed if key.startswith('scripts/lol2/f08_throwaway_owner.gd::')]
   assert bool(own)==(expect=='fail'),(name,expect,failed)
   if expect=='remove':
    assert any(key.startswith('scripts/lol2/f08_throwaway_owner.gd::') for key,row in removed),name
    strict,_,_=g.check(mirror,policy,True)
    assert any(key.startswith('scripts/lol2/f08_throwaway_owner.gd::') for key,row in strict),name
   print('PASS ownership probe',name,expect)
 print('PASS %d throwaway live-store/alias/argument/copy probes'%len(probes))
 return 0
if __name__=='__main__':raise SystemExit(main())
