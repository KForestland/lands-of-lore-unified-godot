extends SceneTree
## Source item row7 "56a-Ltng cr" in the low niche (region1010, slab at height 19) behind block95: placed from source,
## out of a standing human's sight, reachable in small form from the room, one-time pickup.
const Crystal := preload("res://scripts/lol2/museum_lightning_crystal.gd")
const Catalog := preload("res://scripts/lol2/item_catalog.gd")
func _initialize() -> void:
	_run.call_deferred()
func fail(message: String) -> void:
	print("FAIL ", message)
	quit(1)
func aim(scene: Node, target: Vector3) -> void:
	for i in 2: await physics_frame
	var look: Vector3 = target - scene.camera.global_position
	scene.player.rotation.y = atan2(-look.x, -look.z)
	scene.camera.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	for i in 3: await physics_frame
func _run() -> void:
	if not Crystal.assets_ready(): return fail("lightning crystal assets missing")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Crystal.ROOT + "items.json"))
	var item: Dictionary = data.items[0]
	if item.id != Crystal.ID or int(item.row) != 7 or item.name != "56a-Ltng cr" or int(item.definition) != 55: return fail("unexpected source item %s" % [item])
	if Vector3(item.position[0], item.position[1], item.position[2]) != Vector3(431, 5, -1416): return fail("unexpected position %s" % [item.position])
	if not Catalog.admitted(Crystal.ID, "museum") or Catalog.admitted(Crystal.ID, "cave"): return fail("catalog scope")
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.flying = false
	scene.interface_hud.set_cursor(false)
	var crystal: Node3D = scene.lightning_crystal
	if not is_instance_valid(crystal): return fail("museum walkthrough did not add the lightning crystal")
	scene.control96.set_process(false)
	scene.control96.set_physics_process(false)
	var target: Vector3 = crystal.sprite.global_position + Vector3(0, 3, 0)
	scene.player.position = Vector3(431, 31, -1380)
	await aim(scene, target)
	if not crystal.interaction_hint().is_empty(): return fail("standing human should not see into the niche")
	preload("res://scripts/lol2/player_form_body.gd").apply(scene.player, scene.camera, 2, false)
	await aim(scene, target)
	if crystal.interaction_hint() != "E — Take Lightning crystal": return fail("crystal not reachable from the room (hint '%s', camera %s)" % [crystal.interaction_hint(), scene.camera.global_position])
	if not crystal.use(): return fail("pickup refused")
	if scene.carried_collected.count(Crystal.ID) != 1 or crystal.sprite.visible: return fail("pickup state")
	if crystal.use() or scene.carried_collected.count(Crystal.ID) != 1: return fail("duplicate pickup")
	crystal.restore_collected([])
	if not crystal.sprite.visible: return fail("restore without receipt hides crystal")
	crystal.restore_collected([Crystal.ID])
	if crystal.sprite.visible: return fail("restore with receipt shows crystal")
	scene.free()
	print("PASS museum lightning crystal: source row7 in the region1010 niche, small-form pickup, one-time")
	quit()
