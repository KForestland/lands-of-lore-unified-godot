extends SceneTree
## OF7. The owner stood at (2148, -1521, h -118) and hit the bone baskets.
## Spark lights prop 222 from that stand. A sword does not. The flame stays lit,
## the unlit basket is hidden, and the lit one is a local light.
## Rendered: Godot --headless uses the dummy renderer, whose MultiMesh
## set_instance_transform is a no-op and get_instance_transform returns identity.
const Brazier = preload("res://scripts/lol2/l10_braziers.gd")
const STAND := Vector3(2148, -108, -1521)
const LIGHT_SHADER := "shader_type spatial;\nrender_mode unshaded;\nuniform int light_count = 0;\nuniform vec3 light_positions[16];\nuniform vec4 light_colors[16];\nvoid fragment() { ALBEDO = vec3(1.0); }\n"
var failures := 0

class MapHost extends Node3D:
	var geometry_file := "res://assets/lol2/generated/maps/L10_DC/area.json"
	var quest_state: Dictionary = {}
	var flying := false
	var camera: Camera3D
	var player: CharacterBody3D
	var starting_magic: Node
	var prop_placements: Dictionary = {}
	var sector_lighting: Node
	var feedback: Array[String] = []
	func save_feedback(text: String) -> void:
		feedback.append(text)

class Shade extends Node:
	var materials: Array = []

class MagicStub extends Node:
	var mana := 1
	func magic_state() -> Dictionary:
		return {"player": {"mana": mana}}

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	failures += 1
	push_error(message)
	print("FAIL brazier spark: ", message)

