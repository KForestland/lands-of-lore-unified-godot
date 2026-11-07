extends Node3D
## L1_DC colonnade pillar trap (tools/prepare_cave_pillar_trap.py; playtest 2026-10-17 report10:58:48 "2 pillars that
## you can hit and bring down the stones on the guard pursuing you"). The six intact template30 pillars and the cracked
## template31 prop878 were never drawn (legacy preview template set / animated). Hitting prop878 (melee masks
## 0x0906/0x0004 or Spark 0x0011/0x0001, armed by region1929 local9 and one-shot local24) sends event20 to prop150
## (shared scenic local11 reward) and prop152 (collapse): movable4 rubble is linked across the corridor, prop878 shows
## its broken stump and the falling-pebble timer stops. Guard38's region (kind10 -> local6) decides the crush: in
## regions 1934/0/1952 the guard dies under the rubble and the player earns magic 200 + fighting 200 (op2 sub0x0C/0x0B).
## Leaving south through regions 120/234/283 collapses the corridor the same way. Prop151's 5..15 s timer (started
## by region1787) drops pebbles (template29 props 1221-1225) and shakes prop878.
const SOURCE := "res://scripts/lol2/cave_pillar_trap_source.json"
const ROOT := "res://assets/lol2/generated/cave_pillar_trap/"
const REACH := 96.0
const FPS := 10.0
const SPARK_DAMAGE := 8
const Rewards = preload("res://scripts/lol2/player_property_rewards.gd")
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
const Creature = preload("res://scripts/lol2/scripted_creature_state.gd")
var host: Node3D
var source: Dictionary
var state: Dictionary = {}
var sprites := {}       # "878", statics "1213".., stones "1221"..
var mirrored := {}
var textures := {}      # "pillar0", "pillar1", "static", "stone"
var plays := {}         # op7 one-pass clocks: id -> seconds
var body: StaticBody3D  # prop878 hit volume
var rubble: StaticBody3D
var players := {}       # sound request -> AudioStreamPlayer3D
var clock := 0.0

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "rubble_312_index.png")

static func initial(src: Dictionary) -> Dictionary:
	return {"version":1,"local6":0,"local9":false,"local14":false,"local24":false,"local31":false,
		"pillar":{"selector":0,"state":0,"durability":int(src.pillar.durability)},"collapse_state":0,"rubble":false,
		"timer":{"enabled":bool(src.timer.enabled),"remaining":0.0,"state":0},"rng":151,"inside":[],"guard_inside":[]}

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.get("version") != 1: return "Invalid pillar trap."
	for key in ["local9","local14","local24","local31","rubble"]:
		if not value.get(key) is bool: return "Invalid pillar trap " + key
	for key in ["local6","collapse_state","rng"]:
		var n = value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or float(n) != floorf(float(n)): return "Invalid pillar trap " + key
	if int(value.local6) not in [0,1,2] or int(value.collapse_state) != 0 or int(value.rng) < 0 or int(value.rng) > 0x7fffffff: return "Invalid pillar trap value."
	var p = value.get("pillar")
	if not p is Dictionary or p.size() != 3: return "Invalid pillar trap pillar."
	for key in ["selector","state","durability"]:
		var n = p.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or float(n) != floorf(float(n)): return "Invalid pillar trap pillar."
	if int(p.selector) not in [0,1] or int(p.state) not in [0,1] or int(p.durability) > int(src.pillar.durability) or int(p.durability) < -1000: return "Invalid pillar trap pillar."
	# The stump (selector1) and the rubble come from the same prop152 group.
	if (int(p.selector) == 1) != bool(value.rubble): return "Pillar trap rubble/stump disagree."
	if bool(value.rubble) and not bool(value.local14): return "Pillar trap rubble without local14."
	var t = value.get("timer")
	if not t is Dictionary or t.size() != 3 or not t.get("enabled") is bool: return "Invalid pillar trap timer."
	var remaining = t.get("remaining"); var ts = t.get("state")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) < 0.0 or float(remaining) > float(src.timer.range_seconds[1]): return "Invalid pillar trap timer."
	if not (ts is int or ts is float) or float(ts) != floorf(float(ts)) or int(ts) < 0 or int(ts) >= int(src.timer.random_states): return "Invalid pillar trap timer."
	for key in ["inside","guard_inside"]:
		var list = value.get(key)
		var allowed: Dictionary = src.player_regions if key == "inside" else src.guard.regions
		if not list is Array or list.size() > allowed.size(): return "Invalid pillar trap regions."
		for r in list:
			if not (r is int or r is float) or not allowed.has(str(int(r))): return "Invalid pillar trap regions."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := {"version":1,"local6":int(value.local6),"local9":bool(value.local9),"local14":bool(value.local14),
		"local24":bool(value.local24),"local31":bool(value.local31),"collapse_state":int(value.collapse_state),"rubble":bool(value.rubble),
		"pillar":{"selector":int(value.pillar.selector),"state":int(value.pillar.state),"durability":int(value.pillar.durability)},
		"timer":{"enabled":bool(value.timer.enabled),"remaining":float(value.timer.remaining),"state":int(value.timer.state)},
		"rng":int(value.rng),"inside":[],"guard_inside":[]}
	for r in value.inside: out.inside.append(int(r))
	for r in value.guard_inside: out.guard_inside.append(int(r))
	return out

