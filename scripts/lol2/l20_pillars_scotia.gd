extends Node3D
## STORY-088 and STORY-089 (HINTBOOK 5492 and 5507). Fire pillars 57-61 are one row.
## No blue cstring is stored. Five fire shots open the chasm deck. Trinity at actor 48
## starts the carrier and the near Scotia falls. Actor 65 is the other Scotia. Actor 47
## is DRAR_PH. No prism opcode 3 is stored. The level is the constant 5.
## Regions 1475-1479 and 1484-1488 are the only level-change owners. Byte 0x53
## splits as level 19 selector 2. This module does not take that exit.
## The deck and the carrier are adapters. No opcode 196 floor crosses either gap,
## and movables 57-98 are type-1 props with no solid faces. L20 is outside the
## region-collision areas, so the movement body is one combined mesh. The chasm
## lips and the south lip are source walls and are not in that mesh. Region 0 is a
## box in the gap: its ceiling at y=64 is solid and meets the capsule. Trinity
## drops that ceiling. The drawn quads stay in the pack mesh.
## Each fire pillar's template-19 center quad carries a shot receiver. Region 1477
## is the east lip (x -2788..-2436, z -4279..-4245, floor 0). A Human with a weapon
## stands there and the camera ray records that pillar. No shot opcode was read, so
## the body and the ray length are an adapter. The west proximity E remains.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l20_pillars"
const FIRE := [57, 58, 59, 60, 61]
const ICE := 62
const BLUE := -1
const SCOTIA := 48
const OTHER_SCOTIA := 65
const DRAR_PH := 47
const PRISM := -1
const TRINITY_LEVEL := 5
const DEST_BYTE := 0x53
const DEST_LEVEL := 19
const DEST_SELECTOR := 2
const STAIR_REGIONS := [1475, 1476, 1477, 1478, 1479, 1484, 1485, 1486, 1487, 1488]
const AT_57 := Vector3(-3340, -50, -4299)
const AT_58 := Vector3(-3404, -50, -4299)
const AT_59 := Vector3(-3482, -50, -4299)
const AT_60 := Vector3(-3559, -50, -4299)
const AT_61 := Vector3(-3636, -50, -4299)
const AT_62 := Vector3(-3400, -50, -4463)
const SCOTIA_AT := Vector3(-3539, -50, -3877)
const OTHER_AT := Vector3(-2207, -50, -1180)
const DRAR_AT := Vector3(-3576, -50, -3986)
const STAIR_AT := Vector3(-2612, 0, -4262)
const REACH := 20.0
## Region 1477. The body origin is the floor plus 32, inside the quad by more than the capsule radius.
const LIP := Vector3(-2760.0, 32.0, -4271.0)
const LIP_X0 := -2788.0
const LIP_X1 := -2436.0
const LIP_Z0 := -4279.0
const LIP_Z1 := -4245.0
## Template 19 selector 1 at each fire placement: left -15, right 15, bottom 0, top 255.
## The five placements share one native Y, so that 30-wide sprite lines up along the shot.
## The marker stays 4 across the row. A 30-wide body would hide every pillar behind the first.
const QUAD_BOTTOM := 0.0
const QUAD_TOP := 255.0
const QUAD_WIDTH := 4.0
## The quad is a billboard. The thickness lets the camera ray meet that plane.
const QUAD_THICK := 8.0
## Camera on the lip to pillar 61 is about 869. No projectile length is stored.
const SHOT_REACH := 960.0
## Layer 4, mask 7: the same layers as the L19 switch ray. Layer 1 stays the walk mesh.
const SHOT_LAYER := 4
const SHOT_MASK := 7
const DECK_FROM := Vector3(-2600, 0, -4262)
const DECK_TO := Vector3(-3360, -50, -4262)
const DECK_Z0 := -4272.0
const DECK_Z1 := -4247.0
const GAP_FROM := Vector3(-1410, 0, -3950)
const GAP_TO := Vector3(-1410, 0, -3598)
const CARRIER_X := -1410.0
const CARRIER_SOUTH_Z := -3896.0
const CARRIER_NORTH_Z := -3620.0
const CARRIER_SPEED := 40.0
const CARRIER_PAUSE := 3.0
const CARRIER_HALF_D := 20.0
var host: Node3D
var hint: Label
var stage: Label
var path_leaf: MeshInstance3D
var scotia_body: MeshInstance3D
var deck_bodies: Array[StaticBody3D] = []
var deck_meshes: Array[MeshInstance3D] = []
var carrier: StaticBody3D
var caps_open := false
var gap_open := false
var leg := 0
var leg_time := 0.0

