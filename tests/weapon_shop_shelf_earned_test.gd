extends SceneTree
## Owner r17 16-52-10 at Jungle (-5279, -595): the shop shelf had no bow, sword, or bracer to click.
## Walk the last of the shop approach, then click the three longplay pictures.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const State := preload("res://scripts/lol2/weapon_shop_state.gd")
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL shelf: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	scene.set_physics_process(false)
	if is_instance_valid(scene.village_alarm):
		scene.village_alarm.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var shop = scene.weapon_shop
	if shop == null or not shop.available:
		fail("Weapon shop missing")
		return
	var outside: String = await walk_to(Vector2(-5231.0, -637.0), Vector2(-5280.5, -601.5))
	if not outside.is_empty():
		fail(outside)
		return
	if shop.active():
		fail("Entered the hut before the door")
		return
	var inside: String = await walk_to(Vector2(scene.player.global_position.x, scene.player.global_position.z), Vector2(-5310.0, -610.0))
	if not shop.active() or shop.state().room != "WPNEXT":
		fail("Door walk did not open the exterior (%s) at %s" % [inside, scene.player.global_position])
		return
	if not shop.interact("enter"):
		fail("Could not enter the shop")
		return
	shop.advance(1000.0)
	if State.active(shop.state()) or shop.state().room != "WPN":
		fail("Introduction did not finish")
		return
	if not await click_picture(0, "shortsword"):
		return
	shop.advance(1000.0)
	if State.ITEMS["5-Short swd"] not in scene.carried_collected or shop.shelf[0].visible:
		fail("The sword click did not grant the short sword")
		return
	if not await click_picture(2, "gargoyle_after_sword"):
		return
	shop.advance(1000.0)
	if State.ITEMS["42-Gargoyle br"] not in scene.carried_collected or shop.shelf[2].visible:
		fail("The bracer click did not grant the bracers")
		return
	if not await click_picture(1, "orb"):
		return
	shop.advance(1000.0)
	if scene.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB", 0) != 1:
		fail("The bow click did not start the Firestorm talk")
		return
	if State.ITEMS["9-Firestorm"] in scene.carried_collected:
		fail("The bow click granted Firestorm without the orb")
		return
	var carried: int = scene.carried_collected.size()
	shop.interact("shortsword")
	if State.active(shop.state()) or scene.carried_collected.size() != carried:
		fail("The sword could be bought twice")
		return
	print("PASS shelf: walked into the hut at (-5310,-610), and clicks on the sword, the bracer, and the bow used the existing purchases")
	quit(0)

func walk_to(start: Vector2, target: Vector2) -> String:
	plant(start)
	var body: CharacterBody3D = scene.player
	for _settle in 20:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	var floor_y: float = body.global_position.y
	var stuck := 0
	var previous := body.global_position
	for _i in 700:
		if scene.weapon_shop.active():
			return ""
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 8.0:
			return ""
		await physics_frame
		scene.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		if body.global_position.y < floor_y - 160.0 or scene.resets != 0:
			return "Fell on the way to %s at %s" % [target, body.global_position]
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				return "Stuck on the way to %s at %s" % [target, body.global_position]
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	return "Stopped %.1f short of %s at %s" % [left, target, body.global_position]

func plant(at: Vector2) -> void:
	var body: CharacterBody3D = scene.player
	var from := Vector3(at.x, 400.0, at.y)
	var to := Vector3(at.x, -400.0, at.y)
	var ground := 26.0
	for _attempt in 6:
		var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var normal: Vector3 = hit.normal
		if normal.y > 0.5:
			ground = hit.position.y
			break
		from = hit.position + Vector3(0.0, -0.5, 0.0)
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO

func click_picture(index: int, sequence: String) -> bool:
	var picture: TextureRect = scene.weapon_shop.shelf[index]
	if not picture.visible:
		fail("Picture %d was not on the shelf" % index)
		return false
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = picture.size * 0.5
	picture.gui_input.emit(event)
	await process_frame
	if scene.weapon_shop.state().sequence != sequence:
		fail("Picture %d started %s" % [index, scene.weapon_shop.state().sequence])
		return false
	return true
