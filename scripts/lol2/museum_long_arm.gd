extends Node3D
## Live owner for Museum prop153 (Long arm pedestal) and its floor trap. Saved as checkpoint "museum_long_arm".
## Floors: shipped faces of the 20 walkway regions are replaced by the builder's dropped variant (floors.json).
## Group2052's player op2 sub0x3A (form2) is kept owed until applied: modern forced-form adapter (bypasses the
## shared nonhuman->nonhuman refusal, waits for warning/return transitions and for admitted requests).
## Regions: walkway first contact (local25), chamber re-arm 171/176, duct human-return 967/1436/1437/1463 (op2 0x3C).
const State = preload("res://scripts/lol2/museum_long_arm_state.gd")
const SOURCE := "res://scripts/lol2/museum_long_arm_source.json"
const ROOT := "res://assets/lol2/generated/museum_long_arm/"
const FPS := 10.0 # Presentation adapter for the 15-frame pedestal loop.
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var pedestal: Sprite3D
var frames: Array[ImageTexture] = []
var clock := 0.0
var floors := {}
var last_form_request := false
const Curse = preload("res://scripts/lol2/player_curse.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
const Locks = preload("res://scripts/lol2/museum_key_locks_state.gd")
## Modern safety prerequisite (lead decision 2026-10-09). The static region graph shows the pit pocket rejoins the
## main Museum only through the lock78 passage, and only in tiny form. Until that is disproved, a NEW pickup is
## refused while passage78 is closed or curse requests are disabled; state, item and floors stay unchanged.
## An already-triggered save keeps its owed form request. The single-key puzzle is preserved (nothing unlocks).
const NEED_PASSAGE := "Open the passage before taking the axe."
const NEED_CURSE := "The axe will not come free while the curse is stilled."

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "floors.json") and FileAccess.file_exists(ROOT + "icon.png")

static func floor_data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "floors.json"))

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "MuseumLongArm"
	host = owner
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1 or source.take.commands.size() != 28: return "Invalid Long arm source."
	for row in source.pedestal.frames: frames.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(row.file))))
	pedestal = Sprite3D.new()
	pedestal.texture = frames[0]
	pedestal.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pedestal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pedestal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var p: Array = source.pedestal.position
	var width: float = float(source.pedestal.right) - float(source.pedestal.left)
	pedestal.pixel_size = width / float(frames[0].get_width())
	pedestal.centered = true
	pedestal.position = Vector3(float(p[0]), float(p[1]) + (float(source.pedestal.bottom) + float(source.pedestal.top)) / 2.0, float(p[2]))
	add_child(pedestal)
	var data := floor_data()
	floors = {"raised":_build(data.closed_faces), "dropped":_build(data.open_faces)}
	return restore_checkpoint(saved)

func _build(faces: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := PackedVector3Array()
	for face in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0, 1, 2, 0, 2, 3]:
			var q: Array = face.points[i]
			st.set_uv(Vector2(face.uv[i][0], face.uv[i][1]) if face.has("uv") else Vector2.ZERO)
			st.add_vertex(Vector3(q[0], q[1], q[2]))
			collision.append(Vector3(q[0], q[1], q[2]))
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = host.materials.get(face.material)
		body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

func restore_checkpoint(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value, host.carried_collected)
	if not error.is_empty(): return error
	state = State.canonical(value)
	present()
	return ""

func checkpoint() -> Dictionary: return state.duplicate(true)

func aim_point() -> Vector3: return pedestal.global_position

func _ready_for_use() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state != "complete": return false
	if is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	return host.starting_magic == null or host.starting_magic.world_active()

## Source admission (walkway contact, empty hand) plus reach; the safety prerequisite is checked separately.
func offered() -> bool:
	return int(state.stage) == 0 and state.walkway and host.hand_item == "" and _ready_for_use() and host.can_reach_item(aim_point())

func refusal() -> String:
	if not is_instance_valid(host.get("key_locks")) or not Locks.is_loaded(host.key_locks.state, 78): return NEED_PASSAGE
	if host.get("curse") == null or not host.curse.requests_enabled(): return NEED_CURSE
	return ""

func can_take() -> bool: return offered() and refusal().is_empty()

func interaction_hint() -> String:
	if not offered(): return ""
	var reason := refusal()
	return "E — Take Long arm" if reason.is_empty() else reason

func use() -> bool:
	if offered() and not refusal().is_empty():
		# Refused pickup: explain, consume the key press, change nothing.
		if host.has_method("save_feedback"): host.save_feedback(refusal())
		return true
	if not can_take(): return false
	var inventory := {"collected":host.carried_collected,"hand":host.hand_item}
	if not State.take(state, inventory): return false
	host.hand_item = inventory.hand
	present()
	if host.has_method("save_feedback"): host.save_feedback("Long arm taken. The floor gives way!")
	return true

func _physics_process(delta: float) -> void:
	if int(state.stage) == 0:
		clock += delta
		pedestal.texture = frames[int(clock * FPS) % frames.size()]
	if not _ready_for_use(): return
	var on_floor: bool = host.player.is_on_floor()
	if on_floor and not state.walkway and int(state.stage) == 0 and _in_any(source.regions.walkway, false): state.walkway = true
	if on_floor and _in_any(source.regions.rearm, true) and State.rearm(state, int(host.player_form)): pass
	if on_floor and _in_any(source.regions.human_return, true): _human_return()
	State.advance(state, delta)
	if state.pending: apply_owed_form()

## Owed form2 request (adapter). Returns true once applied or already satisfied.
func apply_owed_form() -> bool:
	if not state.pending or host.get("curse") == null: return false
	var curse = host.curse
	var phase := int(curse.state.phase)
	if int(host.player_form) == State.FORM or (phase == 1 and int(curse.state.target) == State.FORM):
		state.pending = false
		return true
	if not curse.requests_enabled() or phase == 1 or phase == 3: return false
	curse.cancel_aura()
	curse.state.merge({"phase":1,"previous":int(host.player_form),"target":State.FORM,"remaining":Curse.WARNING_SECONDS,"duration":State.FORM_SECONDS},true)
	state.pending = false
	last_form_request = true
	return true

## Region kind2 event0 player op2 sub0x3C: repeatable human request when admitted and nonhuman.
func _human_return() -> void:
	var curse = host.get("curse")
	if curse == null or not curse.requests_enabled() or int(host.player_form) == 0 or int(curse.state.phase) == 3: return
	curse.request_human()

func _in_any(rows: Dictionary, check_floor: bool) -> bool:
	var p: Vector3 = host.player.global_position
	var foot := p.y - Body.FOOT_OFFSET
	for row in rows.values():
		if check_floor and (foot < float(row.floor[0]) - 1.0 or foot > float(row.floor[1]) + 3.0): continue
		if not check_floor and foot < 0.0: continue
		var polygon := PackedVector2Array()
		for vertex in row.polygon: polygon.append(Vector2(float(vertex[0]), float(vertex[1])))
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon): return true
	return false

func present() -> void:
	pedestal.visible = int(state.stage) == 0
	var dropped := State.floors_dropped(state)
	for pair in [[floors.raised, not dropped], [floors.dropped, dropped]]:
		var body: StaticBody3D = pair[0]
		body.visible = pair[1]
		for child in body.get_children():
			if child is CollisionShape3D: child.disabled = not pair[1]