class PillarShot:
	extends RefCounted
	var owner: Node
	var slot: int
	func _init(n: Node, id: int) -> void:
		owner = n
		slot = id
	func receive_shot() -> bool:
		return owner.record_shot(slot)

static func initial() -> Dictionary:
	return {"version": 1, "shot": [], "trinity": false, "path_open": false, "pillars_moved": false}

func opens_path() -> bool:
	return bool(state().path_open)

func moves_pillars() -> bool:
	return bool(state().pillars_moved)

func deck_ready() -> bool:
	return opens_path() and not deck_bodies.is_empty() and deck_bodies[0].collision_layer == 1

func carrier_z() -> float:
	if carrier == null:
		return 0.0
	return carrier.global_position.z

func carrier_docked_south() -> bool:
	return moves_pillars() and leg == 0 and absf(carrier_z() - CARRIER_SOUTH_Z) < 2.0

static func relocates_player() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 5: return "Invalid pillar state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid pillar state."
	if not (s.get("trinity") is bool) or not (s.get("path_open") is bool) or not (s.get("pillars_moved") is bool): return "Invalid pillar state."
	var listed: Variant = s.get("shot")
	if not listed is Array: return "Invalid pillar state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not (int(id) in FIRE): return "Invalid pillar state."
		seen[int(id)] = true
	var path_ready: bool = seen.size() == FIRE.size()
	var moved: bool = bool(s.get("trinity"))
	if bool(s.get("path_open")) != path_ready or bool(s.get("pillars_moved")) != moved: return "Invalid pillar state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_pillars_scotia.gd").new()
	n.host = map
	n.name = "L20PillarsScotia"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var shot: Array = []
	var listed: Variant = raw.get("shot", [])
	if listed is Array:
		for id in listed:
			shot.append(int(id))
	var trinity: bool = bool(raw.get("trinity", false))
	var path_ready: bool = shot.size() == FIRE.size()
	return {"version": int(raw.get("version", 1)), "shot": shot, "trinity": trinity, "path_open": path_ready, "pillars_moved": trinity}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_fire() -> int:
	if flat_to(AT_57) < REACH: return 57
	if flat_to(AT_58) < REACH: return 58
	if flat_to(AT_59) < REACH: return 59
	if flat_to(AT_60) < REACH: return 60
	if flat_to(AT_61) < REACH: return 61
	return -1

func pillar_at(id: int) -> Vector3:
	if id == 57: return AT_57
	if id == 58: return AT_58
	if id == 59: return AT_59
	if id == 60: return AT_60
	if id == 61: return AT_61
	return Vector3.ZERO

func aim_point(id: int) -> Vector3:
	var at := pillar_at(id)
	return Vector3(at.x, at.y + (QUAD_BOTTOM + QUAD_TOP) * 0.5, at.z)

func on_east_lip() -> bool:
	var p: Vector3 = host.player.global_position
	return p.x >= LIP_X0 and p.x <= LIP_X1 and p.z >= LIP_Z0 and p.z <= LIP_Z1

func record_shot(id: int) -> bool:
	if host.flying or not host.starting_magic.world_active():
		return false
	if int(host.player_form) != 0 or str(host.equipped_item) == "":
		return false
	if not id in FIRE:
		return false
	var s: Dictionary = state()
	var shot: Array = s.shot
	if not id in shot:
		shot.append(id)
		s.shot = shot
		s.path_open = shot.size() == FIRE.size()
		s.pillars_moved = bool(s.trinity)
		host.quest_state[KEY] = s
	return true

func shot_from_camera() -> bool:
	if host.flying or not host.starting_magic.world_active() or host.camera == null:
		return false
	var origin: Vector3 = host.camera.global_position
	var end: Vector3 = origin - host.camera.global_basis.z * SHOT_REACH
	var exclude: Array[RID] = [host.player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, SHOT_MASK, exclude))
	if hit.is_empty() or not hit.collider.has_meta("pillar_shot_receiver"):
		return false
	return bool(hit.collider.get_meta("pillar_shot_receiver").receive_shot())

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 532)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 500)
	canvas.add_child(stage)
	_build_deck()
	_build_carrier()
	_arm_pillars()
	scotia_body = _box("ScotiaBody", SCOTIA_AT, Color(0.7, 0.25, 0.2))

