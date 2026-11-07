extends SceneTree
const Body = preload("res://scripts/lol2/player_form_body.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func capsule_height(body: CharacterBody3D) -> float:
	var shape := body.get_child(0) as CollisionShape3D
	return (shape.shape as CapsuleShape3D).height

func run() -> void:
	check(is_equal_approx(Body.CROUCH_HEIGHT, 32.0) and is_equal_approx(Body.CROUCH_EYE, 28.0), "crouch height 32 and eye 28")
	check(is_equal_approx(Body.HEIGHTS[0], 46.0) and is_equal_approx(Body.RADII[0], 15.0), "standing height and radius stay")
	var player := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	player.add_child(collider)
	var camera := Camera3D.new()
	player.add_child(camera)
	root.add_child(player)
	check(Body.apply(player, camera, 0, false, true), "human crouch applies")
	check(is_equal_approx(capsule_height(player), 32.0) and is_equal_approx((collider.shape as CapsuleShape3D).radius, 15.0), "crouched capsule")
	check(is_equal_approx(camera.position.y, Body.CROUCH_EYE - Body.FOOT_OFFSET), "crouch eye")
	check(Body.apply(player, camera, 0, false, false), "stand again")
	check(is_equal_approx(capsule_height(player), 46.0), "standing height returns")
	check(Body.apply(player, camera, 1, false, false), "beast stands")
	var beast_height: float = (player.get_child(0) as CollisionShape3D).shape.height
	check(not Body.apply(player, camera, 1, false, true) and is_equal_approx((player.get_child(0) as CollisionShape3D).shape.height, beast_height), "a beast crouch is refused")
	var scene: Node = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.player.position = Vector3(-1869.547, 22.047, -1092.211)
	scene.player.velocity = Vector3.ZERO
	var grounded := false
	for _i in 40:
		await physics_frame
		if scene.player.is_on_floor():
			grounded = true
			break
	check(grounded, "the owner point has a floor")
	check(scene.set_crouch(true, true), "hold C at the owner point")
	check(is_equal_approx(capsule_height(scene.player), 32.0) and scene.crouched, "the museum body crouches")
	check(scene.set_crouch(false, true) and is_equal_approx(capsule_height(scene.player), 46.0) and not scene.crouched, "releasing C stands")
	scene.queue_free()
	player.queue_free()
	await process_frame
	if failures == 0: print("PASS museum crouch: height 32, eye 28, owner point")
	quit(1 if failures else 0)