func setup(walkthrough: Node3D) -> String:
	name = "CavePillarTrap"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid pillar trap source."
	textures.pillar0 = _load(source.art.pillar[0].frames)
	textures.pillar1 = _load(source.art.pillar[1].frames)
	textures.static = _load(source.art.static.frames)
	textures.stone = _load(source.art.stone.frames)
	for id in source.statics: _sprite(id, source.statics[id], textures.static[0])
	_sprite(str(int(source.pillar.id)), source.pillar, textures.pillar0[0])
	for id in source.stones: _sprite(id, source.stones[id], textures.stone[0])
	# prop878 hit volume (melee aim and Spark ray); the player never collides with it.
	var p: Dictionary = source.pillar
	body = StaticBody3D.new(); body.collision_layer = 2; body.collision_mask = 0; body.name = "Prop878Hit"
	body.set_meta("spark_receiver", self)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(float(p.right) - float(p.left), float(p.height), float(p.depth) * 2.0); shape.shape = box
	shape.position.y = float(p.height) * 0.5
	body.add_child(shape); body.position = host.point(p.position) + host.native_translation
	add_child(body); host.player.add_collision_exception_with(body)
	_build_rubble()
	for request in source.sounds:
		var player := AudioStreamPlayer3D.new(); player.stream = AudioStreamWAV.load_from_file(ROOT + str(source.sounds[request].file))
		player.unit_size = 64.0; add_child(player); players[request] = player
	return restore(null)

func _load(frames: Array) -> Array:
	var list: Array = []
	for f in frames: list.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
	return list

func _sprite(id: String, row: Dictionary, texture: ImageTexture) -> void:
	var width: float = float(row.right) - float(row.left)
	var height: float = float(row.top) - float(row.bottom)
	var quad := QuadMesh.new(); quad.size = Vector2(width, height)
	quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, float(row.bottom) + height / 2.0, 0)
	var mesh := MeshInstance3D.new(); mesh.mesh = quad; mesh.layers = 2; mesh.name = "Pillar" + id
	mesh.material_override = host._indexed_material(ROOT + "15_0_index.png")
	mesh.material_override.set_shader_parameter("sprite", true)
	mesh.material_override.set_shader_parameter("indices", texture)
	mesh.position = host.point(row.position) + host.native_translation
	add_child(mesh)
	sprites[id] = mesh
	var before: int = host.occluder_pairs.size() if host.get("occluder_pairs") != null else 0
	if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
	if host.get("occluder_pairs") != null and host.occluder_pairs.size() > before: mirrored[id] = host.occluder_pairs.back()