func _arm_pillars() -> void:
	for id in FIRE:
		var body := StaticBody3D.new()
		body.name = "PillarShot%d" % int(id)
		body.collision_layer = SHOT_LAYER
		body.collision_mask = 0
		body.position = aim_point(int(id))
		body.set_meta("pillar_shot_receiver", PillarShot.new(self, int(id)))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(QUAD_THICK, QUAD_TOP - QUAD_BOTTOM, QUAD_WIDTH)
		shape.shape = box
		body.add_child(shape)
		add_child(body)

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(14, 30, 14)
	mesh_node.mesh = box
	mesh_node.position = at
	mesh_node.material_override = _mat(color)
	add_child(mesh_node)
	return mesh_node

func _build_deck() -> void:
	var color := Color(0.25, 0.45, 0.85)
	path_leaf = _flat_deck("PillarPath", -2776.0, -2860.0, 0.0, color)
	var cursor := -2860.0
	var end := -3325.0
	var span := -2860.0 - end
	var index := 0
	while cursor - 1.0 > end:
		var nxt: float = maxf(end, cursor - 46.0)
		var top: float = lerpf(0.0, -50.0, (-2860.0 - cursor) / span)
		_flat_deck("DeckStep%d" % index, cursor, nxt, top, color)
		cursor = nxt
		index += 1

func _flat_deck(node_name: String, x0: float, x1: float, top: float, color: Color) -> MeshInstance3D:
	var wide := absf(x1 - x0)
	var deep := DECK_Z1 - DECK_Z0
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(wide, 8.0, deep)
	mesh_node.mesh = box
	mesh_node.position = Vector3((x0 + x1) * 0.5, top - 4.0, (DECK_Z0 + DECK_Z1) * 0.5)
	mesh_node.material_override = _mat(color)
	add_child(mesh_node)
	deck_meshes.append(mesh_node)
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = mesh_node.position
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = box.size
	shape.shape = slab
	body.add_child(shape)
	add_child(body)
	deck_bodies.append(body)
	return mesh_node

func _build_carrier() -> void:
	# Static so the physics step does not ride Luther a second time. The footprint move is the only carry.
	carrier = StaticBody3D.new()
	carrier.name = "GapCarrier"
	carrier.collision_layer = 0
	carrier.collision_mask = 0
	carrier.position = Vector3(CARRIER_X, -4.0, CARRIER_SOUTH_Z)
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(28, 8, CARRIER_HALF_D * 2.0)
	shape.shape = slab
	carrier.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = slab.size
	mesh_node.mesh = box
	mesh_node.material_override = _mat(Color(0.55, 0.58, 0.62))
	carrier.add_child(mesh_node)
	carrier.visible = false
	add_child(carrier)

func _show() -> void:
	var open: bool = opens_path()
	var moved: bool = moves_pillars()
	for body in deck_bodies:
		body.collision_layer = 1 if open else 0
	for mesh in deck_meshes:
		mesh.visible = open
	scotia_body.visible = not bool(state().trinity)
	if open and not caps_open:
		caps_open = _open_caps()
	if moved and not gap_open:
		gap_open = _open_gap()
	if carrier != null:
		carrier.visible = moved
		_sync_carrier_layer()
	stage.text = "The pillars open the path." if open and not moved else ("The platform carries you across the gap." if moved else "")

func _open_caps() -> bool:
	# The lip walls are source walls. They are already absent from the movement body.
	return true

func _open_gap() -> bool:
	var shape_node := _combined_collider()
	if shape_node == null:
		return false
	return _drop_region0_ceiling(shape_node)

func _combined_collider() -> CollisionShape3D:
	var best: CollisionShape3D = null
	var best_n := 0
	for child in host.get_children():
		if not (child is StaticBody3D):
			continue
		for sub in child.get_children():
			if sub is CollisionShape3D and sub.shape is ConcavePolygonShape3D:
				var count := (sub.shape as ConcavePolygonShape3D).get_faces().size()
				if count > best_n:
					best_n = count
					best = sub
	return best

func _drop_region0_ceiling(shape_node: CollisionShape3D) -> bool:
	var shape := shape_node.shape as ConcavePolygonShape3D
	var source: PackedVector3Array = shape.get_faces()
	var kept := PackedVector3Array()
	var index := 0
	while index + 2 < source.size():
		var a := source[index]
		var b := source[index + 1]
		var c := source[index + 2]
		var ceiling := absf(a.y - 64.0) < 1.0 and absf(b.y - 64.0) < 1.0 and absf(c.y - 64.0) < 1.0
		if ceiling:
			ceiling = _in_region0(a) and _in_region0(b) and _in_region0(c)
		if not ceiling:
			kept.append(a)
			kept.append(b)
			kept.append(c)
		index += 3
	shape_node.disabled = true
	shape.set_faces(kept)
	shape_node.disabled = false
	return true

