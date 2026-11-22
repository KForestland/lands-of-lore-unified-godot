extends Node
## Dark Halls doors (movables 56/57, scripts/lol2/dark_halls_doors_source.json), driven by the shared native script
## host (scripts/lol2/native_script_host.gd) over res://scripts/lol2/native_scripts/L7_DH.json:
## E fires the door's kind-4 records (context = the door, arg_c = 0); predicates 206/207 on the door's +0x25 pick the
## open group (opcode 1 percent 100, +0x25 = 1) or the close group (percent 0, +0x25 = 0). The leaf turns to
## sign * travel word * 360 / 65536 degrees on its native hinge. Sound requests are logged, not played.
## Door 57's trap: grounded entry into region 1338 slams and locks it and brings grid SHADE 73 next to the trap; the
## SHADE's death fires actor 73 kind 6 value 10 (group 15750: door 57 +0x25 = 0) and unlocks it. Group 794 does not
## run as a unit: opcode 13 index 12 on actor 73 was not entered, and a refusal drops the whole group. The host applies
## the proven prefix (sound 881, travel 0, state 2). Opcode 18 only parks the command, so the shade is moved here.
## A left click fires kind 9. Three hits open the leaf (travel 21845). The swing words are an adapter: the player does
## not produce them. Group 13798 does not clear the quest lock. Region 83's stream-0 group 76 would shut door 56 and
## set state 3, but predicate 19 nests to local 6, which is not seeded, so the group stays unhosted.
## Modern adapters (docs/DEVIATIONS.md): E as the use (arg_c 0), kind-0x20 slot N = movable N, the earlier swing
## speed, the trap prefix and the shade move, old-save mapping, E within reach and facing, the native template box
## as the leaf's collider, and the kind-9 swing words.
## State: quests.dark_halls_doors {"56": {"open","locked"}, "57": {...}, "trap": bool, optional "native": {"movable:56":
## {fields}, "movable:57": {fields}, "locals": {index: value}}}. "open" mirrors travel != 0; saves without "native"
## load as open -> +0x25 1 and the full travel word.
const SOURCE := "res://scripts/lol2/dark_halls_doors_source.json"
const NATIVE := "res://scripts/lol2/native_scripts/L7_DH.json"
const NativeHost = preload("res://scripts/lol2/native_script_host.gd")
const NATIVE_FIELDS: Array[String] = ["byte_0x25", "selector_0x3d", "byte_0x26", "travel_0x50"]
const REACH := 120.0
const FACING := 0.7
const SWING_SECONDS := 1.0
## Kind-9 admit words. Door 57's third record needs dword_26 <= 20; door 56's needs <= 10. One strength of 10
## opens either door. A strength of 20 opens only door 57. The player swing does not write these words.
const BASH_WORD0 := 0x0002
const BASH_WORD2 := 0x0004
const BASH_DWORD := 10
const TRAP_SOUND := 881
const TRAP_STATE := 2
const Form = preload("res://scripts/lol2/player_form_body.gd")
const Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
var host: Node3D
var source: Dictionary = {}
var leaves: Dictionary = {}   # id -> {"hinge": Node3D, "row": Dictionary}
var angle: Dictionary = {}    # id -> current unsigned leaf angle in degrees
var target_word: Dictionary = {}  # id -> travel word from the native host
var native: RefCounted = null
var sound_log: Array[int] = []
var trap_group: String = ""
var trap_reason: String = ""

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE)

static func movables() -> Array:
	if not assets_ready(): return []
	var result: Array = []
	for d in JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).doors: result.append(int(d.movable))
	return result

static func _vec(a: Array) -> Vector3: return Vector3(float(a[0]), float(a[1]), float(a[2]))

