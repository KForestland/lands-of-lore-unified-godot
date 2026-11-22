extends RefCounted
## Whole-game envelope; each area remains responsible for its own packet/version.
const Globals=preload("res://scripts/lol2/game_native_globals.gd")
const Areas = preload("res://scripts/lol2/game_areas.gd")
const Session = preload("res://scripts/lol2/game_session.gd")
const CURRENT := 3
const MIGRATIONS := [{"from":1,"to":2,"apply":"session_options"},{"from":2,"to":3,"apply":"world_cells"}]
const FORMAT := "lol2-game"
const MAX_BYTES := 8 * 1024 * 1024
const PART_BYTES := 4 * 1024 * 1024
const ROOT := "user://saves/"
const AUTOSAVE := 0

static func slot_path(id: int) -> String:
	if id == AUTOSAVE: return ROOT + "autosave.json"
	return ROOT + "slot_%02d.json" % id if id >= 1 and id <= 10 else ""
static func backup_path(id: int) -> String: return slot_path(id).get_basename() + ".bak" if not slot_path(id).is_empty() else ""
static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 315537897599
static func _session_error(value: Variant) -> String:
	if not value is Dictionary or not value.get("options") is Dictionary or not value.options.get("adapter_exit_seeds") is bool: return "Invalid saved session."
	var slot: Variant = value.get("last_slot", 1)
	if not _number(slot) or slot != int(slot) or slot < 1 or slot > 10: return "Invalid last save slot."
	return ""

static func migrate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format") != FORMAT: return {"error":"This is not a whole-game save."}
	var version: Variant = value.get("version")
	if not _number(version) or version != int(version): return {"error":"Invalid save version."}
	if version > CURRENT: return {"error":"This save needs a newer version of the game."}
	if version < 1: return {"error":"Unsupported save version."}
	var doc: Dictionary=value.duplicate(true)
	while int(doc.version)<CURRENT:
		var found:=false
		for step in MIGRATIONS:
			if int(step.from)!=int(doc.version):continue
			var result:=_apply_migration(step,doc)
			if not result.error.is_empty():return result
			doc=result.state;doc.version=step.to;found=true;break
		if not found:return {"error":"No migration for this save version."}
	return {"error":"", "state":doc}

static func _apply_migration(step:Dictionary,doc:Dictionary)->Dictionary:
	match step.apply:
		"session_options":
			var session:Variant=doc.get("session")
			if not session is Dictionary or not session.get("adapter_exit_seeds") is bool:return {"error":"Invalid version-1 session."}
			session["options"]={"adapter_exit_seeds":session.adapter_exit_seeds}
			session.erase("adapter_exit_seeds")
			doc.session=session
			return {"error":"","state":doc}
		"world_cells":
			var error:=Session.bank_error(doc.get("native_bank"))
			if not error.is_empty():return {"error":error}
			var cells:Variant=doc.get("native_globals",Globals.legacy(doc.native_bank,str(doc.get("area",""))))
			error=Globals.error(cells)
			if not error.is_empty():return {"error":error}
			doc.native_globals=Globals.canonical(cells)
			for area in doc.native_bank:doc.native_bank[area].locals_e58={}
			return {"error":"","state":doc}
	return {"error":"Unknown save migration."}

static func _validate_current(doc: Dictionary) -> String:
	if doc.get("format") != FORMAT or doc.get("version") != CURRENT: return "Unsupported whole-game save."
	if not doc.get("area") is String or not Areas.ROWS.has(doc.area): return "Unknown saved area."
	if not doc.get("scene") is String or doc.scene not in Areas.ROWS[doc.area].scenes: return "Save area and scene disagree."
	if not doc.get("label") is String or doc.label.is_empty() or doc.label.length() > 128: return "Invalid save label."
	if not _number(doc.get("written_unix")) or not _number(doc.get("play_seconds")): return "Invalid save time."
	if not doc.get("area_save") is Dictionary: return "Missing saved area."
	var error := Areas.validate_area(doc.area, doc.area_save)
	if not error.is_empty(): return error
	error = Session.bank_error(doc.get("native_bank"))
	if not error.is_empty(): return error
	if doc.area in Areas.PROGRESSION_AREAS and not doc.native_bank.has(doc.area): return "Native script state for %s is missing. Saves in this area require its native scripts to be staged." % Areas.ROWS[doc.area].label
	error=Globals.error(doc.get("native_globals"))
	if not error.is_empty():return error
	for area in doc.native_bank:
		if not doc.native_bank[area].locals_e58.is_empty():return "Global script cells have more than one saved owner."
	error = _session_error(doc.get("session"))
	if not error.is_empty(): return error
	if JSON.stringify(doc.area_save,"",true,true).to_utf8_buffer().size() > PART_BYTES: return "Saved area is too large."
	if JSON.stringify(doc.native_bank,"",true,true).to_utf8_buffer().size() > PART_BYTES: return "Saved level bank is too large."
	return ""

