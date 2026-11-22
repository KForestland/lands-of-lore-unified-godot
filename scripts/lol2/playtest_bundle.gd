extends Node
## G-08 (lead plan 2026-11-12): the F10 report becomes a full defect bundle so a lane can replay the owner's stop instead of
## reconstructing it. While the game runs this recorder keeps a rolling history (inputs, player poses, small frames);
## when F10 opens it freezes a snapshot, and the report writes it beside report.json:
##   save.json      the whole-game document of the moment (game_save.make_document; never a player slot)
##   inputs.json    the last HISTORY_SECONDS of keys, mouse buttons and summed mouse motion, plus player pose samples
##   frames/NN.png  up to FRAME_COUNT small frames, one every FRAME_SECONDS, oldest first
##   log_tail.txt   the tail of the engine log; bundle.json names the first error line of this session
##   bundle.json    index: every file with its sha256, build identity, first point of failure, what was unavailable
## Local only: no network, nothing outside the report folder, and nothing here changes gameplay state.
## Recording (inputs, poses, frames) runs only in playtest/debug mode: --debug-mode or --developer-tools, or the
## playtest launcher's LOL2_FEEDBACK_DIR. Ordinary players get no per-frame work; their F10 still writes save + log.
## Paths in bundle.json and log_tail.txt are relative or "~"-shortened; no home or absolute project path is written.
## Load a bundle: game_save.load_file(tree, ".../save.json"), or the launcher flag --load-bundle=PATH.
const Save=preload("res://scripts/lol2/game_save.gd")
const SnapshotJob=preload("res://scripts/lol2/playtest_snapshot_job.gd")
const StartRing=preload("res://scripts/lol2/playtest_start_ring.gd")
const HISTORY_SECONDS := 120.0
const REPLAY_SECONDS := HISTORY_SECONDS + StartRing.SLOW_INTERVAL
const POSE_SECONDS := 0.25
const MOTION_SECONDS := 0.1
const FRAME_SECONDS := 3.0
const FRAME_COUNT := 10
const FRAME_WIDTH := 320
const LOG_TAIL_LINES := 300
## G-04 carries moved floors, generic objects and native cells in the whole-game
## document. This diagnostic snapshot is not a deterministic engine checkpoint.
const SAVE_OMITS := ["native timer lists", "creature AI positions mid-fight", "in-flight projectiles and movies", "engine global RNG state", "movement velocity/input smoothing", "spell cooldown cleared by the ordinary loader"]

var start_ring=StartRing.new()
var next_snapshot_t:=0.0
var recording_started_t:=0.0
var snapshot_note:="No saveable playtest state has been captured."
var snapshot_thread:Thread
var snapshot_generation:=0
var job_generation:=0
var job_started_us:=0
var job_t:=0.0
var job_held:Dictionary={}
var job_main_us:=0
var snapshot_warning:=""
var snapshot_intervals:Dictionary={}
var slow_capture_counts:Dictionary={}
var job_area:=""
var job_scene_id:=0
var snapshot_scene_id:=0
var held_keys:Dictionary={}
var held_buttons:Dictionary={}
var events: Array = []
var poses: Array = []
var frames: Array = []
var motion := Vector2.ZERO
var motion_since := 0.0
var pose_since := 0.0
var frame_since := 0.0
var session_started_unix := 0.0
var frozen := {}
var recording := false
static var force_recording := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_started_unix = Time.get_unix_time_from_system()
	set_recording(recording_wanted())

static func recording_wanted() -> bool:
	if force_recording: return true
	var args := OS.get_cmdline_user_args()
	return "--debug-mode" in args or "--developer-tools" in args or not OS.get_environment("LOL2_FEEDBACK_DIR").is_empty()