## Movable4 (template22, material312 rubble, travel 0): its two faces across the corridor; drawn and solid once linked.
func _build_rubble() -> void:
	rubble = StaticBody3D.new(); rubble.name = "Movable4Rubble"; rubble.collision_layer = 1; rubble.collision_mask = 0
	rubble.set_meta("original_record", 4)
	var material: ShaderMaterial = host._indexed_material(ROOT + "rubble_312_index.png")
	material.set_shader_parameter("cutout", true)  # fixed faces; index 0 transparent (material312 alpha cutout)
	var hull := PackedVector3Array()
	for face in source.rubble.faces:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES); surface.set_material(material)
		var uv := [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]
		for n in [0,1,2,0,2,3]:
			var vertex: Vector3 = host.point(face.points[n]) + host.native_translation
			surface.set_uv(uv[n]); surface.add_vertex(vertex)
			if not hull.has(vertex): hull.append(vertex)
		var mesh := MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.layers = 2; rubble.add_child(mesh)
	var shape := ConvexPolygonShape3D.new(); shape.points = hull
	var collision := CollisionShape3D.new(); collision.name = "Hull"; collision.shape = shape; rubble.add_child(collision)
	add_child(rubble)
	if host.has_method("_copy_occluders"): host._copy_occluders(rubble)

func checkpoint() -> Dictionary: return canonical(state)

func restore(saved: Variant) -> String:
	var value = initial(source) if saved == null else saved
	var error := validate(value, source)
	if not error.is_empty(): return error
	state = canonical(value)
	plays.clear()
	for p in players.values(): p.stop()
	present()
	return ""

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _frames(id: String) -> Array:
	if id != str(int(source.pillar.id)): return textures.stone
	return textures.pillar1 if int(state.pillar.selector) == 1 else textures.pillar0

func present() -> void:
	var pid := str(int(source.pillar.id))
	var frames: Array = _frames(pid)
	_show(pid, frames[_frame(pid, frames.size())])
	for id in source.stones: _show(id, textures.stone[_frame(id, textures.stone.size())])
	rubble.visible = bool(state.rubble)
	(rubble.get_node("Hull") as CollisionShape3D).disabled = not bool(state.rubble)
	for child in rubble.get_children():
		if child is MeshInstance3D:
			child.visible = bool(state.rubble)
			if host.has_method("sync_render_source"): host.sync_render_source(child)

func _frame(id: String, count: int) -> int:
	if not plays.has(id): return 0
	return mini(int(float(plays[id]) * FPS), count - 1)

func _show(id: String, texture: ImageTexture) -> void:
	sprites[id].material_override.set_shader_parameter("indices", texture)
	if host.has_method("sync_render_source"): host.sync_render_source(sprites[id], texture)
	if mirrored.has(id) and is_instance_valid(mirrored[id][1]): mirrored[id][1].material_override.set_shader_parameter("indices", texture)

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready"): return
	if not _world_active():
		for p in players.values(): p.stream_paused = true
		return
	for p in players.values(): p.stream_paused = false
	advance(delta)

## One world step: player/guard region edges, prop151 timer, op7 one-pass clocks.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	clock += delta
	_player_regions()
	_guard_regions()
	var t: Dictionary = state.timer
	if bool(t.enabled):
		t.remaining = float(t.remaining) - delta
		if float(t.remaining) <= 0.0:
			_reload()
			# Prop151 kind2: op23 state = random(0..4), op9 self property21 (event20 at that state).
			t.state = _random(int(source.timer.random_states))
			_event20(str(int(source.timer.id)))
	var step: float = 1.0 / FPS
	for id in plays.keys():
		plays[id] = float(plays[id]) + delta
		if float(plays[id]) >= _frames(id).size() * step: plays.erase(id)
	for key in mirrored:
		var pair: Array = mirrored[key]
		if is_instance_valid(pair[1]) and pair[0].is_inside_tree() and pair[1].is_inside_tree(): pair[1].global_transform = pair[0].global_transform
	present()

