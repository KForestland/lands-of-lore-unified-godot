extends Node3D
## L1_DC tar pits (tools/prepare_cave_tar_fires.py): first pit props 465..471/640 with sequencer prop464, guard pit
## props 440..446/575..586 with sequencer prop439. The recovered prop preview omits these animated props (playtest
## 2026-10-17 report10:59:16 "tar pit should be able to be aflame": a bare black pool).
## A landed Spark (context 1/1) or a sequencer fire hit runs the native AE2C8 scan over the prop's kind9 records
## (masks 0x0011/0x0000: melee 2/4 is refused); the first admitted record runs: ignite (selector1, state1, sound462),
## advance its pit sequencer to selector1 (kind3 value1 starts its timer) and, in the guard pit, send prop223 its
## op19 fire hit. kind6 value3 (animation end) at state1 shows the burning loop (selector2). Each sequencer timer
## expiry at state1 adds one to its selector; kind3 value2..N hits the next tar prop, the last value stops the timer.
## Guard-pit selector2 is drawn by the existing scenic fire meshes (cave_scenic_guard_effects); this owner draws
## selectors 0/1 there and every selector in the first pit.
const SOURCE := "res://scripts/lol2/cave_tar_fires_source.json"
const ROOT := "res://assets/lol2/generated/cave_tar_fires/"
const FPS := 10.0
const TICKS := 60.0
const STEP := 256  # one native tick in timer units (1/256 tick)
const SPARK_DAMAGE := 8
const CHAIN_DAMAGE := 1 << 20  # op19 damage mode 0x70 leaves a pointer-sized value: any positive admits mode4
var host: Node3D
var source: Dictionary
var state: Dictionary = {}
var sprites := {}
var bodies := {}
var textures := {}  # descriptor -> Array[ImageTexture]
var voices := {}
var carry := 0.0
var prop223_hits := 0  # op19 fire hits delivered to prop223 (cave_scenic_guard runs its group2326)

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "462.wav")

static func initial(src: Dictionary) -> Dictionary:
	var props := {}
	for id in src.props: props[id] = {"selector":0,"state":0,"durability":int(src.props[id].durability),"clock":0.0}
	var seqs := {}
	for id in src.sequencers:
		var q: Dictionary = src.sequencers[id]
		# Cave arrival (kind6 value9, prop464 only) stops the timer; prop439's record starts stopped.
		seqs[id] = {"selector":0,"state":0,"enabled":bool(q.timer_enabled) and not bool(q.arrival_stops),"left":int(q.countdown),"seed":int(id) * 7919 + 1}
	return {"version":1,"props":props,"sequencers":seqs}

