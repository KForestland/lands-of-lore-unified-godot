extends SceneTree
const Freeze=preload("res://scripts/lol2/l16_fountain_freeze.gd")
const Registry=preload("res://scripts/lol2/area_owner_registry.gd")
func _initialize():
 assert(Freeze.validate(Freeze.initial()).is_empty())
 assert(Freeze.validate({"version":1.0,"frozen":true}).is_empty())
 for bad in [null,{}, {"version":true,"frozen":false}, {"version":1.25,"frozen":false}, {"version":1,"frozen":0}, {"version":1,"frozen":false,"chip":true}]:
  assert(not Freeze.validate(bad).is_empty(),"Malformed freeze never enters save")
 assert(Registry.validate_all_quests({}).is_empty(),"Older saves need no invented freeze key")
 assert(not Registry.validate_all_quests({Freeze.KEY:{"version":1,"frozen":1}}).is_empty(),"Registered whole-game validation includes new key")
 print("PASS G15 source626 freeze schema, optional legacy key and integrated malformed-save refusal")
 quit()
