extends SceneTree
## Private project intentionally omits one Museum image, not the shared checkout.
const Save = preload("res://scripts/lol2/game_save.gd")
const Session = preload("res://scripts/lol2/game_session.gd")
const Cases = preload("res://tests/helpers/game_save_cases.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1")
	assert(not FileAccess.file_exists("res://assets/lol2/generated/museum_broken_thohan/sword_0.png"))
	var session: Node = Session.for_tree(self)
	session.set_process(false)
	var doc := Cases.document("L3_DH")
	assert(Save.Areas.validate_area("L3_DH",doc.area_save).is_empty())
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file := FileAccess.open(Save.Areas.ROWS.L3_DH.legacy,FileAccess.WRITE)
	file.store_string(JSON.stringify(doc.area_save)); file.close()
	assert(Save.read_legacy("L3_DH").error.is_empty(), "valid old save, missing assets only")
	var previous := Node.new(); root.add_child(previous); current_scene = previous
	set_meta("lol2_museum_checkpoint", {"keep":true})
	var prior: Dictionary = session.runtime_checkpoint()
	var panel = preload("res://scripts/lol2/save_slots_panel.gd").new()
	root.add_child(panel)
	var button: Button = panel.rows.get_node("Legacy_L3_DH")
	assert(not button.disabled)
	# Actual UI event dispatch to the Old save button (headless GUI input, not a direct handler call).
	root.size = Vector2i(1280,720)
	for i in 5: await process_frame
	button.grab_focus()
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	assert(panel.message.text.contains("Museum") and panel.message.text.contains("assets are missing"), panel.message.text)
	assert(current_scene == previous and previous.is_inside_tree())
	assert(session.runtime_checkpoint() == prior and get_meta("lol2_museum_checkpoint") == {"keep":true}, "asset refusal precedes mutation")
	assert(not session.changing_scene and session.pending_resume.is_empty() and not has_meta("lol2_slot_resume"))
	# The same guard protects ordinary slot loads, not only the old-save button.
	assert(Save.write_document(Save.slot_path(4),doc).is_empty())
	assert(Save.load(self,4).contains("assets are missing") and current_scene == previous)
	panel.free(); previous.free(); current_scene = null
	print("PASS real Old save UI rejects missing Museum assets before scene/session mutation; slot load shares guard")
	quit()