func set_recording(on: bool) -> void:
	if on and not recording: _fresh_history()
	recording = on
	set_process(on)
	set_process_input(on)

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _input(event: InputEvent) -> void:
	# Keep held state current while the feedback form is frozen, without
	# putting the comment's keys into the recorded gameplay history.
	if event is InputEventKey and not event.echo:
		var code:Key=event.keycode if event.keycode!=0 else event.physical_keycode
		var name:String=OS.get_keycode_string(code)
		if event.pressed: held_keys[name]=true
		else: held_keys.erase(name)
	elif event is InputEventMouseButton:
		# Wheels are impulses; native events need not send a matching release.
		# Keep them in history without seeding a fictitious held wheel at T0.
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_XBUTTON1,MOUSE_BUTTON_XBUTTON2]:
			if event.pressed: held_buttons[str(event.button_index)]=true
			else: held_buttons.erase(str(event.button_index))
	if not frozen.is_empty(): return
	if event is InputEventKey and not event.echo:
		events.append({"t": now(), "kind": "key", "key": OS.get_keycode_string(event.keycode if event.keycode!=0 else event.physical_keycode), "pressed": event.pressed})
	elif event is InputEventMouseButton:
		events.append({"t": now(), "kind": "mouse", "button": event.button_index, "pressed": event.pressed,
			"at": [snappedf(event.position.x, 0.1), snappedf(event.position.y, 0.1)]})
	elif event is InputEventMouseMotion:
		motion += event.relative

func _process(delta: float) -> void:
	finish_snapshot()
	if not frozen.is_empty(): return
	var current:Node=get_tree().current_scene
	var scene_id:int=current.get_instance_id() if is_instance_valid(current) else 0
	if scene_id!=snapshot_scene_id:
		snapshot_scene_id=scene_id;next_snapshot_t=0.0
	var t := now()
	motion_since += delta
	if motion_since >= MOTION_SECONDS:
		flush_motion(t)
	pose_since += delta
	if pose_since >= POSE_SECONDS:
		pose_since = 0.0
		var pose := pose_now()
		if not pose.is_empty(): poses.append(pose)
	frame_since += delta
	if frame_since >= FRAME_SECONDS:
		frame_since = 0.0
		var frame := small_frame()
		if frame != null:
			frames.append({"t": t, "image": frame})
			while frames.size() > FRAME_COUNT: frames.pop_front()
	while not events.is_empty() and t - float(events[0].t) > REPLAY_SECONDS: events.pop_front()
	while not poses.is_empty() and t - float(poses[0].t) > REPLAY_SECONDS: poses.pop_front()
	if t>=next_snapshot_t:
		next_snapshot_t=t+1.0 # Refused/initial loading states retry cheaply, not every frame.
		capture_start()

func flush_motion(t:float)->void:
	if motion!=Vector2.ZERO:
		events.append({"t":t,"kind":"look","relative":[snappedf(motion.x,0.1),snappedf(motion.y,0.1)]})
	motion=Vector2.ZERO;motion_since=0.0

func capture_start()->bool:
	var started:=Time.get_ticks_usec()
	if snapshot_thread!=null or not recording or not frozen.is_empty() or get_tree().paused:return false
	var scene:Node=get_tree().current_scene
	if scene==null or not scene.has_method("area_snapshot") or not scene.has_method("can_save"):return false
	var session:Node=get_tree().root.get_node_or_null("GameSession")
	if session==null or session.changing_scene or not session.pending_resume.is_empty() or session.save_in_progress():return false
	if not str(scene.can_save()).is_empty():return false
	var t:=now()
	next_snapshot_t=t+StartRing.INTERVAL
	# The saved camera includes earlier motion; only later events replay it.
	flush_motion(t)
	var doc:Dictionary=_document(scene).duplicate(true)
	if doc.is_empty():snapshot_failed("No whole-game document.");return false
	var cursor:=get_viewport().get_mouse_position()
	job_area=str(doc.area);job_scene_id=scene.get_instance_id()
	next_snapshot_t=t+float(snapshot_intervals.get(job_area,StartRing.INTERVAL))
	job_t=t;job_started_us=started;job_generation=snapshot_generation
	job_held={"keys":held_keys.keys(),"mouse_buttons":held_buttons.keys(),"mouse_mode":Input.mouse_mode,"cursor":[cursor.x,cursor.y]}
	snapshot_thread=Thread.new()
	var status:=snapshot_thread.start(SnapshotJob.encode.bind(Save,doc))
	job_main_us=Time.get_ticks_usec()-started
	if status!=OK:
		snapshot_thread=null;snapshot_failed("Cannot start snapshot worker.");return false
	return true

