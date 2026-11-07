extends SceneTree
## cave-light-sources-min (owner direction 2026-10-29): the decoded Classic depth shading is an "original darkness" toggle,
## default OFF (shader global lol2_classic_shading_enabled); the Cave light field has a flat ambient with no player-centred
## cone and a list of warm local lights at the hosted native emitters: 7 wall torches, 48 lava flames, 27 tar pits
## (lit only while burning). Headless: contract-derived light list, nearest-set selection, upload to light-pass
## materials, the toggle, and the shader include text.
const Lights = preload("res://scripts/lol2/cave_light_sources.gd")
const ClassicShading = preload("res://scripts/lol2/classic_depth_shading.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

class StubTar extends Node:
	var state := {"props": {}}

class StubHost extends Node3D:
	var native_translation := Vector3(10, 20, 30)
	var light_materials: Array[ShaderMaterial] = []
	var tar_fires: Node

func _initialize() -> void: run.call_deferred()

func run() -> void:
	# 1. Toggle: project default off; set/get round trip.
	check(ProjectSettings.get_setting("shader_globals/lol2_classic_shading_enabled").value == false, "project default: original darkness off")
	check(not ClassicShading.enabled(), "global reads false at start")
	ClassicShading.set_enabled(true); check(ClassicShading.enabled(), "toggle on")
	ClassicShading.set_enabled(false); check(not ClassicShading.enabled(), "toggle off")
	var include := FileAccess.get_file_as_string("res://scripts/lol2/classic_depth_shading.gdshaderinc")
	check(include.contains("global uniform bool lol2_classic_shading_enabled") and include.contains("if (!lol2_classic_shading_enabled) { return index; }"), "classic_shade() is gated by the toggle")
	# 2. Light field include: flat ambient, light loop, no player cone.
	var field := FileAccess.get_file_as_string("res://scripts/lol2/cave_light_field.gdshaderinc")
	check(not field.contains("exp(-length(view_position)"), "no player-centred falloff")
	for token in ["uniform vec3 ambient_light", "uniform int light_count", "light_positions[24]", "light_colors[24]", "weight * weight"]:
		check(field.contains(token), "light field keeps " + token)
	for path in ["res://scripts/lol2/indexed_wall_review.gdshader", "res://scripts/lol2/indexed_surface_review.gdshader"]:
		var shader: Shader = load(path)
		check(shader != null and shader.get_shader_uniform_list().size() > 0, "shader parses: " + path)
	# 3. Contract-derived lights.
	var lights := Lights.collect(Vector3(10, 20, 30))
	var kinds := {}
	for light in lights: kinds[light.kind] = int(kinds.get(light.kind, 0)) + 1
	check(kinds == {"torch": 7, "lava": 48, "tar": 27}, "7 torches + 48 lava flames + 27 tar pits: %s" % kinds)
	var torch20: Dictionary = lights[0]
	check(torch20.id == "torch20" and torch20.position == Vector3(-1564, 40, -6094) + Vector3(10, 20, 30) + Vector3(0, 100 * 0.75, 0), "torch 20 at its native placement, light on the flame: %s" % torch20.position)
	check(torch20.range == 320.0 and torch20.color == Color(0.85, 0.62, 0.34), "torch colour/range adapters")
	# 4. Tar pits light only while burning (selector 2).
	var tar := StubTar.new()
	var first_tar: Dictionary = lights[55]
	check(first_tar.kind == "tar" and not Lights.active(first_tar, tar), "cold tar pit is dark")
	tar.state.props[first_tar.prop] = {"selector": 2}
	check(Lights.active(first_tar, tar), "burning tar pit lights")
	check(Lights.active(torch20, null) and Lights.active(lights[7], null), "torches and lava always light")
	# 5. Nearest set: at most 24, nearest first, cold tar excluded.
	var near := Lights.nearest(lights, torch20.position, tar)
	check(near.size() == Lights.MAX_UPLOADED and near[0].id == "torch20", "nearest set starts with the torch at the eye (%d entries)" % near.size())
	for i in range(1, near.size()):
		check(near[i].position.distance_to(torch20.position) >= near[i - 1].position.distance_to(torch20.position), "nearest set is sorted")
	var burning := 0
	for light in near:
		if light.kind == "tar": burning += 1
	check(burning <= 1, "only the burning tar pit may appear")
	# 6. Upload: once per changed set, to every light material, padded to 24.
	var host := StubHost.new(); host.tar_fires = tar; root.add_child(host)
	var material := ShaderMaterial.new(); material.shader = load("res://scripts/lol2/indexed_wall_review.gdshader")
	host.light_materials.append(material)
	var sources := Lights.new(); sources.build(host)
	check(sources.lights.size() == 82, "build collects 82 lights")
	check(sources.sync(host, torch20.position), "first sync uploads")
	check(int(material.get_shader_parameter("light_count")) == Lights.MAX_UPLOADED, "light_count uploaded")
	var positions: PackedVector3Array = material.get_shader_parameter("light_positions")
	var colors: PackedVector4Array = material.get_shader_parameter("light_colors")
	check(positions.size() == 24 and colors.size() == 24 and positions[0] == torch20.position and colors[0] == Vector4(0.85, 0.62, 0.34, 320.0), "arrays padded to 24, torch first")
	check(not sources.sync(host, torch20.position), "same set: no second upload")
	check(sources.sync(host, Vector3(0, 0, -17000)), "a far viewpoint changes the set")
	host.queue_free(); tar.free(); await process_frame
	ClassicShading.clear()
	print("Cave light sources: %d failures" % failures)
	if failures == 0: print("PASS cave light sources: original darkness toggle default off; 82 emitter lights, nearest 24 uploaded, tar only while burning")
	quit(0 if failures == 0 else 1)
