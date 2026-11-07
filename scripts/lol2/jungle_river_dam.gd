extends Node3D
## Huline Jungle river rock / dam (L4_HJ prop250; longplay 35:36-36:42; tools/prepare_jungle_river_dam.py).
## Armed melee on the rock (kind9 value 0x0906 at owner state 0) takes the hit from its durability 50: every hit runs
## g4206 (sound 956); the hit that leaves <= 1 runs g3154: rock -> stump (selector2), foam unlinked, 2 x 500 fighting
## experience, the 75 channel floors sink (66 by 50, 9 by 20; speed3 = 7.5 units/s) and turn to mud when each one
## stops, region4543 drops to -70 and opens the lizard-height burrow, and prop2706's timer starts (1140 ticks at
## 60/s). When it fires (g16764) the curse asks for the lizard form for random(120..180) s (native 649D8 on arg 0x48).
## State: quests.jungle_river_dam {version, durability, broken, elapsed, timer_left, fired}; elapsed drives the
## floors, so a save mid-drain resumes the same heights. timer_left is fractional ticks, so the countdown does not
## depend on how the world clock is subdivided. Burrow items 41/42/68-72 share the Jungle world-item history.
## Modern adapters (docs/DEVIATIONS.md): shake and the prop250 properties 8/16 are not hosted; stones settle with
## their region floor, as does the ground cover standing in the river (longplay); the walls of the drained bed are the published Jungle scene builder's own faces.
const ROOT := "res://assets/lol2/generated/jungle_river_dam/"
const AUDIO := "res://assets/lol2/generated/jungle_river_dam_audio/"
const KEY := "jungle_river_dam"
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const Rewards = preload("res://scripts/lol2/player_property_rewards.gd")
const Catalog = preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
const STRIKE_REACH := 140.0
const ITEM_REACH := 96.0
const ITEM_AIM := 0.97
const MELEE_MASK0 := 2
const MELEE_MASK2 := 4
var host: Node3D
var src: Dictionary
var textures: Dictionary = {}
var materials: Dictionary = {}
var floors: Dictionary = {}
var movers: Dictionary = {}
var walls_before: StaticBody3D
var walls_after: StaticBody3D
var rock: StaticBody3D
var rock_sprite: MeshInstance3D
var foam: Array[MeshInstance3D] = []
var stones: Array = []
var items: Dictionary = {}
var sound: AudioStreamPlayer3D
var clock := 0.0
var presented_elapsed := -1.0

static func assets_ready() -> bool: return FileAccess.file_exists(ROOT + "source.json")
static func source() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source.json"))
static func initial() -> Dictionary:
	return {"version":1,"durability":50,"broken":false,"elapsed":0.0,"timer_left":0,"fired":false}

