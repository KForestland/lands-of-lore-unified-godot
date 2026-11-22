extends SceneTree
const Registry = preload("res://scripts/lol2/area_owner_registry.gd")
const Save = preload("res://scripts/lol2/act2_save.gd")
const FIXTURES := "res://tests/fixtures/area_owners_d5da60a/"
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  print("FAIL: ", message)
func _initialize() -> void:
 var checked := 0
 for area in Registry.AREAS:
  var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + area + "_save.json"))
  var error := Registry.validate_all_quests(state.quests)
  check(error.is_empty(), area + " unchanged legacy save: " + error)
  check(Save.validate(state, state.format).is_empty(), area + " integrated save validator")
  checked += 1
 for family in ["cave", "museum", "hive", "jungle", "act2"]:
  var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/" + family + ".json"))
  var quests: Dictionary = state.get("quests", state.get("quest_state", {}))
  var error := Registry.validate_all_quests(quests)
  check(error.is_empty(), family + " d5 writer fixture: " + error)
  checked += 1
 # Every applicable owner validator rejects a present malformed packet; missing keys stay optional.
 var seen := {}
 for area in Registry.AREAS:
  var registry := Registry.new()
  check(registry.prepare(area).is_empty(), area + " prepare")
  for row in Registry.definition_for(area).get_script_constant_map().OWNERS:
   var path: String = "res://scripts/lol2/" + row.script
   if seen.has(path): continue
   var script: Script = load(path)
   var key: String = row.get("key", Registry.constants_for(script).get("KEY", ""))
   if key.is_empty() or Registry.method(script, row.get("validate", "validate")).is_empty(): continue
   seen[path] = key
   check(not registry.validate_quests({key: null}).is_empty(), row.script + " null state must be refused")
   check(not Save.quests_error({key: null}).is_empty(), row.script + " integrated validator must refuse null")
  registry.free()
 check(seen.get("res://scripts/lol2/generic_object_world.gd", "") == "generic_objects", "GenericObjects validator is explicitly covered")
 check(seen.size() == 80, "owner validator coverage: " + str(seen.size()))
 check(not Registry.validate_all_quests([]).is_empty(), "invalid outer quests")
 check(Registry.validate_all_quests({}).is_empty(), "missing owner keys remain optional")
 print("VALIDATED ", checked, " pinned writer saves; malformed-key validators=", seen.size())
 if failures == 0: print("PASS area owner validation: legacy fixtures accepted, present invalid keys refused, absent keys optional")
 quit(0 if failures == 0 else 1)