func finish_snapshot()->void:
	if snapshot_thread==null or snapshot_thread.is_alive():return
	var started:=Time.get_ticks_usec()
	var result:Dictionary=snapshot_thread.wait_to_finish()
	snapshot_thread=null
	if job_generation!=snapshot_generation or not recording:return
	if not str(result.error).is_empty():snapshot_failed(result.error);return
	result["cost_us"]=Time.get_ticks_usec()-job_started_us
	result["capture_main_us"]=job_main_us
	slow_capture_counts[job_area]=int(slow_capture_counts.get(job_area,0))+1 if job_main_us>StartRing.FRAME_BUDGET_US else 0
	if int(slow_capture_counts[job_area])>=2 and not snapshot_intervals.has(job_area):
		snapshot_intervals[job_area]=StartRing.SLOW_INTERVAL
		push_warning("Replay snapshots on %s now use60s: live capture exceeded5ms twice; replay may need60s of prefix input."%job_area)
	var scene:Node=get_tree().current_scene
	if is_instance_valid(scene) and scene.get_instance_id()==job_scene_id:
		next_snapshot_t=maxf(next_snapshot_t,job_t+float(snapshot_intervals.get(job_area,StartRing.INTERVAL)))
	start_ring.remember_encoded(result,job_t,job_held)
	snapshot_note="";snapshot_warning=""
	start_ring.finish_main_max_us=maxi(start_ring.finish_main_max_us,Time.get_ticks_usec()-started)

func snapshot_failed(error:String)->void:
	snapshot_note=error
	next_snapshot_t=maxf(next_snapshot_t,now()+StartRing.INTERVAL)
	if error!=snapshot_warning:
		snapshot_warning=error;push_warning("Replay start snapshot skipped: "+error)

func _notification(what:int)->void:
	if what!=NOTIFICATION_APPLICATION_FOCUS_OUT:return
	# The engine releases input on focus loss. Preserve that boundary for any
	# future replay crossing it, without asking the desktop to change focus.
	if recording and frozen.is_empty():
		var t:=now()
		for key in held_keys:events.append({"t":t,"kind":"key","key":key,"pressed":false,"source":"focus_loss"})
		for button in held_buttons:events.append({"t":t,"kind":"mouse","button":int(button),"pressed":false,"source":"focus_loss"})
	held_keys.clear();held_buttons.clear()

func _exit_tree()->void:
	if snapshot_thread!=null:snapshot_thread.wait_to_finish();snapshot_thread=null

func _fresh_history()->void:
	snapshot_generation+=1
	events.clear();poses.clear();frames.clear();start_ring.clear()
	motion=Vector2.ZERO;motion_since=0.0;pose_since=0.0;frame_since=0.0
	recording_started_t=now();next_snapshot_t=0.0
	snapshot_note="No saveable playtest state has been captured."


func pose_now() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null: return {}
	var player = scene.get("player")
	if not player is Node3D: return {}
	var translation = scene.get("native_translation")
	if not translation is Vector3: translation = Vector3.ZERO
	var at: Vector3 = player.global_position - translation
	return {"t": now(), "area": str(scene.name), "x": snappedf(at.x, 0.01), "y": snappedf(at.z, 0.01), "h": snappedf(at.y, 0.01),
		"yaw": snappedf(player.global_rotation.y, 0.0001)}

func small_frame() -> Image:
	if DisplayServer.get_name() == "headless": return null
	var texture := get_viewport().get_texture()
	if texture == null: return null
	var image := texture.get_image()
	if image == null or image.is_empty(): return null
	var height := maxi(1, int(round(float(image.get_height()) * FRAME_WIDTH / maxf(1.0, float(image.get_width())))))
	image.resize(FRAME_WIDTH, height, Image.INTERPOLATE_BILINEAR)
	return image