static func validate(value: Variant) -> String:
	var result := migrate(value)
	return result.error if not result.error.is_empty() else _validate_current(result.state)

static func read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error":"No save found."}
	if file.get_length() > MAX_BYTES: return {"error":"Save is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"error":"Save is damaged (invalid JSON)."}
	var result := migrate(parser.data)
	if not result.error.is_empty(): return result
	var error := _validate_current(result.state)
	return {"error":error, "state":result.state if error.is_empty() else {}}

static func write_document(path: String, doc: Dictionary) -> String:
	var error := _validate_current(doc)
	if not error.is_empty(): return error
	var bytes := (JSON.stringify(doc,"",true,true)+"\n").to_utf8_buffer()
	if bytes.size() > MAX_BYTES: return "Save is too large."
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Cannot create save folder."
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot write save."
	file.store_buffer(bytes);file.flush()
	var status := file.get_error();file.close()
	if status != OK or not read_document(temporary).error.is_empty():
		DirAccess.remove_absolute(temporary)
		return "Could not verify save; previous save preserved."
	# Stage a verified copy before rotating the backup; the primary stays intact until final rename.
	if FileAccess.file_exists(path) and read_document(path).error.is_empty():
		var backup := path.get_basename() + ".bak"
		var staged := backup + ".tmp"
		if DirAccess.copy_absolute(path, staged) != OK or FileAccess.get_sha256(path) != FileAccess.get_sha256(staged) or DirAccess.rename_absolute(staged, backup) != OK:
			DirAccess.remove_absolute(temporary);DirAccess.remove_absolute(staged)
			return "Cannot preserve the previous save."
	if DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary)
		return "Cannot replace save; previous save preserved."
	return ""

static func make_document(host: Node, slot_id: int) -> Dictionary:
	var area := Areas.id_for(host)
	if area.is_empty(): return {}
	var session: Node = Session.for_tree(host.get_tree())
	var option: Variant = host.get("adapter_exit_seeds")
	return {"format":FORMAT,"version":CURRENT,"written_unix":Time.get_unix_time_from_system(),"play_seconds":session.play_seconds,
		"label":Areas.ROWS[area].label,"area":area,"scene":host.scene_file_path,"area_save":host.area_snapshot(),
		"native_bank":session.snapshot_bank(host),"native_globals":session.snapshot_globals(host),"session":{"options":{"adapter_exit_seeds":option if option is bool else session.adapter_exit_seeds},"last_slot":slot_id if slot_id != AUTOSAVE else session.last_slot}}

static func save(host: Node, slot_id: int) -> String:
	if Session.for_tree(host.get_tree()).save_in_progress(): return "An autosave is finishing. Try again shortly."
	if slot_path(slot_id).is_empty(): return "Choose a save slot from 1 to 10."
	var error: String = host.can_save()
	if not error.is_empty(): return error
	var doc := make_document(host,slot_id)
	if doc.is_empty(): return "This area cannot be saved."
	error = write_document(slot_path(slot_id),doc)
	if error.is_empty():
		var session: Node = Session.for_tree(host.get_tree())
		session.replace_bank(doc.native_bank,doc.get("native_globals"),str(doc.area))
		session.adapter_exit_seeds = doc.session.options.adapter_exit_seeds
		if slot_id != AUTOSAVE: session.last_slot = slot_id
	return error

static func autosave(host: Node, reason: String) -> String:
	return Session.for_tree(host.get_tree()).start_autosave(host,reason)

static func _file_row(path: String) -> Dictionary:
	var row := {"exists":FileAccess.file_exists(path),"path":path,"valid":false,"error":""}
	if not row.exists: return row
	var read := read_document(path)
	row.error = read.error
	row.valid = read.error.is_empty()
	if row.valid:
		for field in ["label","area","written_unix","play_seconds","scene"]: row[field] = read.state[field]
	return row

