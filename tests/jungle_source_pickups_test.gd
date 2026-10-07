extends SceneTree
## Headless row-51 pickup. No jungle scene and no earned-route claim.
const Pickups = preload("res://scripts/lol2/jungle_source_pickups.gd")

class TestPickup extends Pickups:
	func _mouse_ready() -> bool: return true

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func make_script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		fail("Host script failed")
	return script

func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_source_pickups/pickups.json"))
	if int(catalog.admitted_rows[0]) != 51 or catalog.admitted_rows.size() != 1 or int(catalog.rows_not_admitted) != 87:
		fail("Row admission catalog changed")
		return
	var row: Dictionary = catalog.pickups[0]
	var place: Array = row.position
	if place.size() != 3 or int(place[0]) != -1629 or int(place[1]) != 70 or int(place[2]) != -4932 or int(row.flags) != 2 or bool(row.dormant) or int(row.region) != 3827:
		fail("Source placement mismatch")
		return
	if int(row.region_hops_from_magic) != 18 or int(row.magic_region) != 2636 or int(row.identity) != Pickups.IDENTITY:
		fail("Source identity or hop count mismatch")
		return
	var host := Node3D.new()
	host.set_script(make_script("extends Node3D\nvar flying:=false\nvar quest_state:Dictionary={}\nvar carried_collected:Array=[]\nvar camera:Camera3D\nvar player:Node3D\nvar interface_hud:Node\nvar inventory:Node\nvar magic_shop:Node\n"))
	root.add_child(host)
	current_scene = host
	host.camera = Camera3D.new()
	host.add_child(host.camera)
	host.player = CharacterBody3D.new()
	host.add_child(host.player)
	var pickup := TestPickup.new()
	host.add_child(pickup)
	await physics_frame
	if pickup.sprite.position != Vector3(-1629, 70, -4932) or not pickup.sprite.visible:
		fail("Dagger sprite was not placed")
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var aim: Vector3 = pickup.aim_point()
	host.camera.global_position = aim + Vector3(0, 0, 40)
	host.camera.look_at(aim)
	await physics_frame
	if not pickup.target():
		fail("Aimed dagger inside reach was rejected")
		return
	host.camera.global_position = aim + Vector3(0, 0, 200)
	host.camera.look_at(aim)
	await physics_frame
	if pickup.target():
		fail("Dagger beyond 96 was accepted")
		return
	host.camera.global_position = aim + Vector3(0, 0, 40)
	host.camera.look_at(aim + Vector3(40, 0, 0))
	await physics_frame
	if pickup.target():
		fail("Off-aim dagger was accepted")
		return
	host.camera.look_at(aim)
	await physics_frame
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 2)
	shape.shape = box
	wall.add_child(shape)
	host.add_child(wall)
	wall.global_position = aim + Vector3(0, 0, 20)
	for _i in 2:
		await physics_frame
	if pickup.target():
		fail("Occluded dagger was accepted")
		return
	wall.queue_free()
	await physics_frame
	host.flying = true
	if pickup.target():
		fail("Flight allowed pickup")
		return
	host.flying = false
	var hud := Node.new()
	hud.set_script(make_script("extends Node\nvar cursor_active:=false\n"))
	host.add_child(hud)
	host.interface_hud = hud
	hud.cursor_active = true
	if pickup.target():
		fail("Cursor overlay allowed pickup")
		return
	hud.cursor_active = false
	var shop := Node.new()
	shop.set_script(make_script("extends Node\nvar on:=false\nfunc active(): return on\n"))
	host.add_child(shop)
	host.magic_shop = shop
	shop.on = true
	if pickup.target():
		fail("MAGIC room allowed world pickup")
		return
	shop.on = false
	var bag := Node.new()
	host.add_child(bag)
	host.inventory = bag
	if pickup.target():
		fail("Inventory allowed world pickup")
		return
	host.inventory = null
	bag.queue_free()
	await physics_frame
	if not pickup.target() or not pickup.collect():
		fail("Collect did not take the aimed dagger")
		return
	if host.carried_collected != [Pickups.ITEM] or pickup.sprite.visible or pickup.collect():
		fail("Collected dagger stayed available")
		return
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	pickup._unhandled_input(event)
	if host.carried_collected.size() != 1:
		fail("E duplicated a collected dagger")
		return
	host.carried_collected.clear()
	pickup.restore()
	if pickup.sprite.visible or pickup.target():
		fail("Traded dagger respawned")
		return
	host.quest_state.clear()
	pickup.restore()
	if not pickup.sprite.visible or not pickup.target():
		fail("Restore did not return a dagger removed from the pack")
		return
	pickup._unhandled_input(event)
	if host.carried_collected != [Pickups.ITEM] or pickup.sprite.visible:
		fail("E did not collect the restored dagger")
		return
	var again := TestPickup.new()
	host.add_child(again)
	await physics_frame
	if again.sprite.visible or again.collect():
		fail("Saved pack did not hide a new dagger node")
		return
	print("PASS row51 Th Dagger: source placement, aim, reach, occlusion, overlays, E collect, pack absence")
	quit()
