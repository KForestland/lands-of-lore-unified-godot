extends Node3D
## L3_DH torch switch and the 35 Museum wall torches (tools/prepare_museum_torches.py, docs/museum-torches.md).
## Saved as checkpoint "museum_torches".
## Movable52 (the wall plate in niche 1475/1476): E with an empty hand = its kind4 mode0 record, prop61 state1.
## Prop61 (the small pilot flame): kind9 masks 0x0011/0x0001, threshold1 mode4, one-shot, owner state1 only. It
## flares (selector1), plays 740, awards one magic level (op2 sub0x10) and raises event20; group70 then hits all
## 35 torches (op19 masks 1/1 damage 5), plays 411 at prop63 and sets prop61 state1.
## Each torch: kind9 masks 0x0001 or 0x0011 / 0x0001, threshold1 mode4, not one-shot: selector2 (lit) and sound 740,
## so a single torch can also be lit with Spark.
## Template22 draws its state and the chained next state at one anchor (F1A94 byte11 bit0): holder 954 + embers 949
## unlit, holder 939 + flame 944 lit. The flag-0x10 overlays are drawn additively (presentation adapter).
const SOURCE := "res://scripts/lol2/museum_torches_source.json"
const ROOT := "res://assets/lol2/generated/museum_torches/"
const FPS := 10.0
const SPARK_DAMAGE := 8
const PILOT := "61"
## My Journal (owner 2026-10-28): Classic keeps the native order (the niche plate first, then Spark on the small flame);
## Sparking the flame before the plate does nothing, so a vague hint, data only for the journal. Enhanced: undecided.
const JOURNAL_HINTS := [
	{"when":"pilot_spark_before_plate","flag":"pilot_state","hint":"The little flame by the niche would not take my spark. Something in that niche must wake it first.","enhanced_guard":"undecided (owner 2026-10-28: too early to decide)"}]
var host: Node3D
var source: Dictionary
var state: Dictionary = initial()
var textures := {}  # art key -> Array[ImageTexture]
var materials := {}  # art key -> StandardMaterial3D (shared by every torch)
var torches := {}  # id -> {"base": MeshInstance3D, "overlay": MeshInstance3D}
var pilot: MeshInstance3D
var plate: MeshInstance3D
var bodies := {}  # id -> StaticBody3D
var voices := {}  # id -> AudioStreamPlayer3D (740)
var all_voice: AudioStreamPlayer3D  # 411 at prop63
var clock := 0.0
var frame := -1
var awards := 0  # magic level awards applied in this session (tests)

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "740.wav") and FileAccess.file_exists(ROOT + "411.wav")

static func load_source() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) if FileAccess.file_exists(SOURCE) else null
	return parsed if parsed is Dictionary and int(parsed.get("version", 0)) == 1 else {}

## pilot_state = prop61 owner state (byte25); pilot_spent = its one-shot hit record has fired (selector1 shown).
static func initial() -> Dictionary:
	return {"version": 1, "pilot_state": 0, "pilot_spent": false, "lit": []}

static func validate(value: Variant) -> String:
	if value == null: return ""  # older saves predate the torches
	if not value is Dictionary or value.size() != 4 or value.get("version") != 1: return "Invalid museum torches."
	var s = value.get("pilot_state")
	if not (s is int or s is float) or not is_finite(float(s)) or float(s) not in [0.0, 1.0]: return "Invalid museum torch switch."
	if not value.get("pilot_spent") is bool: return "Invalid museum pilot flame."
	if value.pilot_spent and int(s) != 1: return "Inconsistent museum pilot flame."
	var lit = value.get("lit")
	if not lit is Array or lit.size() > 35: return "Invalid lit museum torches."
	var src := load_source()
	var known: Dictionary = src.get("torches", {})
	var seen := {}
	for id in lit:
		if not (id is int or id is float) or float(id) != floorf(float(id)) or not known.has(str(int(id))) or seen.has(int(id)): return "Invalid lit museum torch."
		seen[int(id)] = true
	if value.pilot_spent and seen.size() != known.size(): return "Inconsistent museum torches."
	return ""

