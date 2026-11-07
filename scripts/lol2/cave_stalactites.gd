extends Node3D
## L1_DC template72 dripping stalactites, props 359/632/633/634 (tools/prepare_cave_stalactites.py), omitted by the
## recovered prop preview (playtest 2026-10-17, report10:55:42 "rock alcoves" looks straight at prop633).
## A landed hit runs the native AE2C8 scan over the prop's own kind9 records in source order; the first admitted
## record runs its group: selector/state (break), sound718, or once per level (shared local10) the fighting (op2
## sub7 -> D8A1C) or magic (sub8 -> D8B94) award of 10. kind3 selector events stop the owner's sounds (property16,
## B5401->E416C) or play 759. kind4 E (no hand in the Cave) plays 298 once per prop.
const SOURCE := "res://scripts/lol2/cave_stalactites_source.json"
const ROOT := "res://assets/lol2/generated/cave_stalactites/"
const REACH := 96.0
const FPS := 10.0
const SPARK_DAMAGE := 8
const Rewards = preload("res://scripts/lol2/player_property_rewards.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
var host: Node3D
var source: Dictionary
var state: Dictionary = {}
var sprites := {}
var bodies := {}
var textures := {}  # selector -> Array[ImageTexture]
var players := {}   # request -> AudioStreamPlayer3D per prop: "prop:request"
var clock := 0.0

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "718.wav")

static func initial(src: Dictionary) -> Dictionary:
	var props := {}
	for id in src.props: props[id] = {"selector":0,"state":0,"durability":int(src.props[id].durability),"used":false}
	return {"version":1,"local10":false,"props":props}

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.get("version") != 1 or not value.get("local10") is bool or not value.get("props") is Dictionary: return "Invalid stalactites."
	if value.props.size() != src.props.size(): return "Invalid stalactites."
	for id in src.props:
		var p = value.props.get(id)
		if not p is Dictionary or p.size() != 4 or not p.get("used") is bool: return "Invalid stalactite " + id
		for key in ["selector","state","durability"]:
			var n = p.get(key)
			if not (n is int or n is float) or not is_finite(float(n)) or float(n) != floorf(float(n)): return "Invalid stalactite " + id
		if int(p.selector) not in [0,1,2] or int(p.state) not in [0,1,3] or int(p.durability) > int(src.props[id].durability) or int(p.durability) < -1000: return "Invalid stalactite " + id
		# Source groups move selector and state together: 0/0, 1/1, 2/3.
		if [int(p.selector),int(p.state)] not in [[0,0],[1,1],[2,3]]: return "Stalactite selector/state disagree " + id
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := {"version":1,"local10":bool(value.local10),"props":{}}
	for id in value.props:
		var p: Dictionary = value.props[id]
		out.props[id] = {"selector":int(p.selector),"state":int(p.state),"durability":int(p.durability),"used":bool(p.used)}
	return out

func setup(walkthrough: Node3D) -> String:
	name = "CaveStalactites"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid stalactite source."
	for sel in source.template72.selectors:
		var list: Array[ImageTexture] = []
		for f in sel.frames: list.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
		textures[int(sel.selector)] = list
	var first: Dictionary = source.template72.selectors[0]
	var width: float = float(first.right) - float(first.left)
	var image: ImageTexture = textures[0][0]
	var height: float = width * float(image.get_height()) / float(image.get_width())
	for id in source.props:
		var row: Dictionary = source.props[id]
		var quad := QuadMesh.new(); quad.size = Vector2(width, height); quad.center_offset = Vector3(0, height / 2.0, 0)
		var mesh := MeshInstance3D.new(); mesh.mesh = quad; mesh.layers = 2; mesh.name = "Stalactite" + id
		mesh.material_override = host._indexed_material(ROOT + str(first.frames[0]))
		mesh.material_override.set_shader_parameter("sprite", true)
		mesh.position = host.point(row.position) + host.native_translation
		add_child(mesh)
		if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
		sprites[id] = mesh
		# Hit volume for melee aim and the Spark ray; the player never collides with it.
		var body := StaticBody3D.new(); body.collision_layer = 2; body.collision_mask = 0
		body.set_meta("spark_receiver", SparkTarget.new(self, id))
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(width * 0.5, height * 0.9, width * 0.5); shape.shape = box
		shape.position.y = height * 0.5
		body.add_child(shape); body.position = mesh.position
		add_child(body); host.player.add_collision_exception_with(body)
		bodies[id] = body
		for request in source.sounds:
			var player := AudioStreamPlayer3D.new(); player.stream = AudioStreamWAV.load_from_file(ROOT + str(source.sounds[request].file))
			player.unit_size = 64.0; mesh.add_child(player); players[id + ":" + request] = player
	return restore(null)

class SparkTarget extends RefCounted:
	var owner_node; var id: String
	func _init(o, prop: String) -> void: owner_node = o; id = prop
	func receive_spark() -> bool: return owner_node.receive_hit(id, 1, 1, owner_node.SPARK_DAMAGE)

func checkpoint() -> Dictionary: return canonical(state)

