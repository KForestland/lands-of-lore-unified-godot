extends Node3D
## L1_DC prop1333: the boulder in the neck between the plate109 corridor and the big north room (longplay 7:03-7:08).
## Plate109's beast branch (group10114, hosted by cave_guard_controls) sets the prop state to 1; a player bump then runs
## the prop's event5 value1 (predicate207 state==1) group9470: op18 move to native (-1194, 6301), state 2. Human and
## lizard never arm it. The prop is drawn by the static prop preview (props_root, original_record 1333); this host adds
## its solid and moves that same instance and its render copies. Slide time and radius: docs/DEVIATIONS.md.
const SOURCE := "res://scripts/lol2/cave_boulder1333_source.json"
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
## Native prop collision radius is not traced. 24 keeps the west lane of the neck (regions 864-866, which the source
## region graph connects around region871) open to a human; 48 closed it and the 64 sprite half-width also trapped the beast.
const RADIUS := 24.0
## Owner F10 r12l 2026-10-28 15:17:55 ("I can walk past the texture"): the resting rock also gets a corridor-side face, a
## FACE_RADIUS solid centred FACE_OFFSET back from the rock towards the corridor (against the slide axis), so a body
## coming down the corridor stops at the drawn rock (64 wide each side) while the neck behind it keeps its old shape (a
## 48 solid at the centre filled the neck exits). It is part of the player-only neck body (creatures walk as before) and
## goes with it once the rock moves. Modern adapter: docs/DEVIATIONS.md.
const FACE_RADIUS := 48.0
const FACE_OFFSET := 24.0
const HEIGHT := 88.0
const SLIDE_SECONDS := 1.0
## Owner 2026-10-26 and the walkthroughs (fan wiki "Caves of the Draracle", Marcelais v1.4, Burroni): at the split
## passage the rock closes the left-hand way and the right-hand passage ends at region631, where the first curse changes
## Luther; the lizard goes on through the low tunnel there (source regions 635-634-639-629-776-777, 20-40 units of
## headroom: only the 8-high lizard fits) and the beast comes back and walks the rock aside. The neck (regions 864-871)
## reaches the north room only across 866->768 and 870->774 (source region graph); the port's 24-radius rock left gaps
## around it, so while the rock rests a player-only wall closes both exits for every form. Creatures do not collide
## with NECK_LAYER. Modern adapter for the untraced native rock radius: docs/DEVIATIONS.md (2026-10-26).
const NECK_LAYER := 1 << 11
const NECK_WALLS := [[[-1293, -6211], [-1260, -6200]], [[-1260, -6200], [-1184, -6175]]]
const NECK_TOP := 240.0
const NECK_THICKNESS := 8.0
var host: Node3D
var source: Dictionary = {}
var instance: MeshInstance3D
var body: StaticBody3D
var neck: StaticBody3D
var face: CollisionShape3D
var face_offset := Vector3.ZERO
var start := Vector3.ZERO
var finish := Vector3.ZERO
## 0 resting (unmoved), 1 sliding, 2 moved (native prop state 2).
var state := 0
var clock := 0.0

static func load_source() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return parsed if parsed is Dictionary and int(parsed.get("prop", -1)) == 1333 else {}

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2: return "Invalid boulder1333 state."
	var s = value.get("state")
	var c = value.get("clock")
	if not (s is int or s is float) or float(s) != floor(float(s)) or int(s) < 0 or int(s) > 2: return "Invalid boulder1333 state."
	if not (c is int or c is float) or not is_finite(float(c)) or c < 0 or c >= SLIDE_SECONDS: return "Invalid boulder1333 clock."
	if int(s) != 1 and c != 0: return "Idle boulder1333 has a clock."
	return ""

