extends SceneTree
const Sprite=preload("res://scripts/lol2/jungle_dino_sprite.gd")
func _initialize() -> void:
	var node:=MeshInstance3D.new();node.mesh=QuadMesh.new()
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/lol2/indexed_surface_review.gdshader")
	node.material_override=material
	var presenter:=Sprite.new()
	assert(presenter.bind(node).is_empty() and node.material_override!=material)
	assert(node.material_override.shader==load("res://scripts/lol2/jungle_dino_sprite.gdshader"))
	var palette: Image=node.material_override.get_shader_parameter("source_palette").get_image()
	assert(palette.get_data()==Image.load_from_file(Sprite.ROOT+"palette.png").get_data())
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Sprite.ROOT+"sprites.json"))
	var cases:=0
	for state in manifest.states:
		for view in state.views:
			for frame in range(view.frames.size()):
				assert(presenter.present(state.selector,float(frame),view.slot).is_empty())
				var actual: Image=node.material_override.get_shader_parameter("indices").get_image()
				var original:=Image.load_from_file(Sprite.ROOT+"frame_%d.png"%int(view.frames[frame]))
				if int(view.flags)==64: original.flip_x()
				assert(actual.get_data()==original.get_data())
				cases+=1
	var before=node.material_override.get_shader_parameter("indices")
	for bad in [[-1,0,0],[11,0,0],[4,14,0],[4,-1,0],[1,0,8],[1.5,0,0],[true,0,0]]:
		assert(not presenter.present(bad[0],bad[1],bad[2]).is_empty())
		assert(node.material_override.get_shader_parameter("indices")==before)
	var invalid:=MeshInstance3D.new()
	assert(not presenter.bind(invalid).is_empty())
	assert(presenter.present(4,9).is_empty())
	assert(presenter.present(5,7).is_empty())
	# Another presenter must not share its mutable material selection.
	var second:=MeshInstance3D.new();second.mesh=QuadMesh.new();second.material_override=material
	var other:=Sprite.new();assert(other.bind_shared(second,presenter).is_empty());assert(other.present(9,0).is_empty())
	before=second.material_override.get_shader_parameter("indices")
	assert(presenter.present(1,3,1).is_empty() and second.material_override.get_shader_parameter("indices")==before)
	assert(other.present(1,3,1).is_empty())
	assert(second.material_override.get_shader_parameter("indices")==node.material_override.get_shader_parameter("indices"))
	assert(second.material_override.get_shader_parameter("source_palette")==node.material_override.get_shader_parameter("source_palette"))
	assert(not other.bind_shared(second,Sprite.new()).is_empty())
	assert(other.present(9,0).is_empty())
	# One loaded library supports the entire15-actor population.
	var population: Array=[]
	for actor in range(15):
		var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.material_override=material
		var instance:=Sprite.new();assert(instance.bind_shared(mesh,presenter).is_empty())
		assert(instance.present(1,actor%14,actor%8).is_empty())
		assert(mesh.material_override!=node.material_override)
		population.append([mesh,instance])
	# Resource references survive loss of the original library owner.
	presenter=null
	for pair in population:
		assert(pair[1].present(4,9).is_empty())
		pair[0].free()
	print("PASS: %d original DINO view/frame pixels, mirrored views, JSON numbers, invalid rollback and independent materials"%cases)
	node.free();second.free();invalid.free();quit()