func restore(saved: Variant) -> String:
	var value = initial(source) if saved == null else saved
	var error := validate(value, source)
	if not error.is_empty(): return error
	state = canonical(value)
	for p in players.values(): p.stop()
	present()
	return ""

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func present() -> void:
	for id in sprites:
		var list: Array = textures[int(state.props[id].selector)]
		var texture: ImageTexture = list[int(clock * FPS) % list.size()]
		var mesh: MeshInstance3D = sprites[id]
		mesh.material_override.set_shader_parameter("indices", texture)
		if host.has_method("sync_render_source"): host.sync_render_source(mesh, texture)

func _process(delta: float) -> void:
	if not _world_active():
		for p in players.values(): p.stream_paused = true
		return
	for p in players.values(): p.stream_paused = false
	clock += delta
	present()

## Native kind9 admission (AE2C8): masks (zero = wildcard), mode4 threshold >= remaining, predicate; first match runs.
func receive_hit(id: String, mask0: int, mask2: int, damage: int) -> bool:
	if not state.props.has(id) or damage <= 0: return false
	var p: Dictionary = state.props[id]
	p.durability = int(p.durability) - damage
	for record in source.props[id].records:
		if int(record.kind) != 9: continue
		var raw: PackedByteArray = str(record.raw).hex_decode()
		var m0 := raw.decode_u16(4); var m2 := raw.decode_u16(6)
		if m0 != 0 and (m0 & mask0) == 0: continue
		if m2 != 0 and (m2 & mask2) == 0: continue
		if int(raw[8]) < int(p.durability): continue
		if not _predicate(id, record.predicate): continue
		_run(id, record.commands)
		return true
	return true

func _predicate(id: String, pred: Variant) -> bool:
	if pred == null: return true
	var left: Dictionary = pred.left
	var value := 0
	if left.has("owner_state"): value = int(state.props[id].state)
	elif int(left.get("local", -1)) == 10: value = 1 if state.local10 else 0
	elif int(left.get("local", -1)) == int(source.props[id].use_local): value = 1 if state.props[id].used else 0
	else: return false
	return str(pred.op) == "==" and value == int(pred.right.immediate)

func _run(id: String, commands: Array) -> void:
	for c in commands:
		var b: PackedByteArray = str(c).hex_decode()
		match int(b[0]):
			5: _select(id, int(b[4]))
			16: state.props[id].state = int(b[4])
			20: _sound(id, str(b.decode_u16(4)))
			198:
				if int(b[4]) == 10: state.local10 = true
				elif int(b[4]) == int(source.props[id].use_local): state.props[id].used = true
			2:
				if int(b[4]) == 7: _award_fighting(int(b[5]))
				elif int(b[4]) == 8: _award_magic(int(b[5]))
			9:
				if int(b[4]) == 16: _stop_sounds(id)
	present()

func _select(id: String, selector: int) -> void:
	state.props[id].selector = selector
	for record in source.props[id].records:
		if int(record.kind) == 3 and str(record.raw).substr(8, 2) == "%02x" % selector: _run(id, record.commands)

func _sound(id: String, request: String) -> void:
	var p = players.get(id + ":" + request)
	if p != null: p.play()

func _stop_sounds(id: String) -> void:
	for key in players:
		if key.begins_with(id + ":"): players[key].stop()

func _award_fighting(amount: int) -> void:
	var result: Dictionary = Rewards.fighting(host.quest_state, amount)
	if result.has("error"): push_error(result.error); return
	host.quest_state = preload("res://scripts/lol2/atlas_explored.gd").release(result.quests)

func _award_magic(amount: int) -> void:
	var magic = host.get("starting_magic")
	if magic == null: return
	var result: Dictionary = Rewards.magic(magic.magic_state(), amount)
	if result.has("error"): push_error(result.error); return
	magic.commit(result.checkpoint)

func aimed() -> String:
	var best := ""; var best_distance := INF
	for id in bodies:
		var target: Vector3 = sprites[id].global_position + Vector3(0, (sprites[id].mesh as QuadMesh).size.y * 0.5, 0)
		var delta: Vector3 = target - host.camera.global_position
		if delta.length() > REACH + 40.0 or delta.length() < 0.01: continue
		if (-host.camera.global_basis.z).dot(delta.normalized()) < 0.9: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, target, 1, [host.player.get_rid()])
		if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if delta.length() < best_distance: best = id; best_distance = delta.length()
	return best

## Armed melee (context 2/4) at an aimed stalactite in reach; the shared melee cooldown is not involved (prop hit).
func strike() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.player_form == 0 and host.equipped_item == "": return false
	var id := aimed()
	if id.is_empty(): return false
	return receive_hit(id, 2, 4, Forms.melee_damage(int(host.player_form), host.equipped_item != ""))

func use() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	var id := aimed()
	if id.is_empty(): return false
	for record in source.props[id].records:
		if int(record.kind) == 4 and _predicate(id, record.predicate):
			_run(id, record.commands)
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not _world_active() or (host.get("roach") != null and host.roach.model.player_health <= 0): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike():
		preload("res://scripts/lol2/combat_feedback.gd").landed(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use():
		get_viewport().set_input_as_handled()