static func _number(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func _whole(v: Variant, low: int, high: int) -> bool: return _number(v) and float(v) == floorf(float(v)) and v >= low and v <= high
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 6 or value.get("version") != 1: return "Invalid jungle river dam."
	if not value.get("broken") is bool or not value.get("fired") is bool: return "Invalid jungle river dam flags."
	if not _whole(value.get("durability"), -1000, 50): return "Invalid jungle river dam durability."
	if not _number(value.get("timer_left")) or float(value.timer_left) < 0.0 or float(value.timer_left) > 65535.0: return "Invalid jungle river dam timer."
	if not _number(value.get("elapsed")) or float(value.elapsed) < 0.0 or float(value.elapsed) > 3600.0: return "Invalid jungle river dam clock."
	if value.broken != (int(value.durability) <= 1): return "Jungle river dam break does not match its durability."
	if not value.broken and (float(value.elapsed) != 0.0 or float(value.timer_left) != 0.0 or value.fired): return "Unbroken jungle river dam has progress."
	if value.fired != (value.broken and float(value.timer_left) == 0.0): return "Jungle river dam timer and its firing disagree."
	return ""

## Floor/wall regions the Jungle scene leaves to this host (called before the scene builds its static mesh).
static func dynamic_regions() -> Array:
	var s := source()
	return s.floors.keys().map(func(k): return int(k))
static func static_exclusions() -> Array: return source().walls_before

## Read without creating the entry: loading the Jungle must not change the quests.
func state() -> Dictionary:
	var saved: Variant = host.quest_state.get(KEY)
	return saved if saved is Dictionary and validate(saved).is_empty() else initial()
func broken() -> bool: return bool(state().broken)

func setup(owner_host: Node3D) -> String:
	name = "JungleRiverDam"
	host = owner_host
	src = source()
	if not src is Dictionary or int(src.get("version", 0)) != 1: return "Invalid river dam source."
	for m in src.movers:
		var region := str(int(m.region))
		var start: float = float(src.floors[region].initial.points[0][1])
		movers[region] = {"delta": float(m.target) if bool(m.relative) else float(m.target) - start, "speed": float(m.speed) * float(src.speed_units_per_second)}
	for region in src.floors:
		var body := StaticBody3D.new(); body.name = "DamFloor" + region
		body.add_child(MeshInstance3D.new()); body.add_child(CollisionShape3D.new()); add_child(body)
		floors[region] = {"body": body, "offset": INF, "final": false}
	var faces: Array = []
	var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_review/jungle.json"))
	for index in src.walls_before: faces.append(scene.faces[int(index)])
	walls_before = _walls("DamWallsBefore", faces)
	walls_after = _walls("DamWallsAfter", src.walls_after)
	# Native low burrow ceilings constrain stepping and form admission.
	var ceilings: Array = []
	var ceiling_regions: Array = src.burrow.regions.duplicate()
	ceiling_regions.append(src.burrow.mouth)
	for region in ceiling_regions:
		var points: Array = []
		for point in region.polygon:
			points.append([point[0], region.ceiling, point[1]])
		ceilings.append({"points": points})
	_walls("BurrowCeilings", ceilings)
	var r: Dictionary = src.objects.rock
	rock = StaticBody3D.new(); rock.name = "RiverRock"; rock.collision_layer = 1; rock.collision_mask = 0
	var shape := CylinderShape3D.new(); shape.radius = 24.0; shape.height = 126.0
	var collision := CollisionShape3D.new(); collision.shape = shape; collision.position.y = 63.0
	rock.add_child(collision); add_child(rock)
	rock.position = _vector(r.position) + _origin()
	rock.set_meta("jungle_river_rock", self)
	rock_sprite = _billboard(r.selectors[0], r.position)
	for row in src.objects.foam: foam.append(_billboard(row.selectors[0], row.position))
	for row in src.objects.stones: stones.append({"node": _billboard(row.selectors[0], row.position), "row": row})
	_billboard(src.objects.timer.selectors[0], src.objects.timer.position)
	_billboard(src.objects.trigger.selectors[0], src.objects.trigger.position)
	for row in src.items:
		var image := Image.load_from_file(str(row.icon))
		var sprite := Sprite3D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.pixel_size = 0.5
		sprite.offset.y = image.get_height() / 2.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.position = _vector(row.position) + _origin()
		add_child(sprite)
		items[int(row.row)] = sprite
	sound = AudioStreamPlayer3D.new(); sound.max_distance = 2000.0; add_child(sound); sound.position = rock.position + Vector3.UP * 60.0
	present()
	return ""

func _origin() -> Vector3:
	var value = host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func _vector(p: Array) -> Vector3: return Vector3(float(p[0]), float(p[1]), float(p[2]))

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(ROOT + path))
	return textures[path]

func _surface_material(key: String) -> StandardMaterial3D:
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture(str(src.materials[key]))
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = m
	return materials[key]

## Wall faces as one mesh per material plus one collider (faces without a source binding are collision only, as the
## Jungle scene's unbound walls).
func _walls(label: String, faces: Array) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = label; body.collision_layer = 1; body.collision_mask = 0
	var groups := {}
	var points := PackedVector3Array()
	for face in faces:
		var key := str(face.get("material", ""))
		for i in [0, 1, 2, 0, 2, 3]:
			var p := _vector(face.points[i])
			points.append(p)
			if key.is_empty(): continue
			if not groups.has(key):
				groups[key] = SurfaceTool.new(); groups[key].begin(Mesh.PRIMITIVE_TRIANGLES); groups[key].set_material(_surface_material(key))
			groups[key].set_uv(Vector2(face.uv[i][0], face.uv[i][1])); groups[key].add_vertex(p)
	for key in groups:
		var mesh := MeshInstance3D.new(); mesh.mesh = groups[key].commit(); body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
	var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	body.position = _origin()
	add_child(body)
	return body

func _billboard(selector: Dictionary, position_native: Array) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.material_override = material
	add_child(node)
	_select(node, selector)
	node.position = _vector(position_native) + _origin()
	return node

