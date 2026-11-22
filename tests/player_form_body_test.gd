extends SceneTree
const Forms = preload("res://scripts/lol2/player_form_body.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.add_child(CollisionShape3D.new())
	world.add_child(body)
	body.position = Vector3(0,32.1,0)
	var camera := Camera3D.new()
	body.add_child(camera)
	for form in range(3):
		assert(Forms.apply(body,camera,form,false))
		var collider := body.get_child(0) as CollisionShape3D
		assert(is_equal_approx(collider.global_position.y-collider.shape.height/2,0.1))
		assert(is_equal_approx(camera.global_position.y,Forms.EYES[form]+0.1))
		assert(collider.shape.radius == Forms.RADII[form])
		assert(collider.shape.height == Forms.HEIGHTS[form])
	var roof := StaticBody3D.new()
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100,10,100)
	box.shape = shape
	roof.add_child(box)
	world.add_child(roof)
	roof.position.y = 25
	await physics_frame
	await physics_frame
	assert(Forms.apply(body,camera,2))
	var before := camera.position
	assert(not Forms.apply(body,camera,0),"Human cannot expand inside a low passage")
	assert(not Forms.apply(body,camera,1),"Beast cannot expand inside a low passage")
	assert(camera.position == before and body.get_child(0).shape.height == 8)
	body.position.x = 150
	assert(Forms.apply(body,camera,1),"Expansion succeeds outside the passage")
	# A freshly loaded, grounded pose has not yet run move_and_slide, so its
	# floor flag is false. Sub-millimetre stored floor contact is not a ceiling.
	var floor_body:=StaticBody3D.new();var floor_collider:=CollisionShape3D.new()
	var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(100,10,100)
	floor_collider.shape=floor_shape;floor_body.position=Vector3(150,-5,0)
	floor_body.add_child(floor_collider);world.add_child(floor_body)
	body.safe_margin=0.05 # Same controller margin as JungleReview/Act2Map.
	body.position=Vector3(150,31.9975,0)
	assert(Forms.apply(body,camera,0,false))
	await physics_frame;await physics_frame
	assert(not body.is_on_floor(),"Fresh pose has no controller floor flag yet")
	assert(Forms.apply(body,camera,0),"A restored full body tolerates its supporting floor before the first move")
	var saved_floor_camera:=camera.position
	roof.position=Vector3(150,42,0)
	await physics_frame;await physics_frame
	assert(not Forms.apply(body,camera,0),"The restored-pose foot tolerance never trims a real low ceiling")
	assert(camera.position==saved_floor_camera and body.get_child(0).shape.height==46)
	assert(Forms.apply(body,camera,0,true,true),"An actual low ceiling still admits the crouched body")
	for invalid in [-1,3,0.5,"0",null,true,NAN,INF]: assert(not Forms.valid(invalid))
	for form in [0.0,1.0,2.0]: assert(Forms.valid(form))
	world.free()
	print("PASS player forms: source dimensions/eye heights, fixed feet, low-passage expansion rejection and clear-space expansion")
	quit()