## Called when F10 opens: stop recording and copy what is needed, so typing the comment does not enter the history.
func freeze() -> void:
	finish_snapshot() # Never wait for a running job on the report-opening frame.
	var scene := get_tree().current_scene
	var t:=now()
	flush_motion(t)
	var requested:=maxf(recording_started_t,t-HISTORY_SECONDS)
	var retained:=maxf(recording_started_t,t-REPLAY_SECONDS)
	var start:Dictionary=start_ring.preceding(requested,retained,t-recording_started_t<HISTORY_SECONDS) if recording else {}
	frozen = {"t": t,"requested_start_t":requested,"start":start,"snapshot_costs":start_ring.costs(),"snapshot_area_intervals":snapshot_intervals.duplicate(),"start_note":snapshot_note, "events": events.duplicate(true), "poses": poses.duplicate(true), "frames": frames.duplicate(),
		"save": {}, "save_note": "", "can_save": ""}
	if scene != null and scene.has_method("can_save"): frozen.can_save = str(scene.can_save())
	frozen.save = _document(scene)
	if frozen.save.is_empty(): frozen.save_note = "This area has no whole-game save document."

func thaw() -> void:
	frozen = {}
	# Report-typing time is paused gameplay; begin a fresh recorded interval
	# rather than leave an unrecorded wall-clock gap in the next replay.
	_fresh_history()

func _document(scene: Node) -> Dictionary:
	if scene == null or not ResourceLoader.exists("res://scripts/lol2/game_save.gd"): return {}
	var save_script = load("res://scripts/lol2/game_save.gd")
	if not scene.has_method("area_snapshot"): return {}
	var areas = load("res://scripts/lol2/game_areas.gd")
	if str(areas.id_for(scene)).is_empty(): return {}
	return save_script.make_document(scene, save_script.AUTOSAVE)

## Writes the bundle files into an existing report folder. Returns the index written to bundle.json.
func write_into(path: String) -> Dictionary:
	if frozen.is_empty(): freeze()
	var index := {"schema": 1, "files": {}, "unavailable": [], "build": build_identity(),
		"history_seconds": HISTORY_SECONDS, "report_t": frozen.get("t", now()), "recording": recording,
		# save.json is written even where the game would refuse a save (dead, drowning, movie): the refusal is named
		# here so a lane knows the state is diagnostic, not a save the player could have made.
		"save_refused_by_game": frozen.get("can_save", ""),
		"save_omits": SAVE_OMITS,"snapshot_costs":frozen.get("snapshot_costs",{}),
		"snapshot_interval_seconds":StartRing.INTERVAL,"snapshot_ring_count":StartRing.COUNT,
		"snapshot_slow_interval_seconds":StartRing.SLOW_INTERVAL,"snapshot_frame_budget_us":StartRing.FRAME_BUDGET_US,
		"snapshot_area_intervals":frozen.get("snapshot_area_intervals",{}),
		"snapshot_cost_definition":"capture_main_us/finish_main_us measure game-thread work; worker_us is background validation/encoding; cost_us is capture-to-collection wall-clock latency.",
		"snapshot_policy":"15s target; two live captures over5ms slow that area to60s. Replay can need up to60s of earlier input; whole saves are not engine checkpoints.",
		"data_handling":"owner-derived, local only; never publish report saves",
		"local_only_files":["save.json","start_save.json","replay_inputs.json"]}
	if not recording: index.unavailable.append("inputs/frames: recording is off outside playtest/debug mode")
	# Save of the moment. write_document validates and verifies the file it writes.
	if not frozen.save.is_empty():
		var error: String = load("res://scripts/lol2/game_save.gd").write_document(path.path_join("save.json"), frozen.save)
		if error.is_empty(): index.files["save.json"] = ""
		else: index.unavailable.append("save.json: " + error)
	else:
		index.unavailable.append("save.json: " + str(frozen.save_note))
	var start:Dictionary=frozen.get("start",{})
	if not start.is_empty():
		var error:String=load("res://scripts/lol2/game_save.gd").write_document(path.path_join("start_save.json"),JSON.parse_string(start.json))
		if error.is_empty():
			index.files["start_save.json"]=""
			index.start_snapshot={"t":start.t,"requested_start_t":frozen.requested_start_t,"coverage":start.coverage,"cost_us":start.cost_us,"bytes":start.bytes,"captured_json_sha256":start.get("captured_json_sha256",str(start.json).sha256_text()),
				"written_file_sha256":FileAccess.get_sha256(path.path_join("start_save.json")),
				"rng":"Saved per-owner streams are in the document; engine global RNG state is unavailable."}
			var replay:Dictionary={"start_t":start.t,"window_start_t":frozen.requested_start_t,"report_t":frozen.t,"initial_input_state":start.held,
				"events":frozen.events.filter(func(e):return float(e.t)>float(start.t)),"poses":frozen.poses.filter(func(p):return float(p.t)>=float(start.t))}
			if _write_text(path.path_join("replay_inputs.json"),JSON.stringify(replay,"\t")+"\n"):index.files["replay_inputs.json"]=""
			else:index.unavailable.append("replay_inputs.json: write failed")
		else:index.unavailable.append("start_save.json: "+error)
	else:
		index.unavailable.append("start_save.json: "+(str(frozen.get("start_note","")) if not str(frozen.get("start_note","")).is_empty() else "No preceding snapshot with retained replay inputs."))
	var inputs := {"events": frozen.events.filter(func(e):return float(e.t)>=float(frozen.requested_start_t)), "poses": frozen.poses.filter(func(p):return float(p.t)>=float(frozen.requested_start_t)), "report_t": frozen.t,
		"note": "t = seconds since engine start; look = summed mouse motion per 0.1 s; poses every 0.25 s (native x, y, h)"}
	if _write_text(path.path_join("inputs.json"), JSON.stringify(inputs, "\t") + "\n"): index.files["inputs.json"] = ""
	else: index.unavailable.append("inputs.json: write failed")
	if not frozen.frames.is_empty():
		DirAccess.make_dir_recursive_absolute(path.path_join("frames"))
		for i in frozen.frames.size():
			var name := "frames/%02d.png" % i
			if frozen.frames[i].image.save_png(path.path_join(name)) == OK: index.files[name] = ""
		index.frame_times = frozen.frames.map(func(f): return f.t)
	else:
		index.unavailable.append("frames: none captured (headless or too early)")
	var log := log_tail()
	index.first_error = log.first_error
	index.log_file = log.path
	if not log.tail.is_empty() and _write_text(path.path_join("log_tail.txt"), log.tail): index.files["log_tail.txt"] = ""
	elif log.tail.is_empty(): index.unavailable.append("log_tail.txt: " + log.note)
	for file_name in index.files.keys():
		index.files[file_name] = FileAccess.get_sha256(path.path_join(file_name))
	return index