func _random(n: int) -> int:
	state.rng = (int(state.rng) * 1103515245 + 12345) & 0x7fffffff
	return int(state.rng) % n

func _reload() -> void:
	var r: Array = source.timer.range_seconds
	state.timer.remaining = float(int(r[0]) + _random(int(r[1]) - int(r[0]) + 1))

static func _inside(row: Dictionary, local: Vector3, foot: float, floor_test: bool) -> bool:
	if floor_test and (foot < float(row.floor_min) - 1 or foot > float(row.floor_max) + 3): return false
	var polygon := PackedVector2Array()
	for v in row.polygon: polygon.append(Vector2(v[0], v[1]))
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), polygon)

func _player_regions() -> void:
	if host.player == null or not host.player.is_on_floor(): return
	var local: Vector3 = host.player.global_position - host.native_translation
	var now: Array = []
	for rid in source.player_regions:
		if _inside(source.player_regions[rid], local, local.y - FormBody.FOOT_OFFSET, true): now.append(int(rid))
	for rid in now:
		if not rid in state.inside: player_enters(rid)
	state.inside = now

## Source region records (event2 entry; event4 for 120/234/283 with local24==0).
func player_enters(rid: int) -> void:
	var row: Dictionary = source.player_regions[str(rid)]
	match str(row.role):
		"local9": state.local9 = int(row.value) == 1
		"timer":
			if int(row.value) == 3:
				if not bool(state.timer.enabled): _reload()  # B485C: no-op while running
				state.timer.enabled = true
			else: state.timer.enabled = false
		"collapse":
			if not bool(state.local24):
				state.local24 = true
				_event20(str(int(source.collapse.id)))

func _guard() -> Dictionary:
	var population = host.get("guard_population")
	if population == null or not is_instance_valid(population): return {}
	var id := str(int(source.guard.actor))
	if not population.state.actors.has(id) or not population.bodies.has(id): return {}
	return {"population":population,"id":id,"actor":population.state.actors[id],"body":population.bodies[id]}

## Actor38 kind10 (enters region word, local24==0): local6 = its corridor zone.
func _guard_regions() -> void:
	var g := _guard()
	if g.is_empty() or not bool(g.actor.present) or int(g.actor.health) <= 0: return
	var local: Vector3 = g.body.global_position - g.population.origin()
	var now: Array = []
	for rid in source.guard.regions:
		if _inside(source.guard.regions[rid], local, 0.0, false): now.append(int(rid))
	for rid in now:
		if not rid in state.guard_inside and not bool(state.local24): state.local6 = int(source.guard.regions[str(rid)].local6)
	state.guard_inside = now

## ---- prop878 interaction ---------------------------------------------------------------------------------------

func receive_spark() -> bool: return receive_hit(1, 1, SPARK_DAMAGE)

## Native kind9 admission (AE2C8): masks (zero = wildcard), mode4 threshold >= remaining, predicate; first match runs.
func receive_hit(mask0: int, mask2: int, damage: int) -> bool:
	if damage <= 0: return false
	var p: Dictionary = state.pillar
	p.durability = int(p.durability) - damage
	for record in source.pillar.records:
		if int(record.kind) != 9: continue
		var raw: PackedByteArray = str(record.raw).hex_decode()
		var m0 := raw.decode_u16(4); var m2 := raw.decode_u16(6)
		if m0 != 0 and (m0 & mask0) == 0: continue
		if m2 != 0 and (m2 & mask2) == 0: continue
		if int(raw[8]) < int(p.durability): continue
		if not _predicate(str(int(source.pillar.id)), record.predicate): continue
		_run(str(int(source.pillar.id)), record.commands)
		break
	present()
	return true

