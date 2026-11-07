extends Node3D
## L1_DC control136, the dying old orc (tools/prepare_cave_old_orc.py: template20 -> resource311 orc-diee.vqa).
## Playtest 2026-10-17 report11:02:43 "here should be the old ork speaking to Luther": no owner hosted it.
## Source groups only: entering region1350/1859 (local3==0) loads the movie and loops its Loiter loop0; regions838/1349
## clear it. E on the orc at state0/2/4 runs the viewpoint/talk groups (segments 1/3/5 = OR450-453/454-460/461-462,
## played once), their ends return to the Loiter loops 2/4; the last line ends with clear + state7 (gone).
## A landed hit (kind9 masks 0/0, one-shot) jumps to the last line. Adapters are listed in the source JSON.
const SOURCE := "res://scripts/lol2/cave_old_orc_source.json"
const MovieFacing := preload("res://scripts/lol2/placed_movie_facing.gd")
const Forms := preload("res://scripts/lol2/player_form_rules.gd")
const REACH := 140.0
const SPARK_DAMAGE := 8
const TICKS := 60.0
var host: Node3D
var source: Dictionary
var state: Dictionary = {}
var frames: Array[ImageTexture] = []
## The orc is an indexed billboard on the world layer (2026-10-31, report 09-19-01): the Cave draws through index buffers and the
## host palette, so the earlier screen overlay (layer-21 TextureRect) could not be occluded by the stone prop in front of the
## orc. The producer quantises each movie frame to the Cave palette (source.index_frames); the quad uses the indexed sprite shader.
var picture: MeshInstance3D
var picture_material: ShaderMaterial
var voice: AudioStreamPlayer3D
var body: StaticBody3D
var effects: Array = []

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE)

static func load_source(path: String = SOURCE) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func initial(src: Dictionary) -> Dictionary:
	var inside := {}
	for r in src.regions: inside[str(int(r.region))] = false
	return {"version":1,"state":0,"local3":0,"local51":0,"shared0":0,"clip":{"segment":-1,"repeat":false,"elapsed":0.0},
		"inside":inside,"timer":{"enabled":false,"left":0},"spent":[],"locked":false,"receipts":[]}

