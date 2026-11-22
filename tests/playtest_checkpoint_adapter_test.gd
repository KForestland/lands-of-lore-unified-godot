extends SceneTree
## Synthetic health/validation probes only; never menu content or earned evidence.
const Save=preload("res://scripts/lol2/game_save.gd")
const Starts=preload("res://scripts/lol2/playtest_starts.gd")
const Session=preload("res://scripts/lol2/game_session.gd")
func _initialize() -> void:run.call_deferred()
func loaded() -> Node:
	for i in 1800:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review") == true and is_instance_valid(current_scene.get("starting_magic")) and Session.for_tree(self).pending_resume.is_empty():
			current_scene.process_mode=Node.PROCESS_MODE_DISABLED
			return current_scene
	assert(false,"checkpoint destination ready")
	return null
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	var session: Node=Session.for_tree(self);session.set_process(false)
	var path:="res://tests/fixtures/saves_d5da60a/areas/L10_DC.json"
	var pin:=FileAccess.get_sha256(path)
	var packet: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));packet.inventory.health=9
	var before: Dictionary=packet.duplicate(true)
	assert(not Save.resume_checkpoint(self,"L1_DC",packet,true).is_empty())
	assert(current_scene==null and session.pending_resume.is_empty() and not has_meta("lol2_slot_resume"))
	var bad: Dictionary=packet.duplicate(true);bad.inventory.health=-1
	assert(not Save.resume_checkpoint(self,"L10_DC",bad,true).is_empty(),"validate before healing, never mask a bad packet")
	var maps: Array=Starts.manifest().entries.filter(func(e):return e.resume=="map")
	var row: Dictionary=maps[0].duplicate(true);row.area_id="../../x"
	assert(Starts.entry_error(row)=="unknown playtest map")
	row=maps[0].duplicate(true);row.act=3
	assert(Starts.entry_error(row)=="map act disagrees with area")
	row=maps[0].duplicate(true);row.full_health=false
	assert(Starts.entry_error(row).contains("full_health"))
	row=maps[0].duplicate(true);row.sha256="0".repeat(64)
	assert(Starts.file_error(row).contains("sha256"),"wrong pin cannot qualify")
	for heal in [false,true]:
		assert(Save.resume_checkpoint(self,"L10_DC",packet,heal).is_empty())
		await scene_changed
		var scene: Node=await loaded()
		assert(session.pending_resume.is_empty() and not session.changing_scene)
		assert(scene.starting_magic.health()==(30 if heal else 9))
		assert(packet==before and FileAccess.get_sha256(path)==pin,"source packet remains unchanged")
		assert(not scene.adapter_exit_seeds and scene.progression.seeds_applied.is_empty())
	# Ordinary slot read/load retains9; only the dedicated checkpoint copy can heal.
	var doc:=Save.make_document(current_scene,2);doc.area_save.inventory.health=9
	assert(Save.write_document(Save.slot_path(2),doc).is_empty())
	assert(Save.load(self,2).is_empty());await scene_changed
	var scene: Node=await loaded()
	assert(scene.starting_magic.health()==9,"ordinary slot load never heals")
	current_scene.free();current_scene=null
	print("PASS C-15 detached full-health adapter; optional no-heal and ordinary slot preserve health; map/act/pin/bad-state refusals before mutation")
	quit()