func _in_region0(point: Vector3) -> bool:
	return point.x >= -1470.5 and point.x <= -1395.5 and point.z >= -3754.5 and point.z <= -3689.5

func _on_carrier() -> bool:
	var player := host.player as CharacterBody3D
	if player == null or not player.is_on_floor():
		return false
	# Once the body is on the north shore, the carrier must leave without dragging it.
	if player.global_position.z > -3606.0 and player.global_position.z < -3500.0:
		return false
	var feet_y := player.global_position.y - 32.0
	if absf(feet_y) > 8.0:
		return false
	if absf(player.global_position.x - CARRIER_X) > 12.0:
		return false
	if absf(player.global_position.z - carrier.global_position.z) > CARRIER_HALF_D - 2.0:
		return false
	return true

func _separated_from_carrier() -> bool:
	var player := host.player as CharacterBody3D
	if player == null or carrier == null:
		return true
	if absf(player.global_position.x - CARRIER_X) > 24.0:
		return true
	# The slab is 20 deep and the capsule radius is 8. Stay unsolid until the body is clear.
	return absf(player.global_position.z - carrier.global_position.z) > CARRIER_HALF_D + 10.0

func _sync_carrier_layer() -> void:
	if carrier == null:
		return
	var solid := moves_pillars() and (_on_carrier() or _separated_from_carrier())
	carrier.collision_layer = 1 if solid else 0

func _place_carrier(z: float) -> void:
	var before := carrier.global_position
	var riding := _on_carrier()
	if not riding:
		_sync_carrier_layer()
	carrier.global_position = Vector3(CARRIER_X, -4.0, z)
	if riding:
		var player := host.player as CharacterBody3D
		player.global_position += carrier.global_position - before
	_sync_carrier_layer()

func advance(delta: float) -> void:
	if carrier == null or not moves_pillars():
		return
	if not gap_open:
		gap_open = _open_gap()
		if not gap_open:
			return
	if leg == 0 or leg == 2:
		leg_time += delta
		if leg_time >= CARRIER_PAUSE:
			leg_time = 0.0
			leg = (leg + 1) % 4
		return
	var dest := CARRIER_NORTH_Z if leg == 1 else CARRIER_SOUTH_Z
	var next := move_toward(carrier.global_position.z, dest, CARRIER_SPEED * delta)
	_place_carrier(next)
	if absf(next - dest) < 0.5:
		_place_carrier(dest)
		leg_time = 0.0
		leg = (leg + 1) % 4

func _physics_process(delta: float) -> void:
	# The earned harness turns the map's physics off and steps the carrier itself.
	if host != null and host.is_physics_processing():
		advance(delta)

func _process(_delta: float) -> void:
	hint.text = ""
	_show()
	if host.flying or not host.starting_magic.world_active(): return
	if on_east_lip() and int(host.player_form) == 0 and str(host.equipped_item) != "":
		hint.text = "Left click — Shoot the pillar"
	elif near_fire() >= 0:
		hint.text = "E — Shoot the pillar"
	elif flat_to(SCOTIA_AT) < REACH:
		hint.text = "Prism — Shift+Q: Trinity at the faux Scotia"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(OTHER_AT) < REACH or flat_to(DRAR_AT) < REACH: return
	if int(host.player_form) != 0 or str(host.equipped_item) == "": return
	var id: int = near_fire()
	if id < 0: return
	if record_shot(id):
		get_viewport().set_input_as_handled()

## Headless has no window, so a captured mouse cannot stick. A real window still requires it.
func _shot_click_open() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _shot_click_open():
		if shot_from_camera():
			get_viewport().set_input_as_handled()

func accepts_player_spell(id: String) -> bool:
	return id == "prism5" and flat_to(SCOTIA_AT) < REACH and not state().trinity

func receive_player_spell(id: String) -> bool:
	if not accepts_player_spell(id) or host.flying or not host.starting_magic.world_active(): return false
	if not Forms.can_cast(int(host.player_form)): return false
	var cast: Dictionary = state()
	cast.trinity = true
	cast.path_open = cast.shot.size() == FIRE.size()
	cast.pillars_moved = true
	host.quest_state[KEY] = cast
	_show()
	return true
