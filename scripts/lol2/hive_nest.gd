extends Node3D
## Source prop317→actor36 handoff; local frame scheduling and static actor are authored.
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const ROOT := "res://assets/lol2/generated/hive_nest/"
var data: Dictionary
var phase := 0 # 0 nesting, 1 approach latched, 2 rising, 3 actor shown
var elapsed := 0.0
var nest: MeshInstance3D
var actor: MeshInstance3D
var material: StandardMaterial3D
var clips: Array = []
var rendered_frame := -1
var rendered_clip := -1
var activation_count := 0
var executioner_visual: RefCounted

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"nest.json"))
	for movie in data.movies:
		var atlas := ImageTexture.create_from_image(Image.load_from_file(ROOT+movie.file))
		var frames: Array[AtlasTexture] = []
		for i in int(movie.frames):
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2((i%int(movie.columns))*320,(i/int(movie.columns))*200,320,200)
			frames.append(frame)
		clips.append(frames)
	nest = make_sprite(data.nest,data.nest_size)
	nest.mesh.center_offset.y -= (200.0-float(data.nest_baseline))/200.0*data.nest_size[1]
	material = nest.material_override
	actor = make_sprite(data.actor,data.actor_size)
	actor.mesh.center_offset.y -= (200.0-float(data.actor_baseline))/200.0*data.actor_size[1]
	actor.material_override.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+"executioner.png"))
	apply_presentation()
	hide_source_candidate.call_deferred()

func make_sprite(position_data: Array, dimensions: Array) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	sprite.position = Vector3(position_data[0],position_data[1],position_data[2])
	var quad := QuadMesh.new()
	quad.size = Vector2(dimensions[0],dimensions[1])
	quad.center_offset.y = dimensions[1]/2.0
	sprite.mesh = quad
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	surface.alpha_scissor_threshold = 0.5
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.material_override = surface
	add_child(sprite)
	return sprite

func hide_source_candidate() -> void:
	for sprite in get_parent().get_node("SourcePropCandidates").instances:
		if int(sprite.get_meta("source_record")) == 317: sprite.hide()

func inside_approach(position: Vector3) -> bool:
	for region in data.approaches:
		if position.y < region.floor or position.y > region.ceiling: continue
		var polygon := PackedVector2Array()
		for point in region.polygon: polygon.append(Vector2(point[0],point[1]))
		if Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),polygon): return true
	return false

func approach() -> bool:
	var review = get_parent()
	if phase != 0 or not review.get_node("Warriors").active() or not review.player.is_on_floor() or not inside_approach(review.player.position): return false
	phase = 1
	return true

func _physics_process(delta: float) -> void:
	approach()
	advance(delta)

func advance(delta: float) -> void:
	if phase == 3 or not is_finite(delta) or delta <= 0 or not get_parent().get_node("Warriors").active(): return
	# Preview convention: event1 at the next nesting loop's first frame, then
	# event0 after all28 rise frames. Native global queue timing remains unverified.
	if phase == 1:
		var remaining := 0.0 if elapsed == 0 else Quests.NEST_LOOP_DURATION-elapsed
		if delta < remaining:
			elapsed += delta
			apply_presentation()
			return
		delta -= remaining
		phase = 2
		elapsed = 0
	if phase == 0:
		elapsed = fmod(elapsed+delta,Quests.NEST_LOOP_DURATION)
	elif phase == 2:
		elapsed += delta
		if elapsed >= Quests.NEST_RISE_DURATION: show_actor()
	apply_presentation()

func show_actor() -> void:
	if phase != 3: activation_count += 1
	phase = 3
	elapsed = 0
	apply_presentation()

func chasm_handoff() -> void:
	# Source group1680 bypasses nest playback and activates actor36.
	show_actor()

func apply_presentation() -> void:
	if not is_instance_valid(nest): return
	nest.visible = phase != 3
	actor.visible = phase == 3
	if phase == 3: return
	var clip := 1 if phase == 2 else 0
	var frame := mini(int(elapsed*15),clips[clip].size()-1)
	if clip != rendered_clip or frame != rendered_frame:
		# 3D materials sample the atlas directly; AtlasTexture regions are canvas-only.
		var selected: AtlasTexture = clips[clip][frame]
		var size: Vector2 = selected.atlas.get_size()
		material.albedo_texture = selected.atlas
		material.uv1_scale = Vector3(selected.region.size.x/size.x,selected.region.size.y/size.y,1)
		material.uv1_offset = Vector3(selected.region.position.x/size.x,selected.region.position.y/size.y,0)
		rendered_clip = clip
		rendered_frame = frame

func checkpoint() -> Dictionary:
	return {"phase":phase,"elapsed":elapsed}

func restore(state: Dictionary) -> void:
	phase = int(state.phase)
	elapsed = float(state.elapsed)
	if executioner_visual != null: executioner_visual.present({"pose":0})
	apply_presentation()

func present_executioner(checkpoint: Variant) -> String:
	if phase != 3: return "Executioner is not visible yet."
	if executioner_visual == null:
		var visual = preload("res://scripts/lol2/hive_executioner_sprite.gd").new()
		var error: String = visual.bind(actor)
		if not error.is_empty(): return error
		executioner_visual = visual
	return executioner_visual.present(checkpoint)