func setup(walkthrough: Node3D) -> String:
	name = "CaveBoulder1333"
	host = walkthrough
	source = load_source()
	if source.is_empty(): return "Missing boulder1333 source."
	var root = host.get("props_root")
	if root == null: return "Boulder1333 needs the prop preview."
	for child in root.get_children():
		if int(child.get_meta("original_record", -1)) == 1333: instance = child
	if instance == null: return "Prop1333 is not drawn."
	start = instance.position
	finish = start + host.point(source.destination_native) - host.point(source.position_native)
	body = StaticBody3D.new()
	body.name = "Solid1333"
	body.collision_layer = preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	body.add_child(shape)
	add_child(body)
	neck = StaticBody3D.new()
	neck.name = "Neck1333"
	neck.collision_layer = NECK_LAYER
	neck.collision_mask = 0
	for wall in NECK_WALLS:
		var a := Vector3(wall[0][0], 0, wall[0][1])
		var b := Vector3(wall[1][0], 0, wall[1][1])
		var box := BoxShape3D.new()
		box.size = Vector3(a.distance_to(b) + NECK_THICKNESS, NECK_TOP, NECK_THICKNESS)
		var piece := CollisionShape3D.new()
		piece.shape = box
		piece.transform = Transform3D(Basis(Vector3.UP, -atan2(b.z - a.z, b.x - a.x)), (a + b) / 2.0 + Vector3.UP * (box.size.y / 2.0))
		neck.add_child(piece)
	face = CollisionShape3D.new()
	var front := CylinderShape3D.new()
	front.radius = FACE_RADIUS
	front.height = HEIGHT
	face.shape = front
	var back: Vector3 = start - finish
	back.y = 0
	face_offset = back.normalized() * FACE_OFFSET
	face.position = instance.global_position - host.native_translation + face_offset + Vector3(0, HEIGHT / 2.0, 0)
	neck.add_child(face)
	add_child(neck)
	if host.get("player") is CollisionObject3D: host.player.collision_mask |= body.collision_layer | NECK_LAYER
	present()
	return ""

func checkpoint() -> Dictionary: return {"state": state, "clock": clock}

func restore(saved: Variant) -> String:
	var value = {"state": 0, "clock": 0.0} if saved == null else saved
	var error := validate(value)
	if not error.is_empty(): return error
	state = int(value.state)
	clock = float(value.clock)
	present()
	return ""

## Native prop state: plate109's beast branch stores 1 in the guard controls packet.
func armed() -> bool:
	var controls = host.get("guard_controls")
	return controls != null and is_instance_valid(controls) and not controls.state.is_empty() and int(controls.state.prop1333) == 1

func touched(feet: Vector3, reach: float) -> bool:
	var p: Vector3 = instance.global_position
	if feet.y >= p.y + HEIGHT or feet.y <= p.y - 8.0: return false
	if Vector2(feet.x - p.x, feet.z - p.z).length() <= RADIUS + reach: return true
	# Contact with the corridor-side face counts as bumping the rock (it only stands while the rock rests).
	if face == null or state != 0: return false
	var f: Vector3 = p + face_offset
	return Vector2(feet.x - f.x, feet.z - f.z).length() <= FACE_RADIUS + reach

func advance(delta: float) -> void:
	if state == 0:
		if armed() and is_instance_valid(host.get("player")):
			var form := int(host.get("player_form")) if host.get("player_form") != null else 0
			if touched(host.player.global_position - Vector3(0, FormBody.FOOT_OFFSET, 0), FormBody.RADII[clampi(form, 0, 2)] + 2.0):
				state = 1
				clock = 0.0
				present()
		return
	if state != 1 or not is_finite(delta) or delta <= 0: return
	clock += delta
	if clock >= SLIDE_SECONDS:
		state = 2
		clock = 0.0
	present()

func present() -> void:
	if not is_instance_valid(instance): return
	var t := 1.0 if state == 2 else clock / SLIDE_SECONDS if state == 1 else 0.0
	instance.position = start.lerp(finish, t)
	body.global_position = instance.global_position + Vector3(0, HEIGHT / 2.0, 0)
	if is_instance_valid(neck) and neck.is_inside_tree():
		neck.global_transform = Transform3D(Basis(), host.native_translation)
		neck.collision_layer = NECK_LAYER if state == 0 else 0
	if host.has_method("sync_render_source"): host.sync_render_source(instance)

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready") or not _world_active(): return
	advance(delta)
