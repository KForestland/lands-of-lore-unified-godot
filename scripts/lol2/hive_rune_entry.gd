extends Node3D
## E interaction adapts source control0/event4. Source group5244 is staged intact.
const Speech = preload("res://scripts/lol2/hive_rune_speech.gd")
const Stone = preload("res://scripts/lol2/hive_ancient_stone.gd")
const State = preload("res://scripts/lol2/hive_rune_entry_state.gd")
const ROOT := "res://assets/lol2/generated/hive_rune_entry/"
var checkpoint := State.initial()
var host: Node3D
var data: Dictionary
var body: StaticBody3D
var layer: CanvasLayer
var view: Control
var notice: Label
var held: OptionButton
var hotspots: Array[Control] = []
func _ready() -> void:
	host = get_parent()
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"entry.json"))
	body = StaticBody3D.new()
	add_child(body)
	var vertices := PackedVector3Array()
	var materials: Dictionary = {}
	for face in data.faces:
		if not materials.has(face.material):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+face.material))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			materials[face.material] = material
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(materials[face.material])
		for index in [0,1,2,0,2,3]:
			var p: Array = face.points[index]
			var vertex := Vector3(p[0],p[1],p[2])
			surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]))
			surface.add_vertex(vertex)
			vertices.append(vertex)
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	layer.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = preload("res://scripts/lol2/hive_rune_room_view.gd").new()
	layer.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for room in ["RUNES","RUNECL"]:
		for row in view.manifest.rooms[room].hotspots:
			var a: Array = row.args
			var hit := Control.new()
			hit.position = Vector2(a[1],a[2])
			hit.size = Vector2(a[3]-a[1],a[4]-a[2])
			hit.set_meta("room",room)
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			view.canvas.add_child(hit)
			hotspots.append(hit)
			var hotspot := int(a[0])
			hit.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: activate_hotspot(hotspot))
	held = OptionButton.new()
	held.position = Vector2(420,365)
	held.size = Vector2(204,28)
	view.canvas.add_child(held)
	notice = Label.new()
	notice.position = Vector2(16,365)
	notice.size = Vector2(400,28)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.canvas.add_child(notice)
	layer.hide()
func busy() -> bool:
	return checkpoint.stone_playing or Speech.active(checkpoint)
func active() -> bool:
	return not checkpoint.room.is_empty()
func target() -> bool:
	if active() or host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.interface_hud.cursor_active or host.get_node("Warriors").health == 0: return false
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return false
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*96.0,1,[host.player.get_rid()])
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == body
func interact() -> bool:
	if not target(): return false
	# Opcode197/sub10 enables region642's marker. Keep this state for later marker consumers.
	checkpoint.marker642_enabled = true
	# Opcode9/property21 raises event20 on prop71 (bytes 090347001500: kind3 object 0x0047). Its kind6/20 groups
	# (Hive Dawn20) are admitted now and run after the blocking room call returns (see hive_dawn20_state.gd).
	if is_instance_valid(host.get("dawn20")): host.dawn20.room_entered()
	checkpoint.room = "RUNES"
	checkpoint.response_mask = int(checkpoint.response_mask)&255
	refresh()
	return true
func leave() -> void:
	if not active() or busy(): return
	if checkpoint.room == "RUNECL":
		checkpoint.room = "RUNES"
		checkpoint.response_mask = int(checkpoint.response_mask)&255
		refresh()
		return
	checkpoint.flag286 = true
	checkpoint.room = ""
	# Source opcode18 follows the blocking room call: flags5 preserve incoming height.
	host.player.position.x = data.return_pose.xz[0]
	host.player.position.z = data.return_pose.xz[1]
	# Opcode18 preserves height, but the approach floor is 50 units below the
	# return floor. Godot cannot recover a body wholly below a triangle floor.
	# Resolve only floor penetration after the source reposition; retain higher
	# incoming heights. Support is staged from the containing source region679.
	var support: float = data.return_pose.support_floor + preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET + host.player.safe_margin
	host.player.position.y = maxf(host.player.position.y,support)
	host.player.rotation.y = wrapf(-float(data.return_pose.bearing)*TAU/65536.0,-PI,PI)
	host.player.velocity = Vector3.ZERO
	refresh()
	if is_instance_valid(host.get("dawn20")): host.dawn20.room_closed()