## Quad from the selector's native bounds (as the chief-hut and oil-fire props).
func _select(node: MeshInstance3D, selector: Dictionary) -> void:
	var t := texture(str(selector.frames[0]))
	var mesh := QuadMesh.new(); mesh.size = Vector2(float(selector.right) - float(selector.left), float(selector.top) - float(selector.bottom))
	mesh.center_offset = Vector3((float(selector.left) + float(selector.right)) / 2.0, (float(selector.bottom) + float(selector.top)) / 2.0, 0)
	node.mesh = mesh
	node.set_meta("selector", selector)
	node.material_override.albedo_texture = t

## Current offset of a moving floor after `elapsed` seconds of the drain.
func offset(region: String, elapsed: float) -> float:
	var m: Dictionary = movers[region]
	var distance := minf(absf(float(m.delta)), float(m.speed) * elapsed)
	return signf(float(m.delta)) * distance
func settled(region: String, elapsed: float) -> bool: return is_equal_approx(offset(region, elapsed), float(movers[region].delta))
func drain_seconds() -> float:
	var longest := 0.0
	for region in movers: longest = maxf(longest, absf(float(movers[region].delta)) / float(movers[region].speed))
	return longest

func present() -> void:
	var s := state()
	var elapsed: float = float(s.elapsed) if s.broken else 0.0
	presented_elapsed = elapsed
	for region in floors: _present_floor(region, elapsed if s.broken else 0.0)
	walls_before.visible = not s.broken
	walls_before.process_mode = Node.PROCESS_MODE_DISABLED if s.broken else Node.PROCESS_MODE_INHERIT
	walls_before.collision_layer = 0 if s.broken else 1
	walls_after.visible = s.broken
	walls_after.collision_layer = 1 if s.broken else 0
	_select(rock_sprite, src.objects.rock.selectors[2 if s.broken else 0])
	(rock.get_child(0).shape as CylinderShape3D).height = 64.0 if s.broken else 126.0
	rock.get_child(0).position.y = (rock.get_child(0).shape as CylinderShape3D).height / 2.0
	for node in foam: node.visible = not s.broken
	for stone in stones:
		var region := str(int(stone.row.region))
		var drop := offset(region, elapsed) if s.broken and movers.has(region) else 0.0
		stone.node.position = _vector(stone.row.position) + _origin() + Vector3.UP * drop
	var props = host.get("props")
	if props != null and is_instance_valid(props) and props.has_method("settle"):
		for row in src.cover: props.settle(int(row[0]), offset(str(int(row[1])), elapsed) if s.broken else 0.0)
	var collected: Array = _history().get("collected", [])
	for row in items: items[row].visible = row not in collected.map(func(r): return int(r))

func _present_floor(region: String, elapsed: float) -> void:
	var row: Dictionary = floors[region]
	var current := offset(region, elapsed) if movers.has(region) else 0.0
	var final := broken() and settled(region, elapsed)
	if row.offset == current and row.final == final: return
	var face: Dictionary = src.floors[region].final if final else src.floors[region].initial
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if face.has("material"): surface.set_material(_surface_material(str(face.material)))
	var points := PackedVector3Array()
	var base: Array = src.floors[region].initial.points
	for i in [0, 1, 2, 0, 2, 3]:
		var p := Vector3(float(base[i][0]), float(base[i][1]) + current, float(base[i][2]))
		points.append(p)
		if face.has("uv"): surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
		surface.add_vertex(p)
	row.body.get_child(0).mesh = surface.commit()
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
	row.body.get_child(1).shape = shape
	row.body.position = _origin()
	row.offset = current
	row.final = final

func world_active() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused: return false
	return host.get("starting_magic") != null and is_instance_valid(host.starting_magic) and host.starting_magic.world_active()