static func _whole(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and int(v) >= low and int(v) <= high

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.get("version") != 1: return "Invalid old orc version."
	if value.size() != 11: return "Invalid old orc fields."
	if not _whole(value.get("state"), 0, 7) or int(value.state) == 5: return "Invalid old orc state."
	for key in ["local3","local51"]:
		if not _whole(value.get(key), 0, 1): return "Invalid old orc " + key + "."
	if not _whole(value.get("shared0"), 0, 255): return "Invalid old orc shared0."
	var c = value.get("clip")
	if not c is Dictionary or c.size() != 3 or not _whole(c.get("segment"), -1, src.loops.size() - 1) or not c.get("repeat") is bool: return "Invalid old orc clip."
	if not (c.get("elapsed") is int or c.get("elapsed") is float) or not is_finite(float(c.elapsed)) or float(c.elapsed) < 0 or float(c.elapsed) > 60.0: return "Invalid old orc clip clock."
	var inside = value.get("inside")
	if not inside is Dictionary or inside.size() != src.regions.size(): return "Invalid old orc regions."
	for r in src.regions:
		if not inside.get(str(int(r.region))) is bool: return "Invalid old orc regions."
	var t = value.get("timer")
	if not t is Dictionary or t.size() != 2 or not t.get("enabled") is bool or not _whole(t.get("left"), 0, 1 << 20): return "Invalid old orc timer."
	var spent = value.get("spent")
	if not spent is Array or spent.size() > 2: return "Invalid old orc spent records."
	for g in spent:
		if not _whole(g, 0, 65535) or int(g) not in [11004, 11068]: return "Invalid old orc spent records."
	if not value.get("locked") is bool or not value.get("receipts") is Array or value.receipts.size() > 64: return "Invalid old orc latches."
	for receipt in value.receipts:
		if not receipt is String or receipt.length() > 64: return "Invalid old orc receipt."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := {"version":1,"state":int(value.state),"local3":int(value.local3),"local51":int(value.local51),"shared0":int(value.shared0),
		"clip":{"segment":int(value.clip.segment),"repeat":bool(value.clip.repeat),"elapsed":snappedf(float(value.clip.elapsed),1.0/4096)},
		"inside":{},"timer":{"enabled":bool(value.timer.enabled),"left":int(value.timer.left)},"spent":[],"locked":bool(value.locked),"receipts":[]}
	for k in value.inside: out.inside[str(k)] = bool(value.inside[k])
	for g in value.spent: out.spent.append(int(g))
	for r in value.receipts: out.receipts.append(str(r))
	return out

## Predicates of the pinned groups: owner state, local3/local51 equalities and their AND.
static func test(s: Dictionary, p: Variant) -> bool:
	if p == null: return true
	if str(p.op) == "AND": return test(s, p.left.expression) and test(s, p.right.expression)
	var left: Dictionary = p.left
	var have: int = int(s.state) if left.has("owner_state") else int(s.get("local" + str(int(left.local)), 0))
	return str(p.op) == "==" and have == int(p.right.immediate)

static func segment_seconds(src: Dictionary, segment: int) -> float:
	var loop: Dictionary = src.loops[segment]
	return float(int(loop.last) - int(loop.first) + 1) / float(src.fps)

## Runs one group; returns presentation effects (view, voice restart).
static func run(s: Dictionary, src: Dictionary, commands: Array) -> Array:
	var out: Array = []
	for hex in commands:
		var b: PackedByteArray = str(hex).hex_decode()
		match int(b[0]):
			0x12:  # op18 player viewpoint: x word4, y word6 (negated), h word8 (0 here: the host keeps the floor)
				out.append({"type":"view","position":[b.decode_s16(4), b.decode_s16(8), -b.decode_s16(6)]})
			0x02:
				if int(b[1]) == 1 and int(b[4]) in [0x26, 0x27]: s.locked = int(b[4]) == 0x26
				else: _receipt(s, hex)
			0xc6: s["local" + str(int(b[4]))] = int(b[5])
			0xce: s.shared0 = int(b[5])
			0x08:
				match int(b[4]):
					0: pass  # load: the movie resource is resident
					1: s.clip = {"segment":-1,"repeat":false,"elapsed":0.0}; out.append({"type":"clip"})
					7: s.clip.repeat = b.decode_u16(6) != 0
					10: s.clip.segment = b.decode_u16(6); s.clip.elapsed = 0.0; out.append({"type":"clip"})
					_: _receipt(s, hex)
			0x0e:
				if int(b[4]) == 3 and not s.timer.enabled: s.timer = {"enabled":true,"left":int(src.timer.countdown)}
				elif int(b[4]) == 4: s.timer.enabled = false
			0x10: s.state = int(b[4])
			_: _receipt(s, hex)
	return out

static func _receipt(s: Dictionary, hex: String) -> void:
	if not hex in s.receipts and s.receipts.size() < 64: s.receipts.append(hex)

## Dispatch every record of a kind whose predicate holds at queue time (kinds 2/4/6); kind9 runs the first admitted.
static func dispatch(s: Dictionary, src: Dictionary, kind: int) -> Array:
	var queued: Array = []
	for r in src.records:
		if int(r.kind) != kind or not test(s, r.predicate): continue
		if kind == 9 and int(r.group) in s.spent: continue
		queued.append(r)
		if kind == 9: break
	var out: Array = []
	for r in queued:
		if kind == 9: s.spent.append(int(r.group))  # mode 0x84: one-shot bit 0x80
		out.append_array(run(s, src, r.commands))
	return out

static func shown(s: Dictionary) -> bool:
	return int(s.clip.segment) >= 0

static func use(s: Dictionary, src: Dictionary) -> Array:
	return dispatch(s, src, 4) if shown(s) else []

static func hit(s: Dictionary, src: Dictionary, damage: int) -> Array:
	return dispatch(s, src, 9) if shown(s) and damage > 0 else []

static func region_step(s: Dictionary, src: Dictionary, point: Vector2, height: float) -> Array:
	var out: Array = []
	for r in src.regions:
		var polygon := PackedVector2Array()
		for v in r.polygon: polygon.append(Vector2(v[0], v[1]))
		var inside: bool = height >= float(r.floor_min) - 4 and height <= float(r.floor_max) + 48 and Geometry2D.is_point_in_polygon(point, polygon)
		var key := str(int(r.region))
		if inside and not s.inside[key] and test(s, r.predicate): out.append_array(run(s, src, r.commands))
		s.inside[key] = inside
	return out

## Clip clock and the kind2 timer (60 ticks/s); a non-repeating segment end raises kind6.
static func tick(s: Dictionary, src: Dictionary, delta: float) -> Array:
	var out: Array = []
	if shown(s):
		var length := segment_seconds(src, int(s.clip.segment))
		s.clip.elapsed = snappedf(float(s.clip.elapsed) + delta, 1.0 / 4096)
		if float(s.clip.elapsed) >= length:
			if bool(s.clip.repeat): s.clip.elapsed = fmod(float(s.clip.elapsed), length); out.append({"type":"clip"})
			else:
				s.clip.elapsed = length
				out.append_array(dispatch(s, src, 6))  # without a matching record the clip holds its last frame
	if s.timer.enabled:
		s.timer.left = int(s.timer.left) - int(roundf(delta * TICKS))
		if int(s.timer.left) <= 0:
			s.timer.left = int(src.timer.fixed) * int(TICKS)
			out.append_array(dispatch(s, src, 2))
	return out

func setup(walkthrough: Node3D) -> String:
	name = "CaveOldOrc136"
	host = walkthrough
	process_mode = Node.PROCESS_MODE_ALWAYS
	source = load_source()
	if source.is_empty() or int(source.get("version", 0)) != 1: return "Invalid old orc source."
	if not source.get("index_frames") is Array or source.index_frames.size() != source.frames.size(): return "Old orc index frames missing."
	if FileAccess.get_sha256(str(source.index_palette)) != str(source.index_palette_sha256): return "Old orc palette hash mismatch."
	for row in source.index_frames:
		if FileAccess.get_sha256(row.file) != str(row.sha256): return "Old orc frame hash mismatch."
		frames.append(ImageTexture.create_from_image(Image.load_from_file(row.file)))
	if FileAccess.get_sha256(source.audio) != str(source.voice_sha256): return "Old orc voice hash mismatch."
	var quad := QuadMesh.new()
	quad.size = Vector2(float(source.dimensions[0]), float(source.dimensions[1]))
	quad.center_offset = Vector3(0, float(source.dimensions[1]) / 2.0, 0)
	picture = MeshInstance3D.new(); picture.name = "OldOrcPicture"; picture.mesh = quad; picture.layers = 2
	picture_material = ShaderMaterial.new(); picture_material.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
	picture_material.set_shader_parameter("sprite", true)
	picture.material_override = picture_material; picture.visible = false; picture.position = anchor(); add_child(picture)
	if host.has_method("_copy_occluders"): host._copy_occluders(picture)
	voice = AudioStreamPlayer3D.new(); voice.stream = AudioStreamWAV.load_from_file(source.audio); voice.unit_size = 160; voice.max_distance = 1400
	voice.position = anchor(); add_child(voice)
	body = StaticBody3D.new(); body.collision_layer = 2; body.collision_mask = 0; body.name = "OldOrcHit"
	body.set_meta("spark_receiver", SparkTarget.new(self))
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(float(source.dimensions[0]) * 0.6, float(source.dimensions[1]) * 0.8, 40); shape.shape = box
	shape.position.y = float(source.dimensions[1]) * 0.4
	body.add_child(shape); body.position = anchor(); add_child(body); host.player.add_collision_exception_with(body)
	return restore(null)

class SparkTarget extends RefCounted:
	var owner_node
	func _init(o) -> void: owner_node = o
	func receive_spark() -> bool: return owner_node.receive_hit(owner_node.SPARK_DAMAGE)

func anchor() -> Vector3:
	return Vector3(source.position[0], source.position[1], source.position[2]) + host.native_translation

func checkpoint() -> Dictionary: return canonical(state)

func restore(saved: Variant) -> String:
	var value = initial(source) if saved == null else saved
	var error := validate(value, source)
	if not error.is_empty(): return error
	state = canonical(value)
	_sync_voice(true)
	present()
	return ""

func locked() -> bool: return state != null and bool(state.get("locked", false))

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func apply(rows: Array) -> void:
	for e in rows:
		effects.append(e)
		if effects.size() > 64: effects.pop_front()
		match str(e.type):
			"clip": _sync_voice(true)
			"view":
				var p: Array = e.position
				var target: Vector3 = Vector3(float(p[0]), host.player.global_position.y - host.native_translation.y, float(p[2])) + host.native_translation
				var ray := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 64, target - Vector3.UP * 256, 1, [host.player.get_rid()])
				var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty(): target.y = hit.position.y + preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
				else: target.y = host.player.global_position.y
				host.player.global_position = target; host.player.velocity = Vector3.ZERO
				var a := anchor()
				host.player.look_at(Vector3(a.x, target.y, a.z)); host.camera.rotation = Vector3.ZERO

