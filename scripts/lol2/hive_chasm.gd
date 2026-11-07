extends Node3D
## Source rock233/group1680. Hit shape, one-hit activation and timing are authored. The native kind9 mask 0x09FF
## takes melee and Spark, so the rock is on the melee (4) and Spark (8) layers.
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const ROOT := "res://assets/lol2/generated/hive_chasm/"
const TRIGGER_LAYERS := 4 | 8
const NAV := "res://assets/lol2/generated/creature_nav/L5_HC.json"
## The gorge under the rock: the closed walkable component of region 94 in the source graph (all floors -600, every
## neighbour 365 higher). Modern rescue (docs/DEVIATIONS.md): standing on its floor puts the player back on the east
## bank (region 121), where the rock can be struck.
const GORGE := [94,95,96,97,105,106,107,108,109,110,111,112,113,114,115,116,117,146,147,148,153,154,155,156,157]
const GORGE_FLOOR := -600.0
const BANK := Vector3(-925,-202.96,-6082)
var gorge: Array[PackedVector2Array] = []
var data: Dictionary
var activated := false
var elapsed := 0.0
var floors: Array[AnimatableBody3D] = []
var trigger: StaticBody3D
var rubble: Node3D
var rubble_material: StandardMaterial3D
var frames: Array[AtlasTexture] = []
var rendered_frame := -1
var configured := false
var completed: bool:
	get: return activated and elapsed == Quests.CHASM_DURATION

class Receiver:
	extends RefCounted
	var chasm
	func receive_spark() -> bool: return chasm.activate()

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"chasm.json"))
	trigger = StaticBody3D.new()
	trigger.position = Vector3(data.trigger.position[0],data.trigger.position[1],data.trigger.position[2])
	trigger.collision_layer = TRIGGER_LAYERS
	trigger.set_meta("hive_chasm",233)
	var receiver := Receiver.new()
	receiver.chasm = self
	trigger.set_meta("spark_receiver",receiver)
	add_child(trigger)
	var hit_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = (data.trigger.right-data.trigger.left)/2.0
	cylinder.height = data.trigger.top-data.trigger.bottom
	hit_shape.shape = cylinder
	hit_shape.position.y = (data.trigger.top+data.trigger.bottom)/2.0
	trigger.add_child(hit_shape)
	var nav: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAV)) if FileAccess.file_exists(NAV) else null
	if nav is Dictionary:
		for region in GORGE:
			var polygon := PackedVector2Array()
			for point in nav.regions[region][0]: polygon.append(Vector2(point[0],point[1]))
			gorge.append(polygon)
	# The parent constructs source materials after child _ready callbacks.
	configure.call_deferred()

func configure() -> void:
	var review = get_parent()
	for floor_data in data.floors:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(review.materials[floor_data.material])
		var collision := PackedVector3Array()
		for i in [0,1,2,0,2,3]:
			var p = floor_data.points[i]
			var vertex := Vector3(p[0],p[1],p[2])
			surface.set_uv(Vector2(floor_data.uv[i][0],floor_data.uv[i][1]))
			surface.add_vertex(vertex)
			collision.append(vertex)
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.name = "ChasmFloor_%d" % int(floor_data.region)
		body.set_meta("target_rise",float(floor_data.target_height)+600.0)
		add_child(body)
		body.add_child(mesh)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(collision)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		floors.append(body)
	var atlas := ImageTexture.create_from_image(Image.load_from_file(ROOT+"rubble.png"))
	for i in range(int(data.frame_count)):
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2((i%int(data.atlas_columns))*data.frame_size[0],(i/int(data.atlas_columns))*data.frame_size[1],data.frame_size[0],data.frame_size[1])
		frames.append(frame)
	rubble_material = StandardMaterial3D.new()
	rubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	rubble_material.alpha_scissor_threshold = 0.5
	rubble_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rubble_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rubble = Node3D.new()
	add_child(rubble)
	for source in data.rubble:
		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(data.rubble_size[0],data.rubble_size[1])
		quad.center_offset.y = data.rubble_size[1]/2.0
		sprite.mesh = quad
		sprite.material_override = rubble_material
		sprite.position = Vector3(source.position[0],source.position[1],source.position[2])
		rubble.add_child(sprite)
	configured = true
	apply_presentation()

func activate() -> bool:
	if activated or not configured or not get_parent().get_node("Warriors").active(): return false
	activated = true
	elapsed = 0.0
	get_parent().get_node("Nest").chasm_handoff()
	apply_presentation()
	return true

func _physics_process(delta: float) -> void:
	advance(delta)
	rescue()

## Back to the east bank when standing on the gorge floor (risen floors are well above it).
func rescue() -> bool:
	var review = get_parent()
	var player: CharacterBody3D = review.player
	if not player.is_on_floor() or player.position.y-32.0 > GORGE_FLOOR+8.0: return false
	var point := Vector2(player.position.x,player.position.z)
	for polygon in gorge:
		if Geometry2D.is_point_in_polygon(point,polygon):
			player.position = BANK
			player.velocity = Vector3.ZERO
			if review.get("interface_hud") != null and is_instance_valid(review.interface_hud):
				review.interface_hud.hint.text = "You climb back out of the gorge."
				review.interface_hud.save_notice_remaining = 3.0
			return true
	return false

func advance(delta: float) -> void:
	if not configured or not activated or completed or get_tree().paused or not is_finite(delta): return
	elapsed = minf(elapsed+maxf(delta,0),Quests.CHASM_DURATION)
	apply_presentation()

func apply_presentation() -> void:
	trigger.collision_layer = 0 if activated else TRIGGER_LAYERS
	if not configured: return
	for body in floors:
		body.visible = activated
		body.collision_layer = 1 if activated else 0
		body.position.y = float(body.get_meta("target_rise"))*elapsed/Quests.CHASM_DURATION
	rubble.visible = activated and not completed
	var frame := mini(int(elapsed*15.0),frames.size()-1)
	if frame != rendered_frame:
		rubble_material.albedo_texture = frames[frame]
		rendered_frame = frame
	for sprite in get_parent().get_node("SourcePropCandidates").instances:
		if int(sprite.get_meta("source_record")) in [229,230,231,232,233]: sprite.visible = not activated

func checkpoint() -> Dictionary:
	return {"activated":activated,"elapsed":elapsed}

func restore(state: Dictionary) -> void:
	activated = state.activated
	elapsed = float(state.elapsed)
	apply_presentation()