## Aimed strike at the rock (the chief-hut rock convention: a 140-unit view ray that meets its collider).
func aimed() -> bool:
	if not world_active() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, host.camera.global_position - host.camera.global_basis.z * STRIKE_REACH, 1, [host.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == rock

func strike() -> bool:
	if not aimed() or (host.player_form == 0 and str(host.equipped_item) == ""): return false
	var damage: int = Forms.melee_damage(int(host.player_form), str(host.equipped_item) != "")
	if host.get("item_effects") != null and is_instance_valid(host.item_effects) and host.item_effects.has_method("melee_damage"): damage = host.item_effects.melee_damage(damage)
	return receive_hit(MELEE_MASK0, MELEE_MASK2, damage)

## Native kind9 admission (masks 0x0906/0x0004, predicate owner state 0, mode4 threshold first, else mode1).
func receive_hit(mask0: int, mask2: int, damage: int) -> bool:
	var s := state()
	if s.broken or damage <= 0: return false
	if not (mask0 & int(src.rock.masks[0])) or not (mask2 & int(src.rock.masks[1])): return false
	var durability := int(s.durability) - damage
	if durability > int(src.rock.break_threshold):
		var next := s.duplicate(true); next.durability = durability
		host.quest_state[KEY] = next
		_play("956")
		return true
	# g3154: two op2 sub0x0B arg5 first (each 500 fighting experience); host.quest_state is replaced by the reward.
	# Both awards run on a local copy; the quests (and the break) are committed only when both succeed.
	var quests: Dictionary = host.quest_state
	for award in src.rewards.awards:
		var result := Rewards.fighting(quests, int(award))
		if result.has("error"): push_error(result.error); return false
		quests = result.quests
	quests[KEY] = {"version":1,"durability":durability,"broken":true,"elapsed":0.0,"timer_left":float(src.timer.countdown),"fired":false}
	host.quest_state = preload("res://scripts/lol2/atlas_explored.gd").release(quests)
	_play("719")
	present()
	if host.has_method("save_feedback"): host.save_feedback("The rock breaks apart and the river drains away.")
	return true

func _play(request: String) -> void:
	var path := AUDIO + request + ".wav"
	if not FileAccess.file_exists(path): return
	sound.stream = AudioStreamWAV.load_from_file(path)
	sound.play()

func _physics_process(delta: float) -> void:
	if world_active(): advance(delta)

## Drain clock and the prop2706 timer (60 ticks/s) on the active Jungle world clock.
func advance(delta: float) -> void:
	clock += delta
	var s := state()
	if not s.broken or not is_finite(delta) or delta <= 0.0: return
	var next := s.duplicate(true)
	if float(next.elapsed) < drain_seconds(): next.elapsed = minf(drain_seconds(), float(next.elapsed) + delta)
	if not next.fired:
		next.timer_left = maxf(0.0, float(next.timer_left) - delta * float(src.timer.ticks_per_second))
		if float(next.timer_left) == 0.0:
			next.fired = true
			_request_lizard()
	host.quest_state[KEY] = next
	if float(next.elapsed) != presented_elapsed: present()

## g16764: op2 sub0x15 arg 0x48 (timed form, random 120..180 s) then op14 sub4 (the timer stops). The curse's own
## admission and nonhuman->nonhuman refusal apply; a refused request is spent like the native one.
func _request_lizard() -> void:
	var curse = host.get("curse")
	if curse == null or not is_instance_valid(curse): return
	var duration: int = curse._draw(int(src.timer.duration_low), int(src.timer.duration_high))
	curse.request_timed_form(int(src.timer.form), float(duration))

func _history() -> Dictionary:
	var world = host.get("world_items")
	if world != null and is_instance_valid(world): return world.history()
	return {"collected": []}

## Burrow items: same E, reach, aim and occlusion as the Jungle world items; rows join their saved history.
func item_target() -> int:
	if not world_active() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1
	var world = host.get("world_items")
	if world == null or not is_instance_valid(world) or world._overlay_blocks(): return -1
	var best := -1; var best_dot := ITEM_AIM
	for row in items:
		var sprite: Sprite3D = items[row]
		if not sprite.visible: continue
		var point: Vector3 = sprite.global_position + Vector3(0, sprite.texture.get_height() * sprite.pixel_size / 2.0, 0)
		var delta: Vector3 = point - host.camera.global_position
		if delta.length() < 0.01 or delta.length() > ITEM_REACH: continue
		var dot: float = (-host.camera.global_basis.z).dot(delta.normalized())
		if dot < best_dot: continue
		var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, 1, [host.player.get_rid()])
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best = row; best_dot = dot
	return best

func collect() -> bool:
	var row := item_target()
	if row < 0: return false
	var id := Catalog.id_of(row)
	if id.is_empty() or id in host.carried_collected: return false
	if host.carried_collected.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
		if host.has_method("save_feedback"): host.save_feedback("Inventory full.")
		return false
	host.carried_collected.append(id)
	host.world_items.history(true).collected.append(row)
	present()
	if host.has_method("save_feedback"): host.save_feedback(str(Catalog.ITEMS[id].label) + " taken.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike(): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and collect(): get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var frame := int(clock * 10.0)
	for node in [rock_sprite] + foam + stones.map(func(s): return s.node):
		if node == null or not node.visible: continue
		var selector: Dictionary = node.get_meta("selector")
		if selector.frames.size() > 1: node.material_override.albedo_texture = texture(str(selector.frames[frame % selector.frames.size()]))