static func canonical(value: Variant) -> Dictionary:
	if value == null: return initial()
	var lit: Array = []
	for id in value.lit: lit.append(int(id))
	lit.sort()
	return {"version": 1, "pilot_state": int(value.pilot_state), "pilot_spent": bool(value.pilot_spent), "lit": lit}

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "MuseumTorches"
	host = owner
	source = load_source()
	if source.is_empty() or source.get("torches", {}).size() != 35: return "Invalid museum torches source."
	for key in source.art:
		if key == "pilot": continue
		var list: Array[ImageTexture] = []
		for file in source.art[key]:
			if FileAccess.get_sha256(ROOT + str(file)) != str(source.files[file]): return "Museum torch art changed: " + str(file)
			list.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(file))))
		textures[key] = list
	textures["pilot"] = textures["flame"]
	for key in ["holder_unlit", "holder_lit"]: materials[key] = _material(false)
	for key in ["embers", "flame", "pilot", "flare"]: materials[key] = _material(true)
	var t: Dictionary = source.templates["22"]
	var light := AudioStreamWAV.load_from_file(ROOT + "740.wav")
	for id in source.order:
		var key := str(int(id))
		var row: Dictionary = source.torches[key]
		var at := Vector3(row.position[0], row.position[1], row.position[2])
		var layers := {}
		for layer in ["base", "overlay"]:
			var mesh := _quad(t.unlit, "Torch%s%s" % [key, layer.capitalize()])
			mesh.position = at
			add_child(mesh)
			layers[layer] = mesh
		torches[key] = layers
		bodies[key] = _hit_body("TorchHit" + key, at + Vector3(0, float(t.unlit.top) / 2.0, 0), _cylinder(10.0, float(t.unlit.top)), key)
		var voice := AudioStreamPlayer3D.new(); voice.stream = light; voice.unit_size = 64.0; voice.position = at; add_child(voice)
		voices[key] = voice
	var p: Dictionary = source.pilot
	var pilot_at := Vector3(p.position[0], p.position[1], p.position[2])
	pilot = _quad(source.templates["42"].pilot, "PilotFlame")
	pilot.position = pilot_at
	add_child(pilot)
	var sphere := SphereShape3D.new(); sphere.radius = 8.0
	bodies[PILOT] = _hit_body("PilotHit", pilot_at + Vector3(0, 4, 0), sphere, PILOT)
	var pilot_voice := AudioStreamPlayer3D.new(); pilot_voice.stream = light; pilot_voice.unit_size = 64.0; pilot_voice.position = pilot_at; add_child(pilot_voice)
	voices[PILOT] = pilot_voice
	all_voice = AudioStreamPlayer3D.new(); all_voice.stream = AudioStreamWAV.load_from_file(ROOT + "411.wav"); all_voice.unit_size = 64.0
	var at63: Array = source.torches[str(int(source.event20.sound.at))].position
	all_voice.position = Vector3(at63[0], at63[1], at63[2]); add_child(all_voice)
	plate = _plate()
	add_child(plate)
	return restore_checkpoint(saved)

