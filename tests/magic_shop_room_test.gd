extends SceneTree
const State = preload("res://scripts/lol2/magic_shop_state.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize(): run.call_deferred()
func until(cursor: int) -> float:
	var total := 0.0
	for index in range(cursor): total += State.duration("MAGIC",index)
	return total
func mana(jungle) -> int:
	return int(jungle.starting_magic.magic_state().player.mana)
func run():
	var path := "user://tests/magic_shop_%d.json" % Time.get_ticks_usec()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var shop = jungle.magic_shop
	shop.set_process(false)
	jungle.monastery.set_process(false)
	assert(shop.available and not shop.active())
	# Supplied location only: the ordinary region2636 detector opens MAGIC.
	jungle.player.position = Vector3(-1066,32,-5676)
	shop._process(0.0)
	assert(shop.active() and not jungle.is_physics_processing() and not jungle.monastery.active())
	assert(is_equal_approx(jungle.player.position.x,-1141) and is_equal_approx(jungle.player.position.z,-5679) and is_equal_approx(jungle.player.position.y,32))
	assert(is_equal_approx(jungle.player.rotation.y,PI/2))
	assert(not jungle.open_inventory() and not jungle.starting_magic.world_active())
	var s: Dictionary = shop.state()
	assert(s.conversation.sequence == "MAGIC" and s.flags["58"] == 1 and s.flags["53"] == 0)
	await process_frame
	await process_frame
	assert(shop.view.background.is_playing() and shop.view.voice.playing and shop.back.disabled)
	shop.leave_room()
	assert(shop.active())
	shop.advance(until(5)-0.05)
	assert(s.flags["53"] == 0)
	shop.advance(0.1)
	assert(s.flags["53"] == 1 and s.flags["54"] == 0 and shop.shown_cursor == 5)
	# Exactly-once host1214 debit across a save taken just before line419.
	var magic: Dictionary = jungle.starting_magic.magic_state().duplicate(true)
	magic.player.maximum = 1500
	magic.player.mana = 1500
	jungle.starting_magic.commit(magic)
	shop.advance(until(18)-until(5)-0.1)
	assert(s.flags["54"] == 1 and s.conversation.cursor == 17 and mana(jungle) == 1500)
	assert(jungle.quicksave(path).is_empty())
	shop.advance(0.1)
	assert(shop.state().conversation.cursor == 18 and mana(jungle) == 500)
	var invalid: Dictionary = Save.read_save(path).state
	invalid.quests.magic_shop.flags["58"] = 0
	assert(not jungle.apply_save(invalid).is_empty())
	assert(shop.state().conversation.cursor == 18 and mana(jungle) == 500)
	assert(jungle.quickload(path).is_empty())
	s = shop.state()
	assert(shop.active() and s.conversation.cursor == 17 and mana(jungle) == 1500 and not jungle.is_physics_processing())
	assert(shop.shown_cursor == 17 and shop.view.voice.playing)
	shop.advance(until(22)-until(17)-float(s.conversation.elapsed)+0.01)
	assert(mana(jungle) == 500 and s.timer_armed and not State.active(s) and not shop.back.disabled)
	assert(shop.view.clip.get("idle",false))
	# Source exit request (message8) sets flag55 on the way out.
	shop.leave_room()
	# The headless display server never reports a captured cursor.
	assert(not shop.active() and jungle.is_physics_processing() and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED))
	assert(shop.state().flags["55"] == 1)
	# Repeat visit: flag58 suppresses the introduction; the earned flag55 selects 440-441.
	shop._process(0.0)
	assert(not shop.active())
	jungle.player.position = Vector3(-1066,32,-5676)
	shop._process(0.0)
	assert(shop.active() and shop.state().conversation.sequence == "MAGIC_RETURN" and mana(jungle) == 500)
	await process_frame
	assert(shop.view.voice.playing)
	shop.advance(3.0)
	assert(not State.active(shop.state()))
	# The host deadline armed after the introduction is still running: expiry plays
	# 430-431, sets flag56 and ejects the player.
	shop.advance(State.TIMER_SECONDS)
	assert(shop.state().script.handler == "timer")
	shop.advance(20.0)
	assert(not shop.active() and shop.state().flags["56"] == 1 and mana(jungle) == 500)
	jungle.queue_free()
	await process_frame
	await process_frame
	print("PASS: Rashar region2636 entry, source line effects, once-only mana debit, save rollback, source exit flags, return greeting and timer ejection")
	quit()