func build_identity() -> Dictionary:
	var manifest := ProjectSettings.globalize_path("res://tmp/staged_inputs/manifest.json")
	return {"version": ProjectSettings.get_setting("application/config/version", "unversioned"),
		"commit": OS.get_environment("LOL2_BUILD_COMMIT"), "launcher": OS.get_environment("LOL2_LAUNCHER"),
		"staged_manifest_sha256": FileAccess.get_sha256(manifest) if FileAccess.file_exists(manifest) else "",
		"engine": Engine.get_version_info().string}

## The engine log of this session: its tail, and the first error line written since the session started.
func log_tail() -> Dictionary:
	var result := {"path": "", "tail": "", "first_error": {}, "note": ""}
	var configured: String = ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log")
	var log_path := ProjectSettings.globalize_path(configured)
	result.path = configured
	if not FileAccess.file_exists(log_path):
		result.note = "no engine log file (file logging off?)"
		return result
	var text := FileAccess.get_file_as_string(log_path)
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.begins_with("SCRIPT ERROR") or line.begins_with("ERROR:") or line.begins_with("USER ERROR"):
			var where := lines[i + 1].strip_edges() if i + 1 < lines.size() else ""
			result.first_error = {"line": i + 1, "text": line.strip_edges(), "at": where}
			break
	var start := maxi(0, lines.size() - LOG_TAIL_LINES)
	result.tail = shorten_paths("\n".join(lines.slice(start)) + "\n")
	if not result.first_error.is_empty():
		result.first_error.text = shorten_paths(result.first_error.text)
		result.first_error.at = shorten_paths(result.first_error.at)
	return result

## Replaces the project folder with res:// and the home folder with ~ (bundle files may be shared with other lanes).
static func shorten_paths(text: String) -> String:
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var home := OS.get_environment("HOME").trim_suffix("/")
	if not project.is_empty(): text = text.replace(project + "/", "res://").replace(project, "res://")
	if not home.is_empty(): text = text.replace(home, "~")
	return text

func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok
