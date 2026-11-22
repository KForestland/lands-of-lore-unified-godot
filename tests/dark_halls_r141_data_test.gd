extends SceneTree
const Crates=preload("res://scripts/lol2/dark_halls_crates.gd")
func _initialize():run.call_deferred()
func run():
 var missing:="user://tests/r141_deliberately_missing.json"
 if FileAccess.file_exists(missing):DirAccess.remove_absolute(missing)
 assert(not Crates.decoration_data(missing).error.is_empty(),"Missing optional source gives a named setup error, not a nil assignment")
 DirAccess.make_dir_recursive_absolute("user://tests")
 var path:="user://tests/r141_invalid_decoration.json"
 for text in ["[]","{\"boxes\":[]}","{\"boxes\":{\"1\":false}}"]:
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
  assert(not Crates.decoration_data(path).error.is_empty(),"Malformed decoration shape is refused without a runtime error")
 var good:Dictionary=Crates.decoration_data("res://scripts/lol2/static_collision_L7_DH.json")
 assert(good.error.is_empty() and not good.boxes.is_empty(),"Actual exported source schema loads")
 print("PASS R141b real file IO: missing/wrong-type/wrong-row decoration data gives named errors; actual source loads without a nil assignment")
 quit()
