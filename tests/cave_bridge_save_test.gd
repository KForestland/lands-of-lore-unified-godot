extends SceneTree
const Save = preload("res://scripts/lol2/cave_bridge_save.gd")
class Host extends Node3D:
	var native_translation := Vector3.ZERO
	var occluder_pairs: Array = []
	var light_pairs: Array = []
	var camera := Camera3D.new()
	func _indexed_material(path: String) -> ShaderMaterial:
		var shader := Shader.new()
		shader.code = "shader_type spatial; uniform sampler2D indices; uniform bool sprite; void fragment(){ALBEDO=texture(indices,UV).rgb;}"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("indices", ImageTexture.create_from_image(Image.load_from_file(path)))
		return material
	func _copy_occluders(mesh: MeshInstance3D) -> void:
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override.duplicate()
		add_child(copy)
		occluder_pairs.append([mesh, copy])
class Warning extends Node:
	var played := false
	var remaining := 0.0
	func dismiss() -> void: remaining = 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.add_child(host.camera)
	var deck = preload("res://scripts/lol2/recovered_river_deck.gd").new()
	host.add_child(deck)
	deck.setup(host)
	deck.set_physics_process(false)
	var chains = preload("res://scripts/lol2/river_chain_interaction.gd").new()
	host.add_child(chains)
	chains.setup(host)
	chains.set_physics_process(false)
	var warning := Warning.new()
	host.add_child(warning)
	var intact := Save.capture(deck, chains, warning)
	assert(Save.validate(intact))
	for id in [85,86,89]:
		chains.chains[id].elapsed = 0.4
		deck.cut_chain(id)
	deck._physics_process(0.35)
	warning.played = true
	var saved := Save.capture(deck, chains, warning)
	assert(Save.validate(saved))
	var path := "user://bridge_roundtrip_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(Save.validate(decoded))
	Save.restore(intact, deck, chains, warning)
	assert(deck.sections[56].body.collision_layer == 1)
	assert(deck.sections[56].mesh.position == deck.sections[56].start)
	assert(not warning.played and deck.chain_rule.cut.is_empty())
	Save.restore(decoded, deck, chains, warning)
	assert(deck.sections[56].body.collision_layer == 0)
	assert(is_equal_approx(deck.sections[56].mesh.position.y, deck.sections[56].start.y-30))
	assert(deck.chain_rule.counts[56] == 2 and deck.chain_rule.counts[57] == 1)
	assert(chains.chains[85].frame == 6 and warning.played)
	assert(Save.capture(deck, chains, warning) == saved)
	deck._physics_process(1.0)
	assert(not deck.sections[56].mesh.visible)
	Save.restore(intact, deck, chains, warning)
	assert(deck.sections[56].mesh.visible and chains.chains[85].frame == -1)
	for pair in host.occluder_pairs:
		if pair[0] == deck.sections[56].mesh: assert(pair[1].visible)
	var bad := saved.duplicate(true)
	bad.cuts.append(bad.cuts[0])
	assert(not Save.validate(bad))
	bad = saved.duplicate(true)
	bad.sections[0] = -1
	assert(not Save.validate(bad))
	bad = saved.duplicate(true)
	bad.cuts[0].elapsed = NAN
	assert(not Save.validate(bad))
	bad = saved.duplicate(true)
	bad.cuts[0].id = 999
	assert(not Save.validate(bad))
	DirAccess.remove_absolute(path)
	host.free()
	print("PASS bridge save: JSON roundtrip, partial cut, falling section, collision/visual rollback, warning, malformed states")
	quit()
