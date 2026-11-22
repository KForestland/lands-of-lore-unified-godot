extends SceneTree
const Rules=preload("res://tests/foundation/save_source_rules.gd")
func _initialize()->void:
	var errors:Array[String]=_scan("res://scripts/lol2")
	assert(errors.is_empty(),"\n".join(errors))
	_verify_probes()
	print("PASS source guard: one session holder, no new host save writers, named legacy writers and exact old view.json audit line retained; negative source probes")
	quit()
func _scan(directory:String)->Array[String]:
	var errors:Array[String]=[]
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".gd"):continue
		var path:=directory.path_join(file)
		errors.append_array(Rules.problems(path,FileAccess.get_file_as_string(path)))
	for folder in DirAccess.get_directories_at(directory):errors.append_array(_scan(directory.path_join(folder)))
	return errors
func _verify_probes()->void:
	assert(not Rules.problems("act2_map.gd","func copied_writer():\n\tFileAccess.open(path,FileAccess.WRITE)").is_empty())
	assert(not Rules.problems("act2_map.gd","func copied_save():\n\tSave.write_save(path,state)").is_empty())
	assert(not Rules.problems("other.gd","const BANK_META := \"lol2_act2_native_bank\"").is_empty())
	assert(not Rules.problems("other.gd","tree.get_meta(\"lol2_adapter_exit_seeds\")").is_empty())
	assert(Rules.problems("cave_walkthrough.gd","func _quicksave_unrecorded():\n\tWalkthroughSave.write_save(path,state)").is_empty())
