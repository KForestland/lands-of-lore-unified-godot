extends SceneTree
## Headless control 181. No museum scene and no rendered capture.
const Control181 = preload("res://scripts/lol2/museum_broken_thohan.gd")

class OpenHand extends Control181:
	func _mouse_ready() -> bool:
		return true

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
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_broken_thohan/control.json"))
	var place: Array = catalog.sword.position
	if int(place[0]) != 981 or int(place[1]) != 53 or int(place[2]) != -2552:
		fail("Sword anchor moved")
		return
	var holders: Array = catalog.regions_containing_point
	if holders.size() != 1 or int(holders[0]) != 413 or int(catalog.grant.group) != 11954 or int(catalog.put_back.group) != 11984:
		fail("Region or group catalog changed")
		return
	var host := Node3D.new()
	host.set_script(make_script("extends Node3D\nvar flying:=false\nvar quest_state:Dictionary={}\nvar carried_collected:Array=[]\nvar hand_item:=\"\"\nvar camera:Camera3D\nvar player:Node3D\nvar interface_hud:Node\nvar inventory:Node\nvar magic_shop:Node\n"))
	root.add_child(host)
	current_scene = host
	host.camera = Camera3D.new()
	host.add_child(host.camera)
	host.player = CharacterBody3D.new()
	host.add_child(host.player)
	var control := OpenHand.new()
	host.add_child(control)
	await physics_frame
	if control.sword.position != Vector3(981, 53, -2552) or not control.sword.visible or control.owner_state != 0:
		fail("Sword did not start in mode 0")
		return
	var aim: Vector3 = control.aim_point()
	host.camera.global_position = aim + Vector3(0, 0, 40)
	host.camera.look_at(aim)
	await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var strict := Control181.new()
	host.add_child(strict)
	await physics_frame
	if strict.use():
		fail("Visible mouse granted the sword")
		return
	strict.queue_free()
	await physics_frame
	host.camera.global_position = aim + Vector3(0, 0, 200)
	host.camera.look_at(aim)
	await physics_frame
	if control.use():
		fail("Sword beyond 96 was granted")
		return
	host.camera.global_position = aim + Vector3(0, 0, 40)
	host.camera.look_at(aim + Vector3(40, 0, 0))
	await physics_frame
	if control.use():
		fail("Off-aim use was accepted")
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
	if control.use():
		fail("Occluded sword was granted")
		return
	wall.queue_free()
	await physics_frame
	host.flying = true
	if control.use():
		fail("Flight granted the sword")
		return
	host.flying = false
	var hud := Node.new()
	hud.set_script(make_script("extends Node\nvar cursor_active:=false\n"))
	host.add_child(hud)
	host.interface_hud = hud
	hud.cursor_active = true
	if control.use():
		fail("Cursor granted the sword")
		return
	hud.cursor_active = false
	var bag := Node.new()
	host.add_child(bag)
	host.inventory = bag
	if control.use():
		fail("Inventory granted the sword")
		return
	host.inventory = null
	bag.queue_free()
	await physics_frame
	host.hand_item = "jungle:item51:Th_Dagger"
	if control.use() or control.run_source_group() or control.source_group() != "":
		fail("Occupied hand took the sword")
		return
	host.hand_item = ""
	if not control.use() or host.carried_collected != [Control181.ITEM] or host.hand_item != Control181.ITEM:
		fail("Empty hand did not take the sword")
		return
	if control.sword.visible or control.owner_state != 1 or control.sprite_mode != 1:
		fail("Grant left the sword showing")
		return
	host.hand_item = ""
	if control.use() or control.sword.visible or host.carried_collected != [Control181.ITEM]:
		fail("Stowed sword was granted again")
		return
	host.hand_item = "12-Tho Broken"
	if not control.use() or host.hand_item != "" or Control181.ITEM in host.carried_collected:
		fail("Held broken sword was not returned")
		return
	if not control.sword.visible or control.owner_state != 0 or control.sprite_mode != 0:
		fail("Return did not restore mode 0")
		return
	host.camera.global_position = aim + Vector3(0, 0, 200)
	host.camera.look_at(aim)
	await physics_frame
	if control.use() or not control.run_source_group():
		fail("Source grant followed the reach adapter")
		return
	if control.sword.visible or host.carried_collected != [Control181.ITEM]:
		fail("Far source grant did not hide the sword")
		return
	host.carried_collected.clear()
	host.hand_item = ""
	control.restore()
	if control.sword.visible or control.source_group() != "":
		fail("Saved state let a removed sword respawn")
		return
	host.quest_state.erase(Control181.STATE_KEY)
	host.carried_collected = [Control181.ITEM]
	control.restore()
	if control.sword.visible or control.owner_state != 1 or control.use():
		fail("Carried sword without a save respawned")
		return
	host.carried_collected.clear()
	host.quest_state.erase(Control181.STATE_KEY)
	control.restore()
	host.camera.global_position = aim + Vector3(0, 0, 40)
	host.camera.look_at(aim)
	await physics_frame
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	control._unhandled_input(event)
	if host.carried_collected != [Control181.ITEM] or control.sword.visible:
		fail("E did not take the sword")
		return
	control._unhandled_input(event)
	if host.carried_collected != [] or not control.sword.visible:
		fail("Second E did not put the held sword back")
		return
	host.quest_state[Control181.STATE_KEY] = {"owner_state": 1, "sprite_mode": 0}
	control.restore()
	if not control.sword.visible or control.source_group() != "":
		fail("Sprite mode was tied to owner state")
		return
	print("PASS control181 Tho Broken: empty-hand grant, held return, no respawn, modern reach")
	quit()