static func _whole(v: Variant, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and float(v) >= low and float(v) <= high

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or not value.get("props") is Dictionary or not value.get("sequencers") is Dictionary: return "Invalid tar fires."
	if value.props.size() != src.props.size() or value.sequencers.size() != src.sequencers.size(): return "Invalid tar fires."
	for id in src.props:
		var p = value.props.get(id)
		if not p is Dictionary or p.size() != 4: return "Invalid tar prop " + id
		if not _whole(p.get("selector"), 0, 2) or not _whole(p.get("state"), 0, 2) or not _whole(p.get("durability"), -(1 << 30), 255): return "Invalid tar prop " + id
		var c = p.get("clock")
		if not (c is int or c is float) or not is_finite(float(c)) or float(c) < 0 or float(c) > 3600: return "Invalid tar clock " + id
		# Source groups move selector and state together: 0/0, 1/1, 2/1 (prop466: 2/2).
		if [int(p.selector), int(p.state)] not in [[0,0],[1,1],[2,1],[2,2]]: return "Tar selector/state disagree " + id
	for id in src.sequencers:
		var q = value.sequencers.get(id)
		if not q is Dictionary or q.size() != 5 or not q.get("enabled") is bool: return "Invalid tar sequencer " + id
		var last: int = src.sequencers[id].records.filter(func(r): return int(r.kind) == 3).size()
		if not _whole(q.get("selector"), 0, last) or not _whole(q.get("state"), 0, 1) or not _whole(q.get("left"), 0, 65535) or not _whole(q.get("seed"), 0, 2147483647): return "Invalid tar sequencer " + id
		if int(q.selector) > 0 and int(q.state) != 1: return "Tar sequencer selector/state disagree " + id
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := {"version":1,"props":{},"sequencers":{}}
	for id in value.props:
		var p: Dictionary = value.props[id]
		out.props[id] = {"selector":int(p.selector),"state":int(p.state),"durability":int(p.durability),"clock":snappedf(float(p.clock), 1.0 / 1024)}
	for id in value.sequencers:
		var q: Dictionary = value.sequencers[id]
		out.sequencers[id] = {"selector":int(q.selector),"state":int(q.state),"enabled":bool(q.enabled),"left":int(q.left),"seed":int(q.seed)}
	return out

func setup(walkthrough: Node3D) -> String:
	name = "CaveTarFires"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid tar fires source."
	for d in source.art:
		var list: Array[ImageTexture] = []
		for f in source.art[d]:
			if FileAccess.get_sha256(ROOT + str(f)) != str(source.files[f]): return "Tar art changed: " + str(f)
			list.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
		textures[str(d)] = list
	var stream := AudioStreamWAV.load_from_file(ROOT + "462.wav")
	for id in source.props:
		var row: Dictionary = source.props[id]
		var t: Dictionary = source.templates[str(int(row.template))]
		var mesh := MeshInstance3D.new(); mesh.mesh = QuadMesh.new(); mesh.layers = 2; mesh.name = "Tar" + id
		mesh.material_override = host._indexed_material(ROOT + str(source.art["449"][0]))
		mesh.material_override.set_shader_parameter("sprite", true)
		mesh.position = Vector3(row.position[0], row.position[1], row.position[2]) + host.native_translation
		add_child(mesh)
		sprites[id] = mesh
		_size(id, 0)
		if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
		# Hit volume for the Spark ray; the player never collides with it.
		var first: Dictionary = t.selectors[0]
		var body := StaticBody3D.new(); body.collision_layer = 2; body.collision_mask = 0; body.name = "TarHit" + id
		body.set_meta("spark_receiver", SparkTarget.new(self, id))
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
		box.size = Vector3(float(first.right) - float(first.left), float(t.height), float(t.depth)); shape.shape = box
		shape.position = Vector3((float(first.left) + float(first.right)) / 2.0, float(t.height) / 2.0, 0)
		body.add_child(shape); body.position = mesh.position
		add_child(body); host.player.add_collision_exception_with(body)
		bodies[id] = body
		var voice := AudioStreamPlayer3D.new(); voice.stream = stream; voice.unit_size = 64.0; mesh.add_child(voice); voices[id] = voice
	return restore(null)

class SparkTarget extends RefCounted:
	var owner_node; var id: String
	func _init(o, prop: String) -> void: owner_node = o; id = prop
	func receive_spark() -> bool: return owner_node.receive_hit(id, 1, 1, owner_node.SPARK_DAMAGE)

## Only the ignition clock (selector1) is persisted: its end raises kind6 value3. The looping bubbling (selector0) and
## burning (selector2) phases are scenery and save as 0, so the world clock running across a save does not change it.
func checkpoint() -> Dictionary:
	var out := canonical(state)
	for id in out.props:
		if int(out.props[id].selector) != 1: out.props[id].clock = 0.0
	return out

func restore(saved: Variant) -> String:
	var value = initial(source) if saved == null else saved
	var error := validate(value, source)
	if not error.is_empty(): return error
	state = canonical(value)
	carry = 0.0
	for v in voices.values(): v.stop()
	_sync_scenic()
	present()
	return ""

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _scenic() -> Variant:
	var guard = host.get("scenic_guard")
	if guard == null or not is_instance_valid(guard) or guard.get("effects") == null: return null
	return guard.effects

## Guard-pit selector2 is the scenic fire mesh; the scenic explosion (prop574 g5926) also selects it directly.
func _scenic_burning(id: String) -> bool:
	var fx = _scenic()
	return fx != null and int(fx.packet().selectors.get(id, 0)) == 2 and fx.fire_meshes.has(id)

func _sync_scenic() -> void:
	var fx = _scenic()
	if fx == null: return
	for id in state.props:
		if int(source.props[id].pit) == 439 and int(state.props[id].selector) == 2 and fx.fire_meshes.has(id):
			fx.packet().selectors[id] = 2

func _size(id: String, selector: int) -> void:
	var t: Dictionary = source.templates[str(int(source.props[id].template))]
	var s: Dictionary = t.selectors[selector]
	var quad: QuadMesh = sprites[id].mesh
	quad.size = Vector2(float(s.right) - float(s.left), float(s.top) - float(s.bottom))
	quad.center_offset = Vector3((float(s.left) + float(s.right)) / 2.0, (float(s.bottom) + float(s.top)) / 2.0, 0)

func _descriptor(id: String) -> String:
	var t: Dictionary = source.templates[str(int(source.props[id].template))]
	return str(int(t.selectors[int(state.props[id].selector)].descriptor))

func present() -> void:
	for id in sprites:
		var p: Dictionary = state.props[id]
		var mesh: MeshInstance3D = sprites[id]
		mesh.visible = not _scenic_burning(id)
		_size(id, int(p.selector))
		var list: Array = textures[_descriptor(id)]
		var texture: ImageTexture = list[int(float(p.clock) * FPS) % list.size()]
		mesh.material_override.set_shader_parameter("indices", texture)
		if host.has_method("sync_render_source"): host.sync_render_source(mesh, texture)

func _process(delta: float) -> void:
	if not _world_active():
		for v in voices.values(): v.stream_paused = true
		return
	for v in voices.values(): v.stream_paused = false
	advance(delta)

## Animation clocks (kind6 value3 at each cycle end of the shown selector) and native 60/s timer ticks.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	for id in state.props:
		var p: Dictionary = state.props[id]
		var frames: int = textures[_descriptor(id)].size()
		var before := int(float(p.clock) * FPS)
		p.clock = snappedf(float(p.clock) + delta, 1.0 / 1024)
		var cycles := int(float(p.clock) * FPS) / frames - before / frames
		if cycles > 0: _event(id, 3)
	carry += delta * TICKS
	while carry >= 1.0:
		carry -= 1.0
		for id in state.sequencers: _tick(id)
	present()

## Native timer B8C16 (fixed step, flags0): countdown in 1/256 ticks; expiry reloads random(20..30) << 8 with carry.
func _tick(id: String) -> void:
	var q: Dictionary = state.sequencers[id]
	if not q.enabled: return
	if int(q.left) > STEP:
		q.left = int(q.left) - STEP
		return
	var reload: int = _draw(id) << 8
	q.left = int(q.left) + reload - STEP if reload > STEP else 0
	var timer: Dictionary = source.sequencers[id].records.filter(func(r): return int(r.kind) == 2)[0]
	if _seq_predicate(q, timer.predicate): _run_sequencer(id, timer.commands)

func _draw(id: String) -> int:
	var q: Dictionary = state.sequencers[id]
	var interval: Array = source.sequencers[id].interval
	var seed: int = (int(q.seed) * 1103515245 + 12345) & 0x7fffffff
	q.seed = seed
	return int(interval[0]) + (seed >> 16) % (int(interval[1]) - int(interval[0]) + 1)

func _seq_predicate(q: Dictionary, pred: Variant) -> bool:
	if pred == null: return true
	return str(pred.op) == "==" and pred.left.has("owner_state") and int(q.state) == int(pred.right.immediate)

func _run_sequencer(id: String, commands: Array) -> void:
	var q: Dictionary = state.sequencers[id]
	for c in commands:
		var b: PackedByteArray = str(c).hex_decode()
		match int(b[0]):
			5: _select_sequencer(id, int(q.selector) + int(b[4]) if int(b[5]) == 1 else int(b[4]))
			14:
				if int(b[4]) == 3 and not q.enabled: q.enabled = true  # B485C: arg0 keeps the countdown
				elif int(b[4]) == 4: q.enabled = false
			16: q.state = int(b[4])
			19: receive_hit(str(b.decode_u16(2)), b.decode_u16(4), b.decode_u16(6), CHAIN_DAMAGE)

func _select_sequencer(id: String, selector: int) -> void:
	var last: int = source.sequencers[id].records.filter(func(r): return int(r.kind) == 3).size()
	state.sequencers[id].selector = clampi(selector, 0, last)
	for r in source.sequencers[id].records:
		if int(r.kind) == 3 and str(r.raw).substr(8, 2).hex_to_int() == int(state.sequencers[id].selector): _run_sequencer(id, r.commands)

## Native kind9 admission (AE2C8): masks (zero = wildcard), mode4 threshold >= remaining, predicate; first match runs.
func receive_hit(id: String, mask0: int, mask2: int, damage: int) -> bool:
	if not state.props.has(id) or damage <= 0: return false
	var p: Dictionary = state.props[id]
	p.durability = maxi(int(p.durability) - damage, -(1 << 30))
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
	if str(pred.op) == "AND": return _predicate(id, pred.left.expression) and _predicate(id, pred.right.expression)
	var value := 0
	if pred.left.has("owner_state"): value = int(state.props[id].state)
	elif pred.left.has("local"): value = 0  # local12 (prop577's second record) has no writer hosted here
	else: return false
	return str(pred.op) == "==" and value == int(pred.right.immediate)

func _event(id: String, value: int) -> void:
	for record in source.props[id].records:
		if int(record.kind) == 6 and str(record.raw).substr(8, 2).hex_to_int() == value and _predicate(id, record.predicate):
			_run(id, record.commands)

func _run(id: String, commands: Array) -> void:
	for c in commands:
		var b: PackedByteArray = str(c).hex_decode()
		var target := str(b.decode_u16(2))
		match int(b[0]):
			5:
				if state.sequencers.has(target): _select_sequencer(target, int(b[4]))
				elif state.props.has(target):
					var changed: bool = int(state.props[target].selector) != int(b[4])
					state.props[target].selector = int(b[4])
					if changed: state.props[target].clock = 0.0
					if int(b[4]) == 2 and int(source.props[target].pit) == 439: _sync_scenic()
			6:
				if int(b[4]) == 1 and state.props.has(target): state.props[target].clock = 0.0  # 9F584 restart
			9:
				if int(b[4]) == 19 and state.props.has(target): state.props[target].durability = int(b[5])  # B5420
			16:
				if state.props.has(target): state.props[target].state = int(b[4])
			19:
				# op19 (66130) hit on prop223: masks bytes4..7, damage mode byte9 0 -> byte8 (fire, 5).
				if target == "223":
					prop223_hits += 1
					var guard = host.get("scenic_guard")
					if guard != null and is_instance_valid(guard) and guard.has_method("receive_prop223_hit"):
						guard.receive_prop223_hit(b.decode_u16(4), b.decode_u16(6), int(b[8]) if int(b[9]) == 0 else CHAIN_DAMAGE)
			20:
				if voices.has(target): voices[target].play()
	present()
