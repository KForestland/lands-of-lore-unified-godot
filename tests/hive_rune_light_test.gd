extends SceneTree
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	root.grab_focus()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var light = scene.rune_light
	# Supplied local aim fixture; continuous earned-wax arrival is not claimed.
	scene.player.position = light.aim_point()+Vector3(0,-10,60)
	var direction: Vector3 = light.aim_point()-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
	await physics_frame
	if not check(light.target(),"Source lighting prop has no clear aim from fixture"): return
	scene.interface_hud._process(0)
	if not check(scene.interface_hud.hint.text == "G — Cast Spark","Spark hint missing"): return
	scene.interface_hud.set_cursor(true)
	if not check(not light.cast(),"Cursor overlay allowed Spark"): return
	scene.interface_hud.set_cursor(false)
	scene.player_magic_checkpoint = {"version":1,"player":{"experience":0,"level":1,"maximum":20,"mana":0}}
	if not check(not light.cast() and not scene.runes.checkpoint.lights,"Zero mana lit room"): return
	scene.player_magic_checkpoint.player.mana = 20
	scene.player_form=1
	if not check(not light.target() and not light.cast() and scene.player_magic_checkpoint.player.mana==20,"Beast cast or spent mana"): return
	scene.player_form=0
	var path := "user://tests/rune_light_%d.json" % Time.get_ticks_usec()
	if not check(scene.quicksave(path).is_empty(),"Unlit save failed"): return
	key(KEY_Q)
	key(KEY_G) # Same-frame legacy shortcut must not debit the same light twice.
	if not check(scene.runes.checkpoint.lights and scene.player_magic_checkpoint.player.mana == 19 and light.glow.visible,"Spark did not light room/debit mana"): return
	if not check(not light.cast() and scene.player_magic_checkpoint.player.mana == 19,"Repeated lit interaction debited mana"): return
	if not check(scene.quicksave(path+".lit").is_empty(),"Lit save failed"): return
	if not check(scene.quickload(path).is_empty() and not scene.runes.checkpoint.lights and scene.player_magic_checkpoint.player.mana == 20,"Unlit rollback failed"): return
	scene.set_physics_process(false)
	light.refresh()
	if not check(light.sprite.texture == light.unlit and not light.glow.visible,"Unlit art did not restore"): return
	scene.player_form=2
	key(KEY_G)
	if not check(scene.runes.checkpoint.lights and scene.player_magic_checkpoint.player.mana==19,"Lizard could not cast"): return
	if not check(scene.quickload(path+".lit").is_empty(),"Lit rollback failed"): return
	scene.set_physics_process(false)
	light.refresh()
	if not check(light.sprite.texture in light.textures and scene.runes.checkpoint.lights,"Lit art/state did not restore"): return
	# The lighting result is the room controller's actual admission state.
	scene.runes.checkpoint.room = "RUNES"
	scene.runes.checkpoint.marker642_enabled = true
	scene.runes.refresh()
	if not check(scene.runes.activate_hotspot(2),"Cast lighting did not admit inscription"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,scene.runes): return
	if not check(scene.runes.checkpoint.room == "RUNECL","Inscription speech did not finish"): return
	if not check(not light.cast(),"Room allowed world casting"): return
	scene.runes.leave()
	scene.runes.leave()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await physics_frame
	await process_frame
	if not check(jungle.apply_area_handoff(scene.area_handoff()).is_empty(),"Jungle rejected Spark state"): return
	var carried: Dictionary = jungle.area_handoff()
	if not check(carried.quests.hive_rune_entry.lights and carried.quests.player_magic_reward_state.player.mana == 19,"Jungle lost lighting/mana"): return
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: aimed Spark input, mana/overlay guards, original flame art, light saves, inscription admission and Jungle carry")
	quit()