func _sync_voice(seek: bool) -> void:
	if voice == null: return
	if not shown(state): voice.stop(); return
	var loop: Dictionary = source.loops[int(state.clip.segment)]
	var at := float(loop.first) / float(source.fps) + float(state.clip.elapsed)
	var end := float(int(loop.last) + 1) / float(source.fps)
	if at >= end - 0.01: voice.stop(); return
	if seek or not voice.playing: voice.play(at)
	voice.stream_paused = not _world_active()

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	var p: Vector3 = host.player.global_position - host.native_translation
	apply(region_step(state, source, Vector2(p.x, p.z), p.y - preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET))
	apply(tick(state, source, delta))

func frame_index() -> int:
	if not shown(state): return -1
	var loop: Dictionary = source.loops[int(state.clip.segment)]
	return mini(int(loop.last), int(loop.first) + int(float(state.clip.elapsed) * float(source.fps)))

func present() -> void:
	if picture == null: return
	var index := frame_index()
	var cam: Camera3D = host.camera
	var a := anchor()
	# Occlusion and facing come from the world draw now (depth against the stone, billboard in the sprite shader).
	var visible_now := index >= 0 and cam != null and a.distance_to(cam.global_position) < 1400.0
	picture.visible = visible_now
	if not visible_now: return
	picture_material.set_shader_parameter("indices", frames[index])
	var mirrored := MovieFacing.mirrored(cam, MovieFacing.control_heading(str(source.control_hex)))
	picture_material.set_shader_parameter("uv_scale", Vector2(-1.0 if mirrored else 1.0, 1.0))
	picture_material.set_shader_parameter("uv_offset", Vector2(1.0 if mirrored else 0.0, 0.0))