func _material(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.render_priority = 1
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	return m

func _quad(g: Dictionary, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = QuadMesh.new()
	_shape(mesh, g)
	return mesh

func _shape(mesh: MeshInstance3D, g: Dictionary) -> void:
	var quad: QuadMesh = mesh.mesh
	quad.size = Vector2(float(g.right) - float(g.left), float(g.top) - float(g.bottom))
	quad.center_offset = Vector3((float(g.left) + float(g.right)) / 2.0, (float(g.bottom) + float(g.top)) / 2.0, 0)

func _cylinder(radius: float, height: float) -> CylinderShape3D:
	var c := CylinderShape3D.new(); c.radius = radius; c.height = height
	return c

class SparkTarget extends RefCounted:
	var owner_node; var id: String
	func _init(o, prop: String) -> void: owner_node = o; id = prop
	func receive_spark() -> bool: return owner_node.receive_hit(id, 1, 1, owner_node.SPARK_DAMAGE)

## Spark volume only (layer 2, no mask); the player never collides with it.
func _hit_body(label: String, at: Vector3, shape: Shape3D, id: String) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = label; body.collision_layer = 2; body.collision_mask = 0
	body.set_meta("spark_receiver", SparkTarget.new(self, id))
	var holder := CollisionShape3D.new(); holder.shape = shape; body.add_child(holder)
	body.position = at
	add_child(body)
	if host.get("player") != null and is_instance_valid(host.player): host.player.add_collision_exception_with(body)
	return body

## Movable52 state0 (child172, resource31): the six source faces, drawn still.
func _plate() -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in source.switch.faces:
		for i in [0, 1, 2, 0, 2, 3]:
			var q: Array = face.points[i]
			surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			surface.add_vertex(Vector3(q[0], q[1], q[2]))
	surface.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.name = "TorchSwitchPlate"; mesh.mesh = surface.commit()
	var shared = host.get("materials")
	if shared is Dictionary and shared.has("31"): mesh.material_override = shared["31"]
	else:
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var path := "res://assets/lol2/generated/museum_review/material_31.png"
		if FileAccess.file_exists(path): m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(path))
		mesh.material_override = m
	return mesh

func checkpoint() -> Dictionary: return canonical(state)

func restore_checkpoint(saved: Variant) -> String:
	var error := validate(saved)
	if not error.is_empty(): return error
	state = canonical(saved)
	for voice in voices.values(): voice.stop()
	if all_voice != null: all_voice.stop()
	frame = -1
	present()
	return ""

func is_lit(id: Variant) -> bool: return int(id) in state.lit

func present() -> void:
	var f := int(clock * FPS)
	for key in ["holder_lit", "embers", "flame", "flare"]:
		var list: Array = textures[key]
		materials[key].albedo_texture = list[f % list.size()]
	materials["holder_unlit"].albedo_texture = textures["holder_unlit"][0]
	materials["pilot"].albedo_texture = textures["pilot"][f % textures["pilot"].size()]
	for key in torches:
		var lit := is_lit(key)
		torches[key].base.material_override = materials["holder_lit" if lit else "holder_unlit"]
		torches[key].overlay.material_override = materials["flame" if lit else "embers"]
	var flared: bool = state.pilot_spent
	pilot.material_override = materials["flare" if flared else "pilot"]
	_shape(pilot, source.templates["42"].flare if flared else source.templates["42"].pilot)
	frame = f

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused

func _process(delta: float) -> void:
	var active := _world_active()
	for voice in voices.values(): voice.stream_paused = not active
	if all_voice != null: all_voice.stream_paused = not active
	if not active or not is_finite(delta) or delta <= 0: return
	clock = fmod(clock + delta, 3600.0)
	if int(clock * FPS) != frame: present()

## Native kind9 admission (AE2C8): masks (zero = wildcard), mode4 fires when durability - damage <= threshold 1.
## Torch durability is 1 and the pilot's 2, so any positive admitted hit fires; durability is not saved.
func receive_hit(id: String, mask0: int, mask2: int, damage: int) -> bool:
	if damage <= 0: return false
	if id == PILOT: return _hit_pilot(mask0, mask2, damage)
	if not source.torches.has(id): return false
	var row: Dictionary = source.torches[id]
	if (int(row.mask0) & mask0) == 0 or (1 & mask2) == 0: return true
	if int(row.durability) - damage > 1: return true
	_light(id)
	return true

func _light(id: String) -> void:
	if not is_lit(id):
		state.lit.append(int(id))
		state.lit.sort()
	voices[id].play()
	present()

func _hit_pilot(mask0: int, mask2: int, damage: int) -> bool:
	if (0x11 & mask0) == 0 or (1 & mask2) == 0: return true
	if int(source.pilot.durability) - damage > 1: return true
	if state.pilot_spent: return true  # one-shot cleared
	if int(state.pilot_state) != 1:  # predicate207 false: the flame will not take the spark before the plate
		preload("res://scripts/lol2/my_journal.gd").discover(host, "pilot_spark_before_plate")
		return true
	state.pilot_spent = true
	voices[PILOT].play()
	_award_magic_level()
	present()
	# op9 property21 queued event20 (group70, no predicate) runs after the hit group.
	var hit: Dictionary = source.event20.hit
	for id in source.order: receive_hit(str(int(id)), int(hit.mask0), int(hit.mask2), int(hit.damage))
	all_voice.play()
	state.pilot_state = int(source.event20.state)
	if host.has_method("save_feedback"): host.save_feedback("Fire leaps from the niche; every torch in the halls flares up.")
	return true

## Op2 player sub0x10 arg1 (D88CD): one magic level = thresholds[level] - experience (0 at level 30).
func _award_magic_level() -> void:
	var magic = host.get("starting_magic")
	if magic == null or not is_instance_valid(magic): return
	var saved: Dictionary = magic.magic_state()
	var thresholds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json"))
	var award := 0 if int(saved.player.level) >= 30 else maxi(0, int(thresholds.thresholds[int(saved.player.level)]) - int(saved.player.experience))
	var result: Dictionary = preload("res://scripts/lol2/player_property_rewards.gd").magic(saved, award)
	if result.has("error"): push_error(result.error); return
	magic.commit(result.checkpoint)
	awards += 1

func _ready_for_use() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("introduction_state") != "complete": return false
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	return _world_active()

## Within reach of the plate's centre and facing it; the pilot's Spark volume does not hide the plate.
func can_reach_switch() -> bool:
	var target := Vector3(source.switch.aim[0], source.switch.aim[1], source.switch.aim[2])
	var origin: Vector3 = host.camera.global_position
	var offset := target - origin
	if offset.length() > 96 or offset.length() < 0.01 or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.97: return false
	var query := PhysicsRayQueryParameters3D.create(origin, target + offset.normalized() * -2.0, preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	var skip: Array[RID] = [host.player.get_rid()]
	for body in bodies.values(): skip.append(body.get_rid())
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func offered() -> bool:
	return not state.pilot_spent and _ready_for_use() and str(host.hand_item) == "" and can_reach_switch()

## One aimed melee strike after the plate click. Spark stays on the same receive_hit path.
func strike_pilot() -> bool:
	if int(state.pilot_state) != 1 or bool(state.pilot_spent): return false
	if not host.has_method("melee_ready") or not host.melee_ready(): return false
	if not bodies.has(PILOT): return false
	var origin: Vector3 = host.camera.global_position
	var forward: Vector3 = -host.camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 96.0, 2)
	query.exclude = [host.player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != bodies[PILOT]: return false
	return receive_hit(PILOT, 0x11, 1, SPARK_DAMAGE)

## Kind4 mode0 (empty hand): op16 prop61 state1. Repeating it changes nothing.
func use() -> bool:
	if not offered(): return false
	state.pilot_state = 1
	if host.has_method("save_feedback"): host.save_feedback("The plate gives with a click.")
	return true

func interaction_hint() -> String:
	return "E — Press the wall plate" if offered() else ""
