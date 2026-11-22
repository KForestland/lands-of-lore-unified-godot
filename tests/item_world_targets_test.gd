extends SceneTree
const C=preload("res://scripts/lol2/item_catalog.gd")
const T=preload("res://scripts/lol2/item_world_targets.gd")
func _initialize():
 assert(T.TARGETS.size()==19)
 for index in T.TARGETS:
  var id:String=C.generic_id(index)
  assert(not C.target_hint(id).is_empty())
  assert(C.use_kind(id).is_empty(),"Selecting a target is not consumable dispatch")
  assert(id not in C.consumables(),"A held quest item cannot enter generic spent history")
 for index in [103,104,106,169]:assert(C.target_hint(C.generic_id(index)).is_empty(),"Unknown target is not guessed")
 assert(C.target_hint(C.Monastery.FLUTE).is_empty() and C.use_kind(C.Monastery.FLUTE).is_empty(),"Existing Act1 Play remains intact")
 assert(C.target_hint("act2:L10_DC:item44:charged:yellow")==T.hint(99))
 print("PASS nineteen known target definitions, no fake consumption/native dispatch; four unknown exclusions, canonical flute compatibility")
 quit()