func setup(walkthrough: Node3D) -> String:
	name = "DarkHallsDoors"
	host = walkthrough
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Dark Halls doors source missing."
	source = parsed
	var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	for row in source.doors:
		var id := str(int(row.movable))
		var pivot := _vec(row.pivot)
		var hinge := Node3D.new()
		hinge.name = "Door" + id
		add_child(hinge)
		hinge.position = pivot
		var groups: Dictionary = {}
		for face in area.faces:
			if face.kind != "movable" or str(face.get("placement_kind", "")) != "movable" or int(face.source_index) != int(row.movable): continue
			if not groups.has(face.material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[face.material] = surface
			for i in [0, 1, 2, 0, 2, 3]:
				groups[face.material].set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				groups[face.material].add_vertex(_vec(face.points[i]) - pivot)
		for key in groups:
			var mesh := MeshInstance3D.new()
			mesh.mesh = groups[key].commit()
			mesh.material_override = _material(area, str(key))
			hinge.add_child(mesh)
		# Leaf collider: the native template box (width x height x depth) at the placement, turned by its heading.
		var body := StaticBody3D.new()
		body.name = "Leaf"
		body.collision_layer = Assemblies.SCENERY_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(row.size[0]), float(row.size[1]), float(row.size[2]))
		shape.shape = box
		body.add_child(shape)
		hinge.add_child(body)
		body.position = _vec(row.origin) - pivot + Vector3(0, float(row.size[1]) / 2.0, 0)
		body.rotation.y = -float(row.heading) / 65536.0 * TAU
		leaves[id] = {"hinge": hinge, "row": row}
		angle[id] = 0.0
		target_word[id] = -1
	host.player.collision_mask |= Assemblies.SCENERY_LAYER
	var loaded: RefCounted = NativeHost.new()
	var native_error: String = str(loaded.call("load_area", NATIVE))
	if not native_error.is_empty():
		for id in leaves: _pose(id)
		return "Dark Halls doors: native scripts not loaded (%s); run tools/prepare_native_scripts.py --all --output-root <project>." % native_error
	native = loaded
	for id in leaves: native.call("bind_target", "0x20:" + str(id), "movable:" + str(id))
	native.connect("object_state_changed", _on_native_field)
	native.connect("sound_request", _on_native_sound)
	restore_from_quests()
	return ""

func _on_native_field(ref: String, field_name: String, value: int) -> void:
	if field_name != NativeHost.FIELD_TRAVEL or not ref.begins_with("movable:"): return
	var id: String = ref.get_slice(":", 1)
	if leaves.has(id): target_word[id] = value

func _on_native_sound(request: int) -> void:
	sound_log.append(request)
	print("Dark Halls doors: native sound request %d (logged; sound is not hosted yet)" % request)

## The doors' native fields and the opcode-198 array, saved beside "open"/"locked".
func _store_native() -> void:
	if native == null: return
	var saved := {}
	for id in leaves:
		var fields := {}
		# Only known fields: the constructor does not state the travel word, so it is absent until opcode 1 writes it.
		for name in NATIVE_FIELDS:
			var value: int = int(native.call("field", "movable:" + str(id), name, -1))
			if value >= 0: fields[name] = value
		saved["movable:" + str(id)] = fields
		state()[id].open = int(fields.get("travel_0x50", 0)) != 0 and not bool(state()[id].locked)
	var locals := {}
	var host_locals: Dictionary = native.get("locals")
	for index in host_locals: locals[str(index)] = int(host_locals[index])
	saved["locals"] = locals
	state().native = saved

func _material(area: Dictionary, key: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if area.materials.has(key):
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir() + "/" + area.materials[key]))
		if key in area.get("alpha_cutout_materials", []): mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.albedo_color = host.TINT
	return mat

func state() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_doors") is Dictionary:
		var fresh := {"trap": false}
		for row in source.doors: fresh[str(int(row.movable))] = {"open": false, "locked": false}
		quests.dark_halls_doors = fresh
	return quests.dark_halls_doors

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.size() != src.doors.size() + 1 + int(value.has("native")) or not value.get("trap") is bool: return "Invalid Dark Halls doors."
	if value.has("native") and not _valid_native(value.native, src): return "Invalid Dark Halls doors."
	for row in src.doors:
		var d: Variant = value.get(str(int(row.movable)))
		if not d is Dictionary or d.size() != 2 or not d.get("open") is bool or not d.get("locked") is bool or (d.open and d.locked): return "Invalid Dark Halls doors."
	return ""