func run() -> void:
	if not Brazier.admits(Brazier.SPARK_WORD0, 0):
		fail("Spark word does not admit")
		quit(1)
		return
	if Brazier.admits(Brazier.CUT_WORD0, 0):
		fail("Sword word admits")
		quit(1)
		return
	if Brazier.admits(Brazier.SPARK_WORD0, 2):
		fail("Remaining 2 still admits")
		quit(1)
		return
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L10_DC/area.json"))
	var shades: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/sector_shades/L10_DC.json"))
	var row: Array = shades.rows[15]
	if float(row[0]) < 0.10 or float(row[0]) > 0.25:
		fail("Shade row 15 is not the dim catacomb band")
		quit(1)
		return
	var host := MapHost.new()
	var magic := MagicStub.new()
	host.starting_magic = magic
	host.player = CharacterBody3D.new()
	host.camera = Camera3D.new()
	host.player.add_child(host.camera)
	host.camera.position = Vector3(0, 10, 0)
	host.player.position = Vector3(STAND.x, STAND.y - 10.0, STAND.z)
	host.add_child(host.player)
	var mesh := BoxMesh.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var count := 0
	for row_prop in pack.props:
		if int(row_prop.get("template", -1)) != 23: continue
		count += 1
	multi.instance_count = count
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = multi
	host.add_child(shown)
	var index := 0
	for row_prop in pack.props:
		if int(row_prop.get("template", -1)) != 23: continue
		var at := Vector3(row_prop.position[0], row_prop.position[1], row_prop.position[2])
		multi.set_instance_transform(index, Transform3D(Basis(), at))
		host.prop_placements[int(row_prop.record)] = [multi, index, at]
		index += 1
	var shade := Shade.new()
	var shader := Shader.new()
	shader.code = LIGHT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	shade.materials = [mat]
	host.sector_lighting = shade
	host.add_child(shade)
	root.add_child(host)
	var braziers: Node3D = Brazier.attach(host)
	await physics_frame
	await physics_frame
	var aim: Vector3 = braziers.aims["222"]
	host.camera.look_at(aim, Vector3.UP)
	if braziers.reachable("222"):
		fail("E reach includes the reported stand")
		quit(1)
		return
	if not braziers.spark_aimed("222"):
		fail("Spark aim misses prop 222 from the reported stand")
		quit(1)
		return
	magic.mana = 0
	braziers._process(0.016)
	if braziers.hint.text != "":
		fail("Spark hint with no mana is '%s'" % braziers.hint.text)
		quit(1)
		return
	magic.mana = 1
	var blocked := StaticBody3D.new()
	blocked.collision_layer = 1
	var blocked_shape := CollisionShape3D.new()
	var blocked_box := BoxShape3D.new()
	blocked_box.size = Vector3(40, 40, 40)
	blocked_shape.shape = blocked_box
	blocked.add_child(blocked_shape)
	blocked.position = (host.camera.global_position + aim) * 0.5
	host.add_child(blocked)
	await physics_frame
	braziers._process(0.016)
	if braziers.spark_target() != "" or braziers.hint.text != "":
		fail("Spark hint through a wall is '%s' target %s" % [braziers.hint.text, braziers.spark_target()])
		quit(1)
		return
	blocked.queue_free()
	await physics_frame
	if braziers.spark_target() != "222":
		fail("Spark target is %s" % braziers.spark_target())
		quit(1)
		return
	braziers._process(0.016)
	if braziers.hint.text != "Spark — Light brazier":
		fail("Hint is '%s' paused %s" % [braziers.hint.text, str(braziers.get_tree().paused)])
		quit(1)
		return
	var stand_player := host.player.position
	var stand_cam := host.camera.global_transform
	magic.mana = 0
	host.player.position = aim - Vector3(0, 10, 80)
	host.camera.look_at(aim, Vector3.UP)
	await physics_frame
	braziers._process(0.016)
	if not braziers.reachable("222"):
		fail("Close stand is outside E reach")
		quit(1)
		return
	if braziers.hint.text != "E — Light brazier":
		fail("E hint is '%s'" % braziers.hint.text)
		quit(1)
		return
	host.player.position = stand_player
	host.camera.global_transform = stand_cam
	magic.mana = 1
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, host.camera.global_position - host.camera.global_basis.z * Brazier.SPARK_REACH, 3, [host.player.get_rid()])
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("spark_receiver"):
		fail("Spark ray missed the basket")
		quit(1)
		return
	var receiver: Object = hit.collider.get_meta("spark_receiver")
	if not receiver.receive_spark():
		fail("Spark receiver did not light")
		quit(1)
		return
	if not braziers.lit("222") or not braziers.flames["222"].visible:
		fail("Prop 222 stayed dark")
		quit(1)
		return
	var hidden: Transform3D = multi.get_instance_transform(int(host.prop_placements[222][1]))
	if hidden.basis.x.length() > 0.01:
		fail("Unlit basket still drawn basis %s origin %s" % [str(hidden.basis), str(hidden.origin)])
		quit(1)
		return
	if braziers.receive_hit("223", Brazier.CUT_WORD0, 0).ok or braziers.lit("223"):
		fail("Sword lit prop 223")
		quit(1)
		return
	var again: Dictionary = braziers.receive_hit("222", Brazier.SPARK_WORD0, 0)
	if again.ok or braziers.state().lit.size() != 1:
		fail("Second spark changed the lit list")
		quit(1)
		return
	var lights: Array[String] = braziers.nearest_lit(host.camera.global_position)
	if lights.size() != 1 or lights[0] != "222":
		fail("Light list %s" % [str(lights)])
		quit(1)
		return
	var uploaded: int = int(mat.get_shader_parameter("light_count"))
	var positions: PackedVector3Array = mat.get_shader_parameter("light_positions")
	var colors: PackedVector4Array = mat.get_shader_parameter("light_colors")
	if uploaded != 1 or positions.size() != 16 or positions[0] != braziers.aims["222"]:
		fail("Light upload count %d positions %s" % [uploaded, str(positions)])
		quit(1)
		return
	if colors.size() != 16 or colors[0] != Vector4(Brazier.LIGHT_RGB.x, Brazier.LIGHT_RGB.y, Brazier.LIGHT_RGB.z, Brazier.LIGHT_RANGE):
		fail("Light colour %s" % str(colors))
		quit(1)
		return
	if not braziers.near_unlit(host.player.global_position):
		fail("A remaining unlit basket is outside the note reach")
		quit(1)
		return
	var saved: Dictionary = braziers.state().duplicate(true)
	host.quest_state[Brazier.KEY] = {"version": 1, "lit": []}
	braziers.restore()
	if braziers.flames["222"].visible:
		fail("Cleared state still shows the flame")
		quit(1)
		return
	host.quest_state[Brazier.KEY] = saved
	braziers.restore()
	if not braziers.flames["222"].visible or not braziers.lit("222"):
		fail("Reload lost the lit basket")
		quit(1)
		return
	if Brazier.validate(braziers.state()) != "":
		fail("Lit state does not validate")
		quit(1)
		return
	host.queue_free()
	await process_frame
	print("PASS brazier spark: prop 222 lights from the reported stand, the sword does not, the flame restores")
	quit(0)
