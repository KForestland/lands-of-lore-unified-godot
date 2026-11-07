extends Node3D
## Live owner for the 17 Museum Sk-key locks, the sconces they light and the movable55 SS1 panel.
## Source records: scripts/lol2/museum_key_locks_source.json. Saved as checkpoint "museum_key_locks".
## Modern adapters: E with the shared museum reach/aim/occlusion test, key/flame/panel markers, and
## immediate animation endpoints (no native kind8 timing). Insert needs the key in the hand cursor (E also takes it
## from the pack: use_from_pack); take grants it into the hand cursor. Targets without host objects are listed in source.not_hosted.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const SOURCE := "res://scripts/lol2/museum_key_locks_source.json"
const ROOT := "res://assets/lol2/generated/museum_key_locks/"
const FLAMES := "res://assets/lol2/generated/museum_sconce_flames/"
const AIM_LIFT := 5.0
const BURN := 5 # Sconce empty-hand op19 byte8.
const PANEL_HEIGHT := 40.0 # Adapter: movable55 lowered pose is not replayed; x/z are the source placement.
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var key_markers := {}
var flames: Array[MeshInstance3D] = []
var flame_material: StandardMaterial3D
var flame_frames: Array[Texture2D] = []
var flame_fps := 8.0
var flame_clock := 0.0
var panel: Node3D
var panel_item: Sprite3D

var passage := {}
## Lock sounds and narration (tools/prepare_museum_key_locks_audio.py): op20 skelkey1/skelkey2 on insert/take; the
## insert's op24 narration chain, each kind8 record (value == request) starting the next clip when one ends. Narration
## is not saved: a load starts silent. Not hosted: the speaking-stone picture (effect props 109-125).
const AUDIO := "res://assets/lol2/generated/museum_key_locks_audio/"
var audio: Dictionary = {}
var sound: AudioStreamPlayer3D
var narration: AudioStreamPlayer3D
## {lock, index} of the narration clip playing; empty when silent.
var narrating: Dictionary = {}
var played: Array = []

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "sk_key.png") and FileAccess.file_exists(ROOT + "ss1.png") and FileAccess.file_exists(ROOT + "passage78.json")

static func passage_data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "passage78.json"))

## Lock78 toggles prop81 (event20): closed = loaded floors 30/80 (shipped faces), open = opcode196 floors 0.
func _build_passage(faces: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := PackedVector3Array()
	for face in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.points[i]
			st.set_uv(Vector2(face.uv[i][0], face.uv[i][1]) if face.has("uv") else Vector2.ZERO)
			st.add_vertex(Vector3(p[0], p[1], p[2]))
			collision.append(Vector3(p[0], p[1], p[2]))
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

func set_passage_open(open: bool) -> void:
	for pair in [[passage.closed, not open], [passage.open, open]]:
		var body: StaticBody3D = pair[0]
		body.visible = pair[1]
		body.process_mode = Node.PROCESS_MODE_INHERIT if pair[1] else Node.PROCESS_MODE_DISABLED
		for child in body.get_children():
			if child is CollisionShape3D: child.disabled = not pair[1]

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "MuseumKeyLocks"
	host = owner
	_setup_audio()
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1 or source.locks.size() != 17: return "Invalid key-lock source."
	for id in State.LOCKS:
		if not source.locks.has(str(id)): return "Key-lock source misses control %d." % id
	if source.initial_loaded != [87.0] and source.initial_loaded != [87]: return "Unexpected initial key lock."
	var key_texture := ImageTexture.create_from_image(Image.load_from_file(ROOT + "sk_key.png"))
	for id in State.LOCKS:
		var marker := Sprite3D.new()
		marker.texture = key_texture
		marker.pixel_size = 0.4
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		marker.position = aim_point(id)
		add_child(marker)
		key_markers[id] = marker
	# Template36 lock holders are not in the prop pack. A small plate keeps an empty niche aimable
	# after the key sprite hides. No collision, so the reach ray is unchanged.
	var plate_material := StandardMaterial3D.new()
	plate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_material.albedo_color = Color(0.62, 0.48, 0.22)
	plate_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for id in State.LOCKS:
		var plate := MeshInstance3D.new()
		plate.name = "LockPlate_%d" % int(id)
		var plate_quad := QuadMesh.new()
		plate_quad.size = Vector2(12, 16)
		plate_quad.center_offset = Vector3(0, 8, 0)
		plate.mesh = plate_quad
		plate.material_override = plate_material
		var place: Array = source.locks[str(id)].position
		plate.position = Vector3(float(place[0]), float(place[1]), float(place[2]))
		add_child(plate)
	if FileAccess.file_exists(FLAMES + "sconce_flames.json"): _build_source_flames()
	else: _build_marker_flames()
	panel = Node3D.new()
	var place: Array = source.panel.position
	panel.position = Vector3(float(place[0]), PANEL_HEIGHT, float(place[2]))
	add_child(panel)
	panel_item = Sprite3D.new()
	panel_item.texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "ss1.png"))
	panel_item.pixel_size = 0.4
	panel_item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel_item.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panel.add_child(panel_item)
	var data := passage_data()
	passage = {"closed":_build_passage(data.closed_faces), "open":_build_passage(data.open_faces)}
	return restore_checkpoint(saved)

## Lit state 1 selects template37 child mask 2: one wall-length resource-39 fire face pair per sconce.
## Frame rate is an adapter (see sconce_flames.json timing); frames advance only while lit.
func _build_source_flames() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLAMES + "sconce_flames.json"))
	flame_material = StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	flame_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flame_material.cull_mode = BaseMaterial3D.CULL_BACK
	for name in data.frames: flame_frames.append(ImageTexture.create_from_image(Image.load_from_file(FLAMES + str(name))))
	flame_fps = float(data.fps)
	flame_material.albedo_texture = flame_frames[0]
	var surfaces := {}
	for face in data.faces:
		var id := int(face.source_index)
		if not surfaces.has(id):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[id] = surface
		var surface: SurfaceTool = surfaces[id]
		for i in [0,1,2,0,2,3]:
			surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			surface.add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
	for id in source.sconces:
		var flame := MeshInstance3D.new()
		flame.name = "SconceFire_%s" % id
		var surface: SurfaceTool = surfaces[int(id)]
		surface.generate_normals()
		flame.mesh = surface.commit()
		flame.material_override = flame_material
		add_child(flame)
		flames.append(flame)

func _setup_audio() -> void:
	if not FileAccess.file_exists(AUDIO + "audio.json"): return
	audio = JSON.parse_string(FileAccess.get_file_as_string(AUDIO + "audio.json"))
	for player in ["sound", "narration"]:
		var node := AudioStreamPlayer3D.new()
		node.name = "Lock" + player.capitalize()
		node.unit_size = 160
		node.max_distance = 1200
		add_child(node)
		set(player, node)
	narration.finished.connect(_narration_finished)

func _clip(request: int) -> AudioStream:
	return AudioStreamWAV.load_from_file(str(audio.clips[str(request)].path))

func _play(player: AudioStreamPlayer3D, lock: int, request: int) -> void:
	player.position = aim_point(lock)
	player.stream = _clip(request)
	player.play()
	played.append(request)

## Insert: skelkey1, then the first narration clip once it has ended. Take: skelkey2 and the narration stops.
func lock_sound(lock: int, inserted: bool) -> void:
	if audio.is_empty() or not audio.locks.has(str(lock)): return
	var row: Dictionary = audio.locks[str(lock)]
	if not inserted and int(narrating.get("lock", -1)) == lock:
		narration.stop(); narrating = {}
	_play(sound, lock, int(row.insert if inserted else row.take))
	if inserted and not row.chain.is_empty():
		narration.stop()
		narrating = {"lock": lock, "index": -1, "wait": float(audio.clips[str(int(row.insert))].duration)}

func _narration_finished() -> void:
	if narrating.is_empty(): return
	var chain: Array = audio.locks[str(narrating.lock)].chain
	narrating.index = int(narrating.index) + 1
	if int(narrating.index) >= chain.size(): narrating = {}; return
	_play(narration, int(narrating.lock), int(chain[narrating.index]))

func _process(delta: float) -> void:
	if not narrating.is_empty() and int(narrating.index) < 0:
		narrating.wait = float(narrating.wait) - delta
		if float(narrating.wait) <= 0: _narration_finished()
	if flame_frames.is_empty() or not State.sconces_lit(state): return
	flame_clock += delta
	flame_material.albedo_texture = flame_frames[int(flame_clock * flame_fps) % flame_frames.size()]

## Legacy marker flames when the sconce fire pack is absent.
func _build_marker_flames() -> void:
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(1.0, 0.62, 0.18)
	marker_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for sconce in source.sconces.values():
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# The 4x7 mark did not read across the round hall. Lit size is a presentation adapter.
		quad.size = Vector2(16, 28)
		flame.mesh = quad
		flame.material_override = marker_material
		var p: Array = sconce.position
		flame.position = Vector3(float(p[0]), float(p[1]) + 9.0, float(p[2]))
		add_child(flame)
		flames.append(flame)

func restore_checkpoint(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value, host.carried_collected)
	if not error.is_empty(): return error
	state = State.canonical(value)
	if is_instance_valid(narration): narration.stop(); sound.stop()
	narrating = {}
	present()
	return ""

func checkpoint() -> Dictionary: return state.duplicate(true)

func aim_point(id: int) -> Vector3:
	var p: Array = source.locks[str(id)].position
	return Vector3(float(p[0]), float(p[1]) + AIM_LIFT, float(p[2]))

func _ready_for_use() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state != "complete": return false
	if is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	return host.starting_magic == null or host.starting_magic.world_active()

## The nearest lock or panel the player can reach and aim at, with the source group that would run.
func target() -> Dictionary:
	if not _ready_for_use(): return {}
	var best := {}
	var best_distance := INF
	for id in State.LOCKS:
		var point := aim_point(id)
		var kind := State.group(state, id, host.hand_item)
		if kind == "" or not host.can_reach_item(point): continue
		var distance: float = point.distance_to(host.camera.global_position)
		if distance < best_distance: best = {"lock":id,"group":kind}; best_distance = distance
	# Lit sconces (control113 selector1): the empty-hand record runs op19 on the player (control134 has none).
	# Lock/panel actions take precedence over touching a flame in the same view.
	if best.is_empty() and State.sconces_lit(state) and host.hand_item == "" and panel_kind_for_view() == "":
		for id in source.sconces:
			if source.sconces[id].empty_hand == null: continue
			var flame_point := sconce_point(id)
			if not host.can_reach_item(flame_point): continue
			var d: float = flame_point.distance_to(host.camera.global_position)
			if d < best_distance: best = {"sconce":int(id),"group":"burn"}; best_distance = d
	# Lit sconces with a burnt fire crystal in hand: every sconce's kind4 mode3 record (owner state1, held
	# "57b-Fire brnt") takes the crystal and grants "57a-Fire crstl" property1 (original Museum supply: prop297 reveals placed burnt crystals6/5/4; pickup hosting pending).
	if best.is_empty() and State.sconces_lit(state) and _hand_crystal_burnt() and panel_kind_for_view() == "":
		for id in source.sconces:
			if source.sconces[id].get("recharge") == null: continue
			var flame_point := sconce_point(id)
			if not host.can_reach_item(flame_point): continue
			var d: float = flame_point.distance_to(host.camera.global_position)
			if d < best_distance: best = {"sconce":int(id),"group":"recharge"}; best_distance = d
	var panel_kind := State.panel_group(state, host.hand_item)
	if panel_kind != "" and host.can_reach_item(panel.global_position):
		var distance: float = panel.global_position.distance_to(host.camera.global_position)
		if distance < best_distance: best = {"panel":55,"group":panel_kind}
	return best

func _hand_crystal_burnt() -> bool:
	var effects = host.get("item_effects")
	return host.hand_item != "" and effects != null and is_instance_valid(effects) and effects.crystal_burnt(host.hand_item)

func panel_kind_for_view() -> String:
	var kind := State.panel_group(state, host.hand_item)
	return kind if kind != "" and host.can_reach_item(panel.global_position) else ""

func sconce_point(id: Variant) -> Vector3:
	var p: Array = source.sconces[str(id)].position
	return Vector3(float(p[0]), float(p[1]) + 9.0, float(p[2]))

## op19 (B6B5F -> 66130) sends a hit with word0x10 to the player. Source mode byte 0xEC leaves the native amount
## ambiguous; the modern adapter applies byte8 (5) like mode0, through the shared Museum player health.
func burn() -> bool:
	if host.starting_magic == null: return false
	var health: int = host.starting_magic.health()
	host.starting_magic.set_health(maxi(0, health - BURN))
	if host.has_method("save_feedback"): host.save_feedback("You fell. R: recover here · F9: load save" if host.starting_magic.health() == 0 else "The sconce flame burns you.")
	return true

func interaction_hint() -> String:
	var t := target()
	match t.get("group", ""):
		"insert": return "E — Place Sk key in the lock"
		"take": return "E — Take Sk key"
		"give": return "E — Take SS1"
		"put_back": return "E — Return SS1"
		"burn": return "E — Touch the burning sconce"
		"recharge": return "E — Rekindle the fire crystal"
	return ""

## Modern adapter (owner r12h F10 2026-10-26, Dragon Gem in hand: "can't use the Sk key on the buttons"): the native
## insert needs the key in the hand cursor (State.group). With the key carried in the pack and the hand empty or holding
## another carried item, E at a reachable empty lock puts that item away, takes the key into the hand and runs the same
## source insert group; the put-away item stays carried.
func _pack_key_ready() -> bool:
	var held := str(host.hand_item)
	return _ready_for_use() and held != State.KEY and State.KEY in host.carried_collected and (held == "" or held in host.carried_collected)

func _with_key_in_hand(action: Callable) -> Variant:
	var held := str(host.hand_item)
	host.hand_item = State.KEY
	var result: Variant = action.call()
	host.hand_item = held
	return result

func admission_hint() -> String:
	if not _pack_key_ready(): return ""
	if _with_key_in_hand(func(): return target().get("group", "")) != "insert": return ""
	var held := str(host.hand_item)
	if held == "": return "E — Place Sk key in the lock"
	var label: String = host._stowed_label(held) if host.has_method("_stowed_label") else held
	return "E — Place Sk key in the lock (puts away %s)" % label

func use_from_pack() -> bool:
	if not _pack_key_ready(): return false
	var held := str(host.hand_item)
	if _with_key_in_hand(func(): return target().get("group", "")) != "insert": return false
	host.hand_item = State.KEY
	if use():
		if held != "" and host.has_method("save_feedback"): host.save_feedback("%s put away." % (host._stowed_label(held) if host.has_method("_stowed_label") else held))
		return true
	host.hand_item = held
	return false

## Plain takes only (a key out of a lock, SS1 from the panel): the host's put-away retry uses these, never burns.
func use_take() -> bool:
	return target().get("group", "") in ["take", "give"] and use()
func take_hint() -> String:
	return interaction_hint() if target().get("group", "") in ["take", "give"] else ""

func use() -> bool:
	var t := target()
	if t.is_empty(): return false
	var inventory := {"collected":host.carried_collected,"hand":host.hand_item}
	if t.has("sconce") and t.group == "recharge":
		# op2 0x18 takes the held crystal; op3 gives it back rekindled (same carried id, 1 charge).
		if not host.item_effects.recharge_crystal(host.hand_item): return false
		host.hand_item = ""
		if host.has_method("save_feedback"): host.save_feedback("The fire crystal glows again.")
		return true
	if t.has("sconce"): return burn()
	if t.has("panel"):
		if State.run_panel(state, inventory).is_empty(): return false
	else:
		var effects := State.run(state, int(t.lock), inventory)
		if effects.is_empty(): return false
		lock_sound(int(t.lock), effects[0] == "insert")
		if int(t.lock) == 140 and is_instance_valid(host.gallery):
			if effects[0] == "insert": host.gallery.lock_insert()
			else: host.gallery.lock_take()
	host.hand_item = inventory.hand
	present()
	if is_instance_valid(host.interface_hud) and host.interface_hud.has_method("refresh_equipment"): host.interface_hud.refresh_equipment()
	return true

func present() -> void:
	for id in key_markers: key_markers[id].visible = State.is_loaded(state, id)
	for flame in flames: flame.visible = State.sconces_lit(state)
	panel.visible = State.panel_lowered(state)
	panel_item.visible = int(state.panel_state) == 0
	if not passage.is_empty(): set_passage_open(State.is_loaded(state, 78))