static func _integral(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and float(v) >= 0.0 and float(v) <= 65535.0

static func _valid_native(value: Variant, src: Dictionary) -> bool:
	if not value is Dictionary or value.size() != src.doors.size() + 1 or not value.get("locals") is Dictionary: return false
	for row in src.doors:
		var fields: Variant = value.get("movable:" + str(int(row.movable)))
		if not fields is Dictionary or fields.is_empty(): return false
		for name in fields:
			if not str(name) in NATIVE_FIELDS or not _integral(fields[name]): return false
	for key in value.locals:
		if not str(key).is_valid_int() or not _integral(value.locals[key]) or float(value.locals[key]) > 255.0: return false
	return true

## Reads do not create the entry (loading must not change the quests).
func _saved(id: String) -> Dictionary:
	var saved: Variant = host.quest_state.get("dark_halls_doors")
	return saved[id] if saved is Dictionary and saved.get(id) is Dictionary else {"open": false, "locked": false}
func is_open(id: String) -> bool: return bool(_saved(id).open)
func is_locked(id: String) -> bool: return bool(_saved(id).locked)

## Rebuilds the host from the native constructor state, then the save: its "native" fields, or for an older save
## the mapping open -> +0x25 1 and the full travel word (adapter, docs/DEVIATIONS.md). Leaves snap to the result.
func restore_from_quests() -> void:
	if native != null:
		native.call("reset_state")
		var saved: Variant = host.quest_state.get("dark_halls_doors")
		var stored: Variant = saved.get("native") if saved is Dictionary else null
		for id in leaves:
			var ref := "movable:" + str(id)
			if stored is Dictionary:
				for name in stored[ref]: native.call("set_field", ref, str(name), int(stored[ref][name]))
			elif is_open(id):
				var attrs: Dictionary = (native.get("attributes") as Dictionary).get(ref, {})
				native.call("set_field", ref, "byte_0x25", 1)
				native.call("set_field", ref, "travel_0x50", (int(attrs.get("angle_word", 0)) * 100) / 100)
		if stored is Dictionary:
			for key in stored.locals: native.call("set_local", int(key), int(stored.locals[key]))
	for id in leaves:
		target_word[id] = int(native.call("field", "movable:" + str(id), "travel_0x50", -1)) if native != null else -1
		angle[id] = _target_degrees(id)
		_pose(id)

## Unsigned target angle: travel word * 360 / 65536 degrees (21845 -> 119.998).
func _target_degrees(id: String) -> float:
	# An unknown travel word (never written) leaves the leaf in its placement pose.
	if int(target_word[id]) < 0: return 0.0
	return float(target_word[id]) * 360.0 / 65536.0

func _pose(id: String) -> void:
	var row: Dictionary = leaves[id].row
	leaves[id].hinge.rotation.y = -float(row.sign) * deg_to_rad(float(angle[id]))

## Kind4 use: state0 -> open, state1 -> shut; locked (state2): nothing but the feedback.
func use(id: String) -> bool:
	if not leaves.has(id): return false
	if is_locked(id):
		if host.has_method("save_feedback"): host.save_feedback("The door is locked.")
		return true
	if native == null: return true
	native.call("fire_event", "movable:" + str(id), 4, {"arg_c": 0, "context": "movable:" + str(id)})
	_store_native()
	return true

## Kind 9. One click enqueues one record. The third hit on either door writes travel 21845. The quest lock is untouched.
func bash(id: String) -> bool:
	if not leaves.has(id) or native == null: return false
	var hit: Dictionary = {"word0": BASH_WORD0, "word2": BASH_WORD2, "dword_26": BASH_DWORD, "dword_1e": 0, "global_23331": 0}
	native.call("fire_event", "movable:" + str(id), 9, hit)
	_store_native()
	return true

## The door leaf in front of the camera within reach, or "".
func aimed() -> String:
	var cam: Camera3D = host.camera
	var best := ""
	var best_dot := FACING
	for id in leaves:
		var row: Dictionary = leaves[id].row
		var point: Vector3 = (leaves[id].hinge.get_node("Leaf") as Node3D).global_position
		var offset := point - cam.global_position
		if offset.length() > REACH: continue
		var dot := (-cam.global_basis.z).dot(offset.normalized())
		if dot > best_dot: best_dot = dot; best = id
	return best

func _in_trap() -> bool:
	var t: Dictionary = source.trap
	var p: Vector3 = host.player.position
	var polygon := PackedVector2Array()
	for q in t.polygon: polygon.append(Vector2(q[0], q[1]))
	return absf(p.y - Form.FOOT_OFFSET - float(t.floor)) < 2.0 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)

