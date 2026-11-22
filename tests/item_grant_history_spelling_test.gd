extends SceneTree
const Fixtures=preload("res://tests/helpers/item_grant_history_fixtures.gd")
const FILE:="res://tests/fixtures/item_grant_history_baseline_20c7797.json"
func _initialize():run.call_deferred()
func semantic_record(value:Dictionary)->Dictionary:
 # Guard text, file and actual refusal/packet stay pinned. A preload changes
 # line numbers without changing behavior; preserve raw live citations in any
 # diagnostic, compare only their verified source file in the semantic record.
 var result:Dictionary=value.duplicate(true)
 for row in result.cases.values():
  if not row.has("second_call_blocked"):continue
  var parts:PackedStringArray=str(row.second_call_blocked.source).split(":")
  assert(parts.size()==2 and parts[1].is_valid_int() and int(parts[1])>0,"Guard requires a real file:line citation")
  row.second_call_blocked.source=parts[0]
 return result
func run():
 var census:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_grant_census_742dcab.json"))
 var rows:Dictionary={}
 for row in census.functions:
  if row.has("history"):rows[str(row.file).get_file()+"::"+str(row.function)]=row.history.guard
 assert(rows==Fixtures.CASES and rows.size()==24,"Every table2.9 row has an exact runtime case; no omitted rows")
 var cases:Dictionary=Fixtures.run_history(self)
 assert(cases.size()==24)
 var observed:Dictionary=Fixtures.Sites.canonical({"version":1,"base":"20c7797","scope":"Original production methods/pure builders, explicit isolated state/spatial/view fixtures; not earned evidence","cases":cases})
 if OS.get_environment("LOL2_WRITE_ITEM_BASELINES")=="1":
  var file:=FileAccess.open(FILE,FileAccess.WRITE);file.store_string(JSON.stringify(observed,"  ",true,true)+"\n");file.close()
 assert(FileAccess.file_exists(FILE),"Generate and review the original baseline before any migration")
 var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FILE))
 if semantic_record(expected)!=semantic_record(observed):
  DirAccess.make_dir_recursive_absolute("user://tests")
  var diagnostic:=FileAccess.open("user://tests/item_grant_history_spelling_observed.json",FileAccess.WRITE)
  diagnostic.store_string(JSON.stringify(observed,"  ",true,true)+"\n");diagnostic.close()
 assert(semantic_record(expected)==semantic_record(observed),"Every original history packet/order/refusal/repeat and guard text/file must remain identical; citation line offsets are informational")
 print("PASS 24 exact history sites x normal/prehistory/full64, always repeat paths or asserted guards, full packet and sync order pinned")
 quit()
