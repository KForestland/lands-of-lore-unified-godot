extends Node
## Whole-game runtime state. Transient area handoffs remain with their existing owners.
const Globals=preload("res://scripts/lol2/game_native_globals.gd")
const World=preload("res://scripts/lol2/act2_world_checkpoint.gd")
const Native = preload("res://scripts/lol2/native_script_host.gd")
const NATIVE_AREAS := ["L1_DC","L3_DH","L4_HJ","L5_HC","L7_DH","L8_SJ","L9_DR","L10_DC","L12_CM","L13_RC","L14_HT","L16_CA","L17_HC","L19_BC","L20_BB"]
var native_bank: Dictionary = {}
var native_globals:Dictionary=Globals.empty()
var adapter_exit_seeds := true
var seed_pending := false
var play_seconds := 0.0
var last_slot := 1
var pending_resume: Dictionary = {}

static func for_tree(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null("GameSession") if tree != null else null

static func bank_error(value: Variant) -> String:
	if not value is Dictionary or value.size() > NATIVE_AREAS.size(): return "Invalid saved level bank."
	for area in value:
		if not area is String or area not in NATIVE_AREAS: return "Unknown saved level."
		var row: Variant = value[area]
		if not row is Dictionary or row.size() not in [5,6] or (row.size()==6 and not row.has("world")): return "Invalid saved level packet."
		if row.has("world"):
			var world_error:=World.error(row.world,area)
			if not world_error.is_empty():return world_error
		var vm := {}
		for field in Native.SNAPSHOT_FIELDS: vm[field] = row.get(field)
		var error := Native.snapshot_error(vm)
		if not error.is_empty(): return error
		var durability: Variant = row.get("struck_durability")
		if not durability is Dictionary or durability.size() > Native.SNAPSHOT_ROWS: return "Invalid saved durability."
		for ref in durability:
			if not ref is String or ref.length() > 128 or not Native._snapshot_integer(durability[ref]): return "Invalid saved durability."
	return ""

func replace_bank(value: Variant, global_state:Variant=null, preferred_area:String="") -> String:
	var error := bank_error(value)
	if not error.is_empty(): return error
	var cells:Variant=Globals.legacy(value,preferred_area) if global_state==null else global_state
	error=Globals.error(cells)
	if not error.is_empty():return error
	# Complete validation precedes both owners changing, including rollback loads.
	native_bank=value.duplicate(true)
	native_globals=Globals.canonical(cells)
	for area in native_bank:native_bank[area].locals_e58={}
	return ""

func snapshot_globals(host:Node=null)->Dictionary:
	var value:Dictionary=native_globals.duplicate(true)
	var progression:Variant=host.get("progression") if host!=null else null
	if is_instance_valid(progression) and progression.get("native")!=null:
		value.locals_e58.merge(progression.native.snapshot().locals_e58,true)
	return value

func bank_for(area: String) -> Dictionary:
	return native_bank.get(area, {}).duplicate(true)

func snapshot_bank(host: Node = null) -> Dictionary:
	native_globals=snapshot_globals(host)
	var result := native_bank.duplicate(true)
	var progression: Variant = host.get("progression") if host != null else null
	if is_instance_valid(progression) and progression.get("native") != null:
		var row: Dictionary = progression.native.snapshot()
		row.struck_durability = progression.struck_durability.duplicate(true)
		row.world=World.snapshot(progression)
		result[progression.area_id] = row
	for area in result:result[area].locals_e58={} # One saved global table, no per-level copies.
	return result

func store_current(progression: Node) -> void:
	var row: Dictionary = progression.native.snapshot()
	row.struck_durability = progression.struck_durability.duplicate(true)
	row.world=World.snapshot(progression)
	native_globals.locals_e58.merge(row.locals_e58,true)
	row.locals_e58={}
	native_bank[progression.area_id] = row

func set_seed_override(enabled: bool) -> void:
	adapter_exit_seeds = enabled
	seed_pending = true

func take_seed_override() -> Variant:
	if not seed_pending: return null
	seed_pending = false
	return adapter_exit_seeds

const LEGACY_RESUMES := {"L3_DH":"lol2_museum_resume","L4_HJ":"lol2_jungle_resume","L5_HC":"lol2_hive_resume","L7_DH":"lol2_dark_halls_resume","L8_SJ":"lol2_darker_resume"}
const RESUME_METAS := ["lol2_museum_checkpoint","lol2_museum_resume","lol2_jungle_resume","lol2_hive_resume","lol2_darker_resume","lol2_dark_halls_resume","lol2_act2_handoff","lol2_darker_handoff","lol2_jungle_handoff","lol2_cave_completion","lol2_hive_route_handoff","lol2_dark_halls_route_handoff","lol2_dark_halls_handoff","lol2_map_start_selector","lol2_map_preview","lol2_darker_preview","lol2_level_change","lol2_slot_resume"]
var changing_scene := false

func runtime_checkpoint() -> Dictionary:
	return {"native_bank":snapshot_bank(),"native_globals":native_globals.duplicate(true),"adapter_exit_seeds":adapter_exit_seeds,"seed_pending":seed_pending,"play_seconds":play_seconds,"last_slot":last_slot,"pending_resume":pending_resume.duplicate(true),"changing_scene":changing_scene}
func restore_runtime(value: Dictionary) -> void:
	replace_bank(value.native_bank,value.get("native_globals"),"")
	adapter_exit_seeds = value.adapter_exit_seeds
	seed_pending = value.seed_pending
	play_seconds = value.play_seconds
	last_slot = value.last_slot
	pending_resume = value.pending_resume.duplicate(true)
	changing_scene = value.changing_scene

func reset_legacy() -> void:
	replace_bank({})
	pending_resume.clear()
	adapter_exit_seeds = true; seed_pending = false; play_seconds = 0.0; last_slot = 1; changing_scene = false
	if is_inside_tree():
		for key in RESUME_METAS:
			if get_tree().has_meta(key):get_tree().remove_meta(key)

# A slot load is committed only after the destination has applied its packet.
# Keep the outgoing node off-tree, rather than trying to re-apply a possibly
# incompatible save to reconstruct it after a destination-side failure.
var _load_previous: Node
var _load_runtime: Dictionary = {}
var _load_metadata: Dictionary = {}
var _load_mouse := Input.MOUSE_MODE_VISIBLE

func retain_previous(host: Node, runtime: Dictionary, metadata: Dictionary) -> void:
	_load_previous = host
	_load_runtime = runtime
	_load_metadata = metadata
	_load_mouse = Input.mouse_mode
	if is_instance_valid(host):
		get_tree().current_scene = null
		host.get_parent().remove_child(host)

func _commit_load() -> void:
	if is_instance_valid(_load_previous): _load_previous.queue_free()
	_load_previous = null
	_load_runtime.clear(); _load_metadata.clear()
	pending_resume.clear(); changing_scene = false
	if get_tree().has_meta("lol2_slot_resume"): get_tree().remove_meta("lol2_slot_resume")

func rollback_load(error: String) -> void:
	var tree := get_tree()
	var failed := tree.current_scene
	if is_instance_valid(_load_previous) and is_instance_valid(failed):
		# Keep outgoing cache writers suppressed until the failed scene is detached.
		changing_scene = true
		tree.current_scene = null
		failed.get_parent().remove_child(failed)
		failed.queue_free()
	if not _load_runtime.is_empty(): restore_runtime(_load_runtime)
	else:
		pending_resume.clear(); changing_scene = false
	for key in RESUME_METAS:
		if tree.has_meta(key): tree.remove_meta(key)
	for key in _load_metadata: tree.set_meta(key, _load_metadata[key])
	if is_instance_valid(_load_previous):
		tree.root.add_child(_load_previous)
		tree.current_scene = _load_previous
		var camera: Variant = _load_previous.get("camera")
		if camera is Camera3D: camera.make_current()
		Input.mouse_mode = _load_mouse
	_load_previous = null
	_load_runtime.clear(); _load_metadata.clear()
	var host := tree.current_scene
	if is_instance_valid(host):
		ResourceLoader.load("res://scripts/lol2/game_save.gd")._feedback(host,"Load failed: "+error)

func apply_pending(host: Node) -> String:
	if not is_inside_tree(): return ""
	if pending_resume.is_empty():
		_commit_load()
		return ""
	if pending_resume.scene != host.scene_file_path: return ""
	var error: String = host.apply_slot_state(pending_resume.state)
	if not error.is_empty():
		# Called from destination _ready; tree mutation must wait until it returns.
		rollback_load.call_deferred(error)
		return error
	var magic:Variant=host.get("starting_magic")
	if is_instance_valid(magic) and magic.has_method("finish_load"):magic.finish_load()
	else:host.set_meta("lol2_loaded_magic_clock",true) # Deferred magic attachment consumes this before input.
	_commit_load()
	return ""

func apply_when_ready(host: Node) -> void:
	for i in 1800:
		if not is_instance_valid(host) or not host.is_inside_tree():return
		if host.get("walkthrough_ready") == true and is_instance_valid(host.get("starting_magic")):
			apply_pending(host)
			return
		await get_tree().process_frame
	rollback_load.call_deferred("The saved area did not finish loading.")

const AUTOSAVE_SECONDS := 600.0
const AUTOSAVE_RETRY_SECONDS := 5.0
var _observed_scene: WeakRef
var _arrival_pending := false
var _arrival_frame := -1
var _autosave_elapsed := 0.0
var _retry_remaining := 0.0
var autosave_writes := 0
var last_autosave_reason := ""
var last_autosave_micros := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	advance_play(delta)

## The production clock is explicit so a test can advance it without waiting ten minutes.
## It still uses live scene admission; this is not a bypass of health, physics or holds.
func advance_play(delta: float) -> void:
	_finish_autosave()
	if delta < 0 or not is_finite(delta) or not is_inside_tree():return
	var tree:=get_tree()
	if changing_scene or not pending_resume.is_empty():return
	var host: Node=tree.current_scene
	if not is_instance_valid(host) or not host.has_method("area_snapshot"):return
	if _observed_scene==null or _observed_scene.get_ref()!=host:
		_observed_scene=weakref(host);_arrival_pending=true;_arrival_frame=-1;_retry_remaining=0.0
	if tree.paused:return
	var magic: Variant=host.get("starting_magic")
	if not is_instance_valid(magic):return
	var ready: Variant=host.get("walkthrough_ready")
	if ready==null:ready=host.get("ready_for_review")
	if ready!=true or changing_scene or not pending_resume.is_empty():return
	if _arrival_frame<0:
		_arrival_frame=Engine.get_physics_frames();return
	if Engine.get_physics_frames()<=_arrival_frame:return
	var active: bool=preload("res://scripts/lol2/save_admission.gd").play_active(host)
	if active:
		play_seconds+=delta;_autosave_elapsed+=delta
	if "--no-autosave" in OS.get_cmdline_user_args():return
	_retry_remaining=maxf(0.0,_retry_remaining-delta)
	if not _arrival_pending and _autosave_elapsed<AUTOSAVE_SECONDS:return
	if _retry_remaining>0 or save_in_progress():return
	_retry_remaining=AUTOSAVE_RETRY_SECONDS
	if not active or not host.can_save().is_empty():return
	var reason: String="arrival" if _arrival_pending else "timer"
	ResourceLoader.load("res://scripts/lol2/game_save.gd").autosave(host,reason)

signal manual_save_finished(slot_id:int,error:String)
# One detached snapshot: repeated requests replace this one pending request.
# The worker never sees these live objects and the two writers never overlap.
var _manual_document:Dictionary={}
var _manual_host:WeakRef
var _manual_slot:=0
var _manual_load:Dictionary={}
func manual_load_pending()->bool:
	return not _manual_load.is_empty()
func pending_manual_document(slot_id:int)->Dictionary:
	return _manual_document.duplicate(true) if slot_id==_manual_slot else {}
func queue_manual_load(document:Dictionary,slot_id:int,legacy:bool):
	_manual_load={"document":document.duplicate(true),"slot":slot_id,"legacy":legacy,"waits_for_manual":slot_id==_manual_slot and not _manual_document.is_empty()}
func _finish_manual_load():
	if _manual_load.is_empty() or _save_thread!=null or not _manual_document.is_empty():return
	var request:Dictionary=_manual_load;_manual_load={}
	var writer:Script=ResourceLoader.load("res://scripts/lol2/game_save.gd")
	var host:Node=get_tree().current_scene
	var error:String=writer._queue_scene(get_tree(),request.document,int(request.slot),bool(request.legacy))
	if not error.is_empty() and is_instance_valid(host):writer._feedback(host,"Load failed: "+error)
func manual_save_pending()->bool:
	return not _manual_document.is_empty()
func queue_manual_save(host:Node,slot_id:int)->String:
	var writer:Script=ResourceLoader.load("res://scripts/lol2/game_save.gd")
	if slot_id<1 or slot_id>10:return "Choose a save slot from 1 to 10."
	var error:String=host.can_save()
	if not error.is_empty():return error
	var document:Dictionary=writer.make_document(host,slot_id).duplicate(true)
	if document.is_empty():return "This area cannot be saved."
	_manual_document=document;_manual_host=weakref(host);_manual_slot=slot_id
	return ""
func _finish_manual_save():
	if _manual_document.is_empty() or _save_thread!=null:return
	var document:Dictionary=_manual_document
	var slot_id:int=_manual_slot
	var host:Node=_manual_host.get_ref() if _manual_host!=null else null
	_manual_document={};_manual_host=null;_manual_slot=0
	var writer:Script=ResourceLoader.load("res://scripts/lol2/game_save.gd")
	var error:String=writer.write_document(writer.slot_path(slot_id),document)
	if error.is_empty():last_slot=slot_id
	elif _manual_load.get("waits_for_manual",false) and int(_manual_load.slot)==slot_id:_manual_load={}
	# Do not install an earlier capture back into the running game's bank or
	# rewind state the player changed while the worker was finishing.
	if is_instance_valid(host) and get_tree().current_scene==host:
		writer._feedback(host,"Saved to slot %02d."%slot_id if error.is_empty() else "Save failed: "+error)
	manual_save_finished.emit(slot_id,error)

var _save_thread: Thread
var _save_host_id := 0
var _save_reason := ""
var _save_started := 0
var last_autosave_capture_micros := 0
var last_autosave_error := ""

func save_in_progress() -> bool:
	return _save_thread != null

func start_autosave(host: Node, reason: String) -> String:
	if save_in_progress():return "An autosave is finishing."
	var error: String=host.can_save()
	if not error.is_empty():return error
	var writer: Script=ResourceLoader.load("res://scripts/lol2/game_save.gd")
	var start:=Time.get_ticks_usec()
	# Capture and detach all live state on the game thread. The worker sees only values.
	var doc: Dictionary=writer.make_document(host,0).duplicate(true)
	if doc.is_empty():return "This area cannot be saved."
	_save_host_id=host.get_instance_id();_save_reason=reason;_save_started=start
	_save_thread=Thread.new()
	var status:=_save_thread.start(_write_autosave.bind(writer,doc))
	last_autosave_capture_micros=Time.get_ticks_usec()-start
	if status!=OK:
		_save_thread=null
		return "Cannot start the autosave writer."
	return ""

static func _write_autosave(writer: Script, doc: Dictionary) -> String:
	# Existing pure validators, JSON and file operations only: no scene or session access.
	return writer.write_document(writer.slot_path(0),doc)

func _finish_autosave() -> void:
	if _save_thread==null:
		_finish_manual_save();_finish_manual_load();return
	if _save_thread.is_alive():return
	var error: String=_save_thread.wait_to_finish()
	_save_thread=null;last_autosave_error=error
	last_autosave_micros=Time.get_ticks_usec()-_save_started
	if not error.is_empty():
		_finish_manual_save();_finish_manual_load();return
	autosave_writes+=1;last_autosave_reason=_save_reason;_autosave_elapsed=0.0
	var host: Node=get_tree().current_scene
	if is_instance_valid(host) and host.get_instance_id()==_save_host_id:
		_arrival_pending=false;_retry_remaining=0.0
		ResourceLoader.load("res://scripts/lol2/game_save.gd")._feedback(host,"Autosaved.")
	_finish_manual_save();_finish_manual_load()

func _exit_tree() -> void:
	if is_instance_valid(_load_previous): _load_previous.free()
	_load_previous = null
	if _save_thread!=null:
		_save_thread.wait_to_finish();_save_thread=null
	_finish_manual_save()
