extends SceneTree
## Save-boundary probe: valid legacy packet, admitted host without a native VM.
## This is not evidence of playable partially staged L9 geometry/owners.
const Save = preload("res://scripts/lol2/game_save.gd")
const Cases = preload("res://tests/helpers/game_save_cases.gd")
class HostWithoutNative extends Node:
	var progression: Node = null
	var adapter_exit_seeds := false
	var packet: Dictionary
	var feedback := ""
	func area_snapshot() -> Dictionary: return packet.duplicate(true)
	func can_save() -> String: return "" # Isolate the envelope's missing-VM refusal from other admission.
	func save_feedback(text: String) -> void: feedback = text
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1")
	assert(not FileAccess.file_exists("res://scripts/lol2/native_scripts/L9_DR.json"))
	var scene := HostWithoutNative.new()
	scene.scene_file_path = Save.Areas.ROWS.L9_DR.scene
	scene.packet = Cases.document("L9_DR").area_save
	root.add_child(scene); current_scene = scene
	var error: String = Save.quicksave(scene)
	assert(error.contains("Dracoid Ruins") and error.contains("native scripts to be staged"), error)
	assert(scene.feedback == "Save failed: "+error, "player sees the reason")
	assert(not FileAccess.file_exists(Save.slot_path(1)), "refusal leaves slots alone")
	var legacy := "user://legacy_partial_stage.json"
	assert(preload("res://scripts/lol2/act2_save.gd").write_save(legacy,scene.packet,Save.Areas.ROWS.L9_DR.format).is_empty())
	assert(Save.read_legacy("L9_DR",legacy).error.is_empty(), "legacy packet remains readable")
	var session = preload("res://scripts/lol2/game_session.gd").for_tree(self)
	assert(Save.autosave(scene,"arrival").is_empty())
	for i in 3000:
		await process_frame
		session._finish_autosave()
		if not session.save_in_progress(): break
	assert(session.last_autosave_error == error and session.autosave_writes == 0)
	scene.free(); current_scene = null
	print("PASS missing-VM save boundary: manual feedback/autosave explain native scripts, preserve slots, keep legacy packet readable")
	quit()
