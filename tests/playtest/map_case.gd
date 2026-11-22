extends SceneTree
## C-15 load/UI proof only: immutable earned-test checkpoints, no walking claim.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const Session = preload("res://scripts/lol2/game_session.gd")
const Health = preload("res://scripts/lol2/player_health.gd")
var results := []
func rendered() -> bool: return false
func areas() -> Array: return Starts.Areas.PROGRESSION_AREAS
func _initialize() -> void: run.call_deferred()
func tap(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame; await process_frame
func saves() -> Dictionary:
	var found := {}; var dir := DirAccess.open("user://saves")
	if dir != null:
		for file in dir.get_files(): found[file]=FileAccess.get_sha256("user://saves/"+file)
	return found
func new_gate() -> Node:
	var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	gate.settings_path="user://tests/c15_%d.cfg"%Time.get_ticks_usec()
	root.add_child(gate); current_scene=gate
	for i in 3: await process_frame
	gate.path_field.text=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	return gate
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	assert((DisplayServer.get_name()!="headless")==rendered())
	var session: Node=Session.for_tree(self); session.set_process(false)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file:=FileAccess.open("user://saves/c15_sentinel.json",FileAccess.WRITE); file.store_string("owner-save-sentinel");file.close()
	var before:=saves();var listed:=Starts.manifest();assert(listed.error.is_empty(),listed.error)
	var maps: Array=listed.entries.filter(func(e):return e.resume=="map")
	assert(maps.size()==10)
	var seen := {}
	for entry in maps:
		assert(not seen.has(entry.area_id));seen[entry.area_id]=true
		assert(Starts.file_error(entry).is_empty())
		var read:=Starts.read(entry);assert(read.error.is_empty(),str(read.error));assert(Starts.identity_error(entry,read.state).is_empty())
		assert(read.state.format==Starts.format_for(entry) and entry.full_health)
	assert(seen.size()==Starts.Areas.PROGRESSION_AREAS.size())
	for area in areas():
		var entry: Dictionary=maps.filter(func(e):return e.area_id==area)[0]
		var raw:=Starts.read(entry);var incoming: Dictionary=raw.state.duplicate(true)
		var gate:=await new_gate()
		await tap(KEY_F2)
		assert(gate.starts_panel.visible)
		var button: Button=gate.starts_panel.find_child("Start_"+entry.id,true,false)
		assert(button!=null and not button.disabled)
		button.grab_focus();for i in 3:await process_frame
		if rendered():
			await RenderingServer.frame_post_draw
			var rect:=button.get_global_rect();assert(root.get_visible_rect().intersects(rect),"focused row scrolls into view")
			var directory:="user://tests/c15/";DirAccess.make_dir_recursive_absolute(directory)
			assert(root.get_texture().get_image().save_png(directory+area+"_list.png")==OK)
		await tap(KEY_ENTER) # Actual F2 list button activation through normal GUI dispatch.
		var scene: Node
		for i in 1800:
			await process_frame
			if current_scene!=gate and is_instance_valid(current_scene):
				scene=current_scene
				if session.pending_resume.is_empty() and not session.changing_scene:break
		assert(scene!=null and scene.scene_file_path==Starts.scene_for(entry),area+" F2 resumes expected scene")
		scene.process_mode=Node.PROCESS_MODE_DISABLED # Hold clocks after apply for exact checkpoint comparisons.
		assert(session.pending_resume.is_empty() and not session.changing_scene and not has_meta("lol2_slot_resume"))
		assert(not scene.adapter_exit_seeds and scene.progression.seeds_applied.is_empty(),"no preview seeds")
		assert(scene.starting_magic.health()==Health.MAXIMUM,area+" full health")
		var expected_pack: Array=incoming.inventory.collected.duplicate()
		for item in incoming.quests.get("act2_items",{}).get("carried",[]):
			if item not in expected_pack:expected_pack.append(item)
		assert(scene.carried_collected==expected_pack,area+" earned legacy + Act2 pack unchanged")
		assert(scene.equipped_item==incoming.inventory.equipped_item and scene.equipped_armor==incoming.inventory.equipped_armor)
		var at: Array=incoming.player.position
		assert(Vector2(scene.player.position.x-at[0],scene.player.position.z-at[2]).length()<2.0,area+" saved horizontal pose (normal gravity may settle Y): "+str(scene.player.position))
		assert(scene.resets==0,"no arrival fall reset")
		assert(Starts.read(entry).state==incoming and FileAccess.get_sha256(Starts.save_path(entry))==entry.sha256,"pinned bytes/health unchanged")
		if rendered():
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("user://tests/c15/"+area+"_loaded.png")==OK)
		results.append({"area":area,"id":entry.id,"sha256":entry.sha256,"before_health":incoming.inventory.health,"health":scene.starting_magic.health(),"scene":scene.scene_file_path,"preview_seeds":scene.progression.seeds_applied.duplicate(),"real_F2_Enter":true})
		print("C15 START ",area," health=",scene.starting_magic.health()," original=",incoming.inventory.health)
		scene.free();current_scene=null
		for i in 3:await process_frame
	assert(saves()==before,"private starts do not write save files while autosave is disabled")
	var folder:="user://tests/c15/";DirAccess.make_dir_recursive_absolute(folder)
	file=FileAccess.open(folder+("rendered"if rendered()else"headless")+"_receipt.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases":results,"all10_staged_pinned_valid":true,"owner_saves_unchanged":true,"scope":"Load/UI proof. Private autosave disabled and post-apply clocks held, no earned-walk claim. Checkpoint producer aids are disclosed in the manifest."},"  "));file.close()
	print("PASS C-15 ",results.size()," real F2/Enter starts; all10 earned pins validate; full health, no preview seeds, pack/pose/pins/user saves preserved; rendered=",rendered())
	quit()