func restore(value: Dictionary) -> void:
	assert(State.validate(value).is_empty())
	checkpoint = State.initial()
	checkpoint.merge(value.duplicate(true),true)
	checkpoint.reward_seed = int(checkpoint.reward_seed)
	checkpoint.response_seed = int(checkpoint.response_seed)
	checkpoint.response_mask = int(checkpoint.response_mask)
	refresh()
func refresh() -> void:
	layer.visible = active()
	host.jump_requested = false
	if active():
		host.player.velocity = Vector3.ZERO
		host.set_physics_process(false)
		host.interface_hud.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if checkpoint.stone_playing: view.show_stone_movie(checkpoint.stone_elapsed)
		elif checkpoint.room == "RUNECL": view.show_inscription()
		else: view.show_runes(checkpoint.lights,checkpoint.flag7)
		for hit in hotspots: hit.visible = not busy() and hit.get_meta("room") == checkpoint.room
		held.visible = checkpoint.room == "RUNECL" and not busy()
		held.clear()
		held.add_item("Empty hand")
		held.set_item_metadata(0,"")
		for item in host.carried_inventory.collected:
			held.add_item("Wax" if item == "hive:item0:Wax" else ("Wax runes" if preload("res://scripts/lol2/hive_rune_items.gd").valid(item) else str(item).get_slice(":",2).replace("_"," ")))
			held.set_item_metadata(held.item_count-1,item)
		notice.text = "" if busy() else ("Escape — Back" if checkpoint.room == "RUNECL" else "Escape — Return to the cavern")
		if Speech.active(checkpoint):
			view.voice.stream = AudioStreamWAV.load_from_file(Speech.media()[checkpoint.speech_key].path)
			view.voice.play(checkpoint.speech_elapsed)
	else:
		view.background.stop()
		view.voice.stop()
		view.background_generation += 1
		host.interface_hud.show()
		var actor = host.get_node("ConversationReview")
		host.set_physics_process(host.get_node("Warriors").health > 0 and not (actor.started and not actor.completed))
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _input(event: InputEvent) -> void:
	if not active() or get_tree().paused: return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: leave()
			elif event.keycode == KEY_F5: notice.text = host.quicksave()
			elif event.keycode == KEY_F9: notice.text = host.quickload()
		get_viewport().set_input_as_handled()

func activate_hotspot(index: int) -> bool:
	if not active() or get_tree().paused or busy(): return false
	if checkpoint.room == "RUNES":
		if index == 1:
			leave()
			return true
		if not checkpoint.lights:
			start_speech("2:26")
			return true
		if index == 3:
			var line := Speech.choose_response(checkpoint)
			if line != 0: start_speech("2:%d" % line)
			return true
		if index == 2:
			if not checkpoint.flag8:
				checkpoint.flag8 = true
				start_speech("2:64","inscription")
			else:
				checkpoint.flag286 = true
				checkpoint.room = "RUNECL"
				refresh()
			return true
		if index == 4:
			if not Stone.begin(checkpoint,host.carried_inventory.collected): return false
			refresh()
			return true
		return false
	if index == 1:
		start_speech("2:62")
		return false # Native RUNECL hotspot1 still returns zero.
	if index != 0: return false
	var selected: String = held.get_item_metadata(held.selected)
	if selected != "hive:item0:Wax":
		start_speech("2:51" if selected.is_empty() else "2:35")
		return true
	var result := preload("res://scripts/lol2/hive_rune_transaction.gd").copy_wax(host.area_handoff().quests,host.carried_inventory)
	if result.has("error"):
		notice.text = result.error
		return false
	var error: String = host.apply_area_handoff({"quests":result.quests,"inventory":result.inventory})
	if not error.is_empty():
		notice.text = error
		return false
	start_speech("2:66")
	return true

func start_speech(key: String, next: String = "") -> void:
	Speech.begin(checkpoint,key,next)
	refresh()
func _process(delta: float) -> void:
	if Speech.active(checkpoint):
		if Speech.advance(checkpoint,delta): refresh()
		return
	if not checkpoint.stone_playing: return
	if Stone.advance(checkpoint,host.carried_inventory.collected,delta):
		if checkpoint.flag7: start_speech("100:2")
		else:
			refresh()
			notice.text = "There is no room to carry the stone."
	else:
		view.set_time(checkpoint.stone_elapsed)
