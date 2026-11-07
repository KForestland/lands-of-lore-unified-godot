extends SceneTree
const Presenter=preload("res://scripts/lol2/hive_executioner_sprite.gd")
func _initialize() -> void:
	var sprite:=MeshInstance3D.new()
	sprite.mesh=QuadMesh.new()
	sprite.mesh.size=Vector2(95.0/78.0*40.0,40.0)
	sprite.mesh.center_offset=Vector3(0,20,0)
	sprite.material_override=StandardMaterial3D.new()
	var presenter:=Presenter.new()
	var expected: Dictionary={0:{"frames":1,"width":95,"height":78},1:{"frames":10,"width":95,"height":78}}
	assert(presenter.bind(sprite,"res://assets/lol2/generated/hive_worm_sprites/",expected,Vector2(95,78)).is_empty())
	var size: Vector2=sprite.mesh.size
	var center: Vector3=sprite.mesh.center_offset
	for selector in [0,1]:
		for frame in range(expected[selector].frames):
			assert(presenter.present({"pose":selector,"source_pose":{"selector":selector,"frame":frame}}).is_empty())
			assert(sprite.mesh.size==size and sprite.mesh.center_offset==center)
			var clip: Dictionary=presenter._clips[selector]
			assert(is_equal_approx(sprite.material_override.uv1_scale.x,1.0/clip.columns))
			assert(is_equal_approx(sprite.material_override.uv1_offset.x,float(frame%clip.columns)/clip.columns))
	var material: Material=sprite.material_override
	var mesh: Mesh=sprite.mesh
	var offset: Vector3=sprite.material_override.uv1_offset
	assert(not presenter.present({"pose":1,"source_pose":{"selector":1,"frame":10}}).is_empty())
	assert(sprite.material_override.uv1_offset==offset)
	assert(not presenter.bind(sprite,"res://assets/lol2/generated/hive_worm_sprites/",expected,Vector2.ZERO).is_empty())
	assert(sprite.material_override==material and sprite.mesh==mesh)
	# Default callers must retain the strict320px canvas contract.
	assert(not Presenter.new().bind(sprite,"res://assets/lol2/generated/hive_worm_sprites/",{0:{"frames":1,"height":78}}).is_empty())
	sprite.free()
	print("PASS all11 original boulder frames, explicit95x78 canvas, stable world anchor and malformed visual rollback; default320px contract retained")
	quit()