func aimed() -> bool:
	if not shown(state) or host.flying: return false
	var point := anchor() + Vector3.UP * float(source.dimensions[1]) * 0.4
	var from: Vector3 = host.camera.global_position; var offset := point - from
	if offset.length() > REACH or offset.length() < 0.01 or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.9: return false
	var ray := PhysicsRayQueryParameters3D.create(from, point, 1, [host.player.get_rid()])
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Enter skips the line now playing (dialogue_skip.gd): a single-pass clip segment goes to its last step and the next tick
## fires its source end event; repeating (idle) segments are not lines and are left alone.
func skip_line() -> bool:
	if state == null or not shown(state) or bool(state.clip.repeat) or not _world_active(): return false
	var length := segment_seconds(source, int(state.clip.segment))
	if float(state.clip.elapsed) >= length - 1.0 / 4096: return false
	state.clip.elapsed = length - 1.0 / 4096
	voice.stop()
	return true

func use_orc() -> bool:
	if not _world_active() or not aimed(): return false
	var rows := use(state, source)
	if rows.is_empty() and not shown(state): return false
	apply(rows); present(); return true

func receive_hit(damage: int) -> bool:
	if not shown(state): return false
	apply(hit(state, source, damage)); present(); return true

func strike() -> bool:
	if host.flying or not _world_active() or not aimed(): return false
	if host.player_form == 0 and host.equipped_item == "": return false
	return receive_hit(Forms.melee_damage(int(host.player_form), host.equipped_item != ""))

func _input(event: InputEvent) -> void:
	if locked() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion: get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not _world_active() or (host.get("roach") != null and host.roach.model.player_health <= 0): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike():
		preload("res://scripts/lol2/combat_feedback.gd").landed(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use_orc():
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not _world_active(): return
	advance(delta)

func _process(_delta: float) -> void:
	if voice != null: voice.stream_paused = not _world_active()
	present()