static func slots() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in [1,2,3,4,5,6,7,8,9,10,AUTOSAVE]:
		var row := _file_row(slot_path(id));row["id"] = id;row["backup"] = _file_row(backup_path(id));rows.append(row)
	return rows

static func has_slot_files() -> bool:
	for id in [0,1,2,3,4,5,6,7,8,9,10]:
		if FileAccess.file_exists(slot_path(id)) or FileAccess.file_exists(backup_path(id)):return true
	return false

static func newest() -> Dictionary:
	var candidates := []
	for row in slots():
		if row.valid: candidates.append(row)
		elif row.backup.valid:
			var backup: Dictionary = row.backup.duplicate(true);backup["id"] = row.id;backup["use_backup"] = true;candidates.append(backup)
	candidates.sort_custom(func(a,b): return a.written_unix > b.written_unix)
	return candidates[0] if not candidates.is_empty() else {}

static func legacy_saves() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for area in Areas.ROWS:
		var definition: Dictionary = Areas.ROWS[area]
		if not FileAccess.file_exists(definition.legacy): continue
		var row := {"area":area,"label":definition.label,"path":definition.legacy,"written_unix":FileAccess.get_modified_time(definition.legacy),"legacy":true,"valid":true,"error":""}
		var read := read_legacy(area)
		row.error=read.error;row.valid=read.error.is_empty()
		rows.append(row)
	return rows

static func read_legacy(area: String, path: String = "") -> Dictionary:
	if not Areas.ROWS.has(area): return {"error":"Unknown saved area."}
	if path.is_empty(): path = Areas.ROWS[area].legacy
	match Areas.ROWS[area].kind:
		"cave": return ResourceLoader.load("res://scripts/lol2/walkthrough_save.gd").read_save(path, Areas.cave_checkpoints())
		"museum": return ResourceLoader.load("res://scripts/lol2/museum_save.gd").read_save(path)
		"hive": return ResourceLoader.load("res://scripts/lol2/hive_save.gd").read_save(path)
		"jungle": return ResourceLoader.load("res://scripts/lol2/jungle_save.gd").read_save(path,Areas.ROWS[area].format)
		_: return ResourceLoader.load("res://scripts/lol2/act2_save.gd").read_save(path,Areas.ROWS[area].format)

static func load_slot(tree: SceneTree, slot_id: int, use_backup: bool = false) -> String:
	if slot_path(slot_id).is_empty(): return "Choose a save slot."
	var session:Node=Session.for_tree(tree)
	if session!=null and not use_backup:
		var pending:Dictionary=session.pending_manual_document(slot_id)
		if not pending.is_empty():return _queue_scene(tree,pending,slot_id,false)
	var read := read_document(backup_path(slot_id) if use_backup else slot_path(slot_id))
	if not read.error.is_empty(): return read.error
	return _queue_scene(tree,read.state,slot_id,false)

static func load_legacy(tree: SceneTree, area: String) -> String:
	var read := read_legacy(area)
	if not read.error.is_empty(): return read.error
	var row: Dictionary = Areas.ROWS[area]
	var doc := {"area":area,"scene":row.scene,"area_save":read.state,"native_bank":{},"play_seconds":0.0,"session":{"options":{"adapter_exit_seeds":true},"last_slot":1}}
	return _queue_scene(tree,doc,1,true)

## F2 checkpoints are immutable earned area packets. Use the same pending-apply,
## asset admission and rollback path as slots; no preview/exit seeds are granted.
static func resume_checkpoint(tree: SceneTree, area: String, state: Dictionary, full_health: bool) -> String:
	if area not in Areas.PROGRESSION_AREAS: return "Unknown playtest map."
	var error := Areas.validate_area(area,state)
	if not error.is_empty(): return error
	var packet := preload("res://scripts/lol2/player_spell_teaching.gd").prepare_start(state,area)
	if full_health: packet.inventory.health = preload("res://scripts/lol2/player_health.gd").limit_from_effects(packet.inventory.get("item_effects",{}))
	var doc := {"area":area,"scene":Areas.ROWS[area].scene,"area_save":packet,"native_bank":{},"play_seconds":0.0,
		"session":{"options":{"adapter_exit_seeds":false},"last_slot":1}}
	return _queue_scene(tree,doc,1,false)

