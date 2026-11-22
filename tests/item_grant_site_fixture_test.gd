extends SceneTree
const Fixtures=preload("res://tests/helpers/item_grant_site_fixtures.gd")
const FILE:="res://tests/fixtures/item_grant_site_baseline_20c7797.json"
func _initialize():run.call_deferred()
func run():
 var cases:Dictionary=Fixtures.run_sites(self)
 assert(cases.size()==Fixtures.SITE_NAMES.size()*2,"Every named site has normal and full64 cases")
 for name in Fixtures.SITE_NAMES:
  for variant in ["normal","full64"]:assert(cases.has(name+":"+variant),"Missing site "+name+":"+variant)
  var normal:Dictionary=cases[name+":normal"]
  assert(normal.before!=normal.after,"Normal production grant must change its pinned observation: "+name)
  var full:Dictionary=cases[name+":full64"]
  if name in ["kityara_knife","hive_wax"]:assert(full.after.pack.size()==65,"Existing uncapped site still succeeds at64: "+name)
  elif name=="cave_guard38_loot":assert(full.before.pack==[] and full.after.pack==["cave:guard38:Short_Sword"],"Cave pack remains derived from owner, uncapped")
  else:assert(full.before.pack==full.after.pack,"Full64 refusal preserves pack: "+name)
 var observed:Dictionary={"version":1,"base":"20c7797","scope":"Original production methods; isolated spatial/presentation doubles; no real-input or earned claim","cases":cases}
 observed=Fixtures.canonical(observed)
 if OS.get_environment("LOL2_WRITE_ITEM_BASELINES")=="1":
  var file:=FileAccess.open(FILE,FileAccess.WRITE);file.store_string(JSON.stringify(observed,"  ",true,true)+"\n");file.close()
 assert(FileAccess.file_exists(FILE),"Pin baseline before migrations; explicit generation only")
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FILE))
 assert(expected==observed,"Site values/order/refusal/repeat/feedback/Journal must match frozen production baseline")
 print("PASS 13 original grant sites x normal/full64, before/after/repeat: pack/packet/owner/text/Journal/equipment/HUD/sync order")
 quit()
