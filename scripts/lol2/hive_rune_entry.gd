extends Node3D
## E interaction adapts source control0/event4. Source group5244 is staged intact.
## Rune pit: the region506 floor tiles carry region event1 groups with the same room sequence (hive_rune_pit_source.json).
## Arriving grounded on a room-11 tile runs it, so walking or jumping into the pit opens RUNES (original longplay
## 1:37:17). Region625's room-10 (RUNECL) record is not hosted. docs/DEVIATIONS.md 2026-10-24 Hive rune pit.
const Speech = preload("res://scripts/lol2/hive_rune_speech.gd")
const Stone = preload("res://scripts/lol2/hive_ancient_stone.gd")
const State = preload("res://scripts/lol2/hive_rune_entry_state.gd")
const ROOT := "res://assets/lol2/generated/hive_rune_entry/"
const PIT_SOURCE := "res://scripts/lol2/hive_rune_pit_source.json"
const PIT_FLOOR_TOLERANCE := 8.0
var checkpoint := State.initial()
var host: Node3D
var data: Dictionary
var body: StaticBody3D
var layer: CanvasLayer
var view: Control
var notice: Label
var held: OptionButton
var hotspots: Array[Control] = []
var pit: Dictionary
var pit_region := -1
func _ready() -> void:
	host = get_parent()
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"entry.json"))
	pit = JSON.parse_string(FileAccess.get_file_as_string(PIT_SOURCE))
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
## The hosted room-11 pit tile whose floor the player stands on, or {}.
func pit_tile_at(position: Vector3) -> Dictionary:
	var feet := position.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for tile in pit.tiles:
		if int(tile.room_index) != 11 or absf(feet-float(tile.floor)) > PIT_FLOOR_TOLERANCE+host.player.safe_margin: continue
		var polygon := PackedVector2Array()
		for p in tile.polygon: polygon.append(Vector2(p[0],p[1]))
		if Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),polygon): return tile
	return {}
func _physics_process(_delta: float) -> void:
	if active() or host.flying or get_tree().paused or not host.player.is_on_floor():
		if active(): pit_region = -1
		return
	if host.interface_hud.cursor_active or host.get_node("Warriors").health == 0: return
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return
	var tile := pit_tile_at(host.player.global_position)
	var region := int(tile.get("region",-1))
	if region != -1 and region != pit_region: enter_pit(tile)
	pit_region = region
## Region event1 group of one pit tile: [opcode197 marker642] [opcode9 prop71 property21] opcode12 RUNES, then the
## group's own opcode18 pose when the room closes.
func enter_pit(tile: Dictionary) -> bool:
	if active() or int(tile.get("room_index",0)) != 11: return false
	if tile.marker642: checkpoint.marker642_enabled = true
	if tile.dawn20_link and is_instance_valid(host.get("dawn20")): host.dawn20.room_entered()
	checkpoint.room = "RUNES"
	checkpoint.return_xz = pit.return_pose.xz.duplicate()
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
	# Source opcode18 follows the blocking room call: flags5 (control0) / 0x885 (pit tiles) preserve incoming height.
	var xz: Array = checkpoint.get("return_xz",data.return_pose.xz)
	checkpoint.erase("return_xz")
	host.player.position.x = float(xz[0])
	host.player.position.z = float(xz[1])
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
		# Presentation adapter (owner r12e report 1): the selector stands in for the original held cursor; with a full pack
		# its list scrolls at the bottom of the screen and wax could sit out of view, so carried wax is listed first.
		var transaction := preload("res://scripts/lol2/hive_rune_transaction.gd")
		for item in preload("res://scripts/lol2/hand_selector_order.gd").wanted_first(host.carried_inventory.collected,transaction.is_wax):
			held.add_item("Wax" if transaction.is_wax(item) else ("Wax runes" if preload("res://scripts/lol2/hive_rune_items.gd").valid(item) else str(item).get_slice(":",2).replace("_"," ")))
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
	# Let the global playtest reporter capture this active overlay, and Enter reach the dialogue skip.
	if event is InputEventKey and event.keycode in [KEY_F10,KEY_ENTER,KEY_KP_ENTER]: return
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
	var transaction := preload("res://scripts/lol2/hive_rune_transaction.gd")
	if not transaction.is_wax(selected):
		start_speech("2:51" if selected.is_empty() else "2:35")
		return true
	var result: Dictionary = transaction.copy_wax(host.area_handoff().quests,host.carried_inventory,selected)
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

## Enter skips the line now playing (dialogue_skip.gd): the speech clock runs to its end, so the inscription
## continuation (flag286, RUNECL) still applies.
func skip_line() -> bool:
	if not active() or get_tree().paused or not Speech.active(checkpoint): return false
	if Speech.advance(checkpoint,maxf(float(Speech.media()[checkpoint.speech_key].duration)-float(checkpoint.speech_elapsed),0.0)): refresh()
	return true