func aimed() -> bool:
	if body == null: return false
	var target: Vector3 = body.global_position + Vector3(0, float(source.pillar.height) * 0.5, 0)
	var delta: Vector3 = target - host.camera.global_position
	if delta.length() > REACH + 40.0 or delta.length() < 0.01: return false
	if (-host.camera.global_basis.z).dot(delta.normalized()) < 0.9: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, target, 1, [host.player.get_rid()])
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Armed melee (context 2/4) at the aimed pillar in reach.
func strike() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.player_form == 0 and host.equipped_item == "": return false
	if not aimed(): return false
	return receive_hit(2, 4, Forms.melee_damage(int(host.player_form), host.equipped_item != ""))

## Kind4 value0 (use) at state0.
func use() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not aimed(): return false
	var pid := str(int(source.pillar.id))
	for record in source.pillar.records:
		if int(record.kind) == 4 and _predicate(pid, record.predicate):
			_run(pid, record.commands); present()
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not _world_active() or (host.get("roach") != null and host.roach.model.player_health <= 0): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike():
		preload("res://scripts/lol2/combat_feedback.gd").landed(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use():
		get_viewport().set_input_as_handled()

## ---- interpreter -------------------------------------------------------------------------------------------

func _owner_state(owner: String) -> int:
	if owner == str(int(source.pillar.id)): return int(state.pillar.state)
	if owner == str(int(source.timer.id)): return int(state.timer.state)
	if owner == str(int(source.collapse.id)): return int(state.collapse_state)
	return 0

func _local(n: int) -> int:
	match n:
		6: return int(state.local6)
		9: return 1 if state.local9 else 0
		11: return 1 if _shared_local11() else 0
		14: return 1 if state.local14 else 0
		24: return 1 if state.local24 else 0
		31: return 1 if state.local31 else 0
	return -1

func _predicate(owner: String, pred: Variant) -> bool:
	if pred == null: return true
	if str(pred.op) == "AND": return _predicate(owner, pred.left.expression) and _predicate(owner, pred.right.expression)
	if str(pred.op) != "==": return false
	var left: Dictionary = pred.left
	var value := _owner_state(owner) if left.has("owner_state") else _local(int(left.get("local", -1)))
	return value == int(pred.right.immediate)

## Event20 (op9 property21): the owner's kind6 records with value byte 20 whose predicate holds; first match runs.
func _event20(owner: String) -> void:
	var rows: Array = []
	if owner == str(int(source.pillar.id)): rows = source.pillar.records
	elif owner == str(int(source.reward.id)): rows = source.reward.records
	elif owner == str(int(source.collapse.id)): rows = source.collapse.records
	elif owner == str(int(source.timer.id)):
		var step: Dictionary = source.timer.order[str(int(state.timer.state))]
		_event20(str(int(step.stone)))  # op208 shake [step.shake] not hosted
		return
	elif source.stones.has(owner):
		var stone: Dictionary = source.stones[owner]
		_sound(str(int(stone.sound)), sprites[str(int(source.pillar.id))].global_position)
		_event20(str(int(source.pillar.id)))
		plays[owner] = 0.0
		return
	for record in rows:
		if int(record.kind) == 6 and str(record.raw).substr(8, 2) == "14" and _predicate(owner, record.predicate):
			_run(owner, record.commands)
			return

func _run(owner: String, commands: Array) -> void:
	var pid := str(int(source.pillar.id))
	for c in commands:
		var b: PackedByteArray = str(c).hex_decode()
		var target := str(b.decode_u16(2))
		match int(b[0]):
			0xC6:
				match int(b[4]):
					6: state.local6 = int(b[5])
					9: state.local9 = int(b[5]) == 1
					11: _set_shared_local11()
					14: state.local14 = int(b[5]) == 1
					24: state.local24 = int(b[5]) == 1
					31: state.local31 = int(b[5]) == 1
			5:
				if int(b[1]) == 3 and target == pid: state.pillar.selector = int(b[4])
			16:
				if int(b[1]) == 3 and target == pid: state.pillar.state = int(b[4])
				elif int(b[1]) == 2 and target == str(int(source.guard.actor)) and int(b[4]) == 1: _crush_guard()
			7:
				if int(b[1]) == 3 and int(b[4]) == 2: plays[target] = 0.0
			9:
				if int(b[4]) == 21: _event20(target)
				elif int(b[1]) == 0x20 and target == str(int(source.rubble.movable)) and int(b[4]) == 3: state.rubble = true
			20:
				var at: Vector3 = sprites[pid].global_position
				if int(b[1]) == 0x20: at = _rubble_center()
				_sound(str(b.decode_u16(4)), at)
			14:
				if int(b[1]) == 3 and target == str(int(source.timer.id)):
					if int(b[4]) == 3:
						if not bool(state.timer.enabled): _reload()
						state.timer.enabled = true
					elif int(b[4]) == 4: state.timer.enabled = false
			2:
				_award(int(b[4]), int(b[5]))
			# op8 movable media start (no picture change, travel 0), op13 actor38, op18/op9 prop19, op208: not hosted.

func _rubble_center() -> Vector3:
	var sum := Vector3.ZERO; var n := 0
	for face in source.rubble.faces:
		for p in face.points: sum += host.point(p) + host.native_translation; n += 1
	return sum / maxf(1.0, n)

func _sound(request: String, at: Vector3) -> void:
	var p = players.get(request)
	if p == null: return
	p.global_position = at
	p.play()

## Actor38 op16 state1 -> kind6 value3 chain: sound768 at prop17, op5 selector8 (GGUARD death clip), unlink.
func _crush_guard() -> void:
	_sound(str(int(source.guard.crush_sound)), host.point(source.guard.crush_sound_prop.position) + host.native_translation)
	var g := _guard()
	if g.is_empty() or not bool(g.actor.present) or int(g.actor.health) <= 0: return
	Creature.damage(g.population.state, g.population.src, g.id, int(g.actor.health))
	g.population.sync_quests()
	g.population.present()
	if host.has_method("save_feedback"): host.save_feedback("The guard is crushed under the falling stones.")

func _shared_local11() -> bool:
	var guard = host.get("scenic_guard")
	if guard != null and is_instance_valid(guard) and guard.get("effects") != null: return bool(guard.effects.packet().local11)
	return false

func _set_shared_local11() -> void:
	var guard = host.get("scenic_guard")
	if guard != null and is_instance_valid(guard) and guard.get("effects") != null: guard.effects.packet().local11 = true

## Op2 player properties: 7/8 award arg, 9/0x0A arg*10, 0x0B/0x0C arg*100 (fighting/magic, D84D6), 0x0F/0x10 one
## level (D7CEE/D88CD: thresholds[level] - experience).
func _award(sub: int, arg: int) -> void:
	var magic := sub in [8, 0x0A, 0x0C, 0x10]
	var award := 0
	match sub:
		7, 8: award = arg
		9, 0x0A: award = arg * 10
		0x0B, 0x0C: award = arg * 100
		0x0F, 0x10:
			var thresholds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json"))
			var player: Dictionary
			if magic:
				if host.get("starting_magic") == null: return
				player = host.starting_magic.magic_state().player
			else:
				player = host.quest_state.get("player_reward_state", {}).get("player", JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json")).fighting)
			award = 0 if int(player.level) >= 30 else maxi(0, int(thresholds.thresholds[int(player.level)]) - int(player.experience))
		_: return
	if magic:
		var m = host.get("starting_magic")
		if m == null: return
		var result: Dictionary = Rewards.magic(m.magic_state(), award)
		if result.has("error"): push_error(result.error); return
		m.commit(result.checkpoint)
	else:
		var result: Dictionary = Rewards.fighting(host.quest_state, award)
		if result.has("error"): push_error(result.error); return
		host.quest_state = preload("res://scripts/lol2/atlas_explored.gd").release(result.quests)