## Region1338 g794: door57 -> 0 and state 2 (locked); actor73 moved beside the trap (op18) and woken (op13).
func spring_trap() -> bool:
	if bool(state().trap): return false
	var t: Dictionary = source.trap
	var door := str(int(t.door))
	state().trap = true
	state()[door].open = false
	state()[door].locked = true
	# Group 794's region slot was not entered, and opcode 13 index 12 drops the group. Apply the proven prefix.
	if native != null:
		var ran: Dictionary = native.call("execute_group", 0, int(t.group)) as Dictionary
		trap_group = str(ran.get("status", ""))
		trap_reason = ""
		var reasons: Variant = ran.get("reasons", [])
		if reasons is Array:
			for item in reasons:
				trap_reason += str(item) + " "
		if trap_group == "ran":
			target_word[door] = int(native.call("field", "movable:" + door, "travel_0x50", 0))
		else:
			native.call("set_field", "movable:" + door, "travel_0x50", 0)
			native.call("set_field", "movable:" + door, "byte_0x25", TRAP_STATE)
			target_word[door] = 0
			sound_log.append(TRAP_SOUND)
			print("Dark Halls doors: native sound request %d (logged; the group did not run)" % TRAP_SOUND)
		_store_native()
	var pop = host.get("creatures")
	if pop != null and is_instance_valid(pop) and pop.state.actors.has(t.actor) and int(pop.state.actors[t.actor].health) > 0:
		pop.state.actors[t.actor].position = [float(t.actor_to[0]), float(t.floor), float(t.actor_to[1])]
		pop.state.actors[t.actor].woken = true
		pop.sync_quests()
		pop.present()
	if host.has_method("save_feedback"): host.save_feedback("The door slams shut behind you!")
	return true

## Actor73 kind6 value10 (its end): door57 state 0.
func _check_unlock() -> void:
	var t: Dictionary = source.trap
	var door := str(int(t.door))
	if not is_locked(door): return
	var pop = host.get("creatures")
	if pop == null or not is_instance_valid(pop) or not pop.state.actors.has(t.actor) or int(pop.state.actors[t.actor].health) == 0:
		state()[door].locked = false
		# The SHADE's end: actor73 kind6 value10 runs group 15750 (door 57 +0x25 = 0); group 15756 (opcode 6) is unhosted.
		if native != null:
			native.call("fire_event", "actor:" + str(t.actor), 6, {"caller_byte": 10})
			_store_native()

func _physics_process(delta: float) -> void:
	if host == null or not host.get("ready_for_review"): return
	var saved: Variant = host.quest_state.get("dark_halls_doors")
	if not (saved is Dictionary and bool(saved.get("trap", false))) and host.player.is_on_floor() and _in_trap(): spring_trap()
	_check_unlock()
	for id in leaves:
		var target := _target_degrees(id)
		if is_equal_approx(float(angle[id]), target): continue
		# Adapter: the native swing speed is not proven; the leaf keeps the earlier full swing per SWING_SECONDS.
		angle[id] = move_toward(float(angle[id]), target, float(leaves[id].row.swing_degrees) / SWING_SECONDS * delta)
		_pose(id)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or host.flying: return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# Headless has no window, so a captured mouse cannot stick. A real window still requires it.
	var headless := DisplayServer.get_name() == "headless"
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if not captured: return
		var id := aimed()
		if not id.is_empty() and use(id): get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not captured and not headless: return
		var chop := aimed()
		if not chop.is_empty() and bash(chop): get_viewport().set_input_as_handled()