static func _queue_scene(tree: SceneTree, doc: Dictionary, slot_id: int, legacy: bool) -> String:
	if tree.paused: return "Close the current overlay before loading."
	if OS.has_feature("original_game_required") and not tree.get_meta("original_game_verified",false): return "Verify the original game files before loading."
	var session: Node = Session.for_tree(tree)
	if session == null or session.changing_scene or not session.pending_resume.is_empty(): return "Wait until the area finishes loading."
	var current := tree.current_scene
	if is_instance_valid(current):
		var progression: Variant = current.get("progression")
		if is_instance_valid(progression) and progression.get("transition_pending") == true: return "Wait until the area change finishes."
		for child in current.get_children():
			if child.get("transitioning") == true: return "Wait until the area change finishes."
	var assets_error := Areas.assets_error(doc.area)
	if not assets_error.is_empty(): return assets_error
	if not ResourceLoader.exists(doc.scene): return "The saved area is not available in this build."
	var packed: PackedScene = ResourceLoader.load(doc.scene) as PackedScene
	if packed == null: return "Cannot load the saved area."
	if session.save_in_progress():
		session.queue_manual_load(doc,slot_id,legacy)
		if is_instance_valid(current):_feedback(current,"Loading…")
		return ""
	var prior: Dictionary = session.runtime_checkpoint()
	var metadata := {}
	for key in session.RESUME_METAS:
		if tree.has_meta(key):
			metadata[key] = tree.get_meta(key)
			tree.remove_meta(key)
	var error: String = session.replace_bank(doc.native_bank,doc.get("native_globals"),str(doc.area))
	if not error.is_empty():
		session.restore_runtime(prior)
		for key in metadata: tree.set_meta(key,metadata[key])
		return error
	session.play_seconds = float(doc.play_seconds)
	session.last_slot = int(doc.session.get("last_slot",1)) if slot_id == AUTOSAVE else slot_id
	session.set_seed_override(bool(doc.session.options.adapter_exit_seeds))
	session.changing_scene = true
	if legacy and session.LEGACY_RESUMES.has(doc.area):
		tree.set_meta(session.LEGACY_RESUMES[doc.area],doc.area_save.duplicate(true))
	else:
		session.pending_resume = {"area":doc.area,"scene":doc.scene,"state":Areas.prepare_area(doc.area,doc.area_save)}
		tree.set_meta("lol2_slot_resume",{"area":doc.area,"scene":doc.scene})
	session.retain_previous(current,prior,metadata)
	var status := tree.change_scene_to_packed(packed)
	if status != OK:
		session.rollback_load("Could not open the saved area; current game preserved.")
		return "Could not open the saved area; current game preserved."
	return ""

## G-08: load a whole-game document from any file (an F10 bundle's save.json). Same validation, asset admission and
## rollback as a slot; the session keeps the document's own last slot, so later F5 saves never target a bundle file.
static func load_file(tree: SceneTree, path: String) -> String:
	var read := read_document(path)
	if not read.error.is_empty(): return read.error
	return _queue_scene(tree,read.state,AUTOSAVE,false)

static func load(tree: SceneTree, slot_id: int, use_backup: bool = false) -> String:
	return load_slot(tree, slot_id, use_backup)

## UI saves may wait for the autosave writer. The ordinary synchronous save()
## contract stays unchanged for explicit callers and tests.
static func request_manual_save(host:Node,slot_id:int)->Dictionary:
	var session:Node=Session.for_tree(host.get_tree())
	if session.save_in_progress():
		var error:String=session.queue_manual_save(host,slot_id)
		return {"error":error,"pending":error.is_empty()}
	return {"error":save(host,slot_id),"pending":false}

static func quicksave(host: Node) -> String:
	var session: Node = Session.for_tree(host.get_tree())
	var request:=request_manual_save(host,session.last_slot)
	var error:String=request.error
	_feedback(host,"Saving…" if request.pending else ("Saved to slot %02d."%session.last_slot if error.is_empty() else "Save failed: "+error))
	return error
static func quickload(host: Node) -> String:
	var session: Node = Session.for_tree(host.get_tree())
	var error := load_slot(host.get_tree(),session.last_slot)
	if not error.is_empty(): _feedback(host,"Load failed: "+error)
	return error
static func _feedback(host: Node, text: String) -> void:
	var hud:Variant=host.get("interface_hud")
	if is_instance_valid(hud) and hud.has_method("queue_lesson_status") and hud.queue_lesson_status(text):return
	if host.has_method("save_feedback"):host.save_feedback(text)
	elif host.has_method("_save_feedback"):host._save_feedback(text)
	elif host.get("status") is Label: host.get("status").text=text
