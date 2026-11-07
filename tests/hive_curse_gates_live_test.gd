extends "res://tests/player_magic_handoff_test.gd"
const Monastery = preload("res://scripts/lol2/monastery_quest_state.gd")
var hive: Node3D
func place(region: int) -> void:
	var row: Dictionary
	for candidate in hive.hive_curse.regions:
		if int(candidate.region) == region: row = candidate
	assert(not row.is_empty())
	var center := Vector2.ZERO
	for p in row.polygon: center += Vector2(p[0],p[1])
	center /= row.polygon.size()
	hive.player.position = Vector3(center.x,(float(row.floor_min)+float(row.floor_max))*0.5+32.1,center.y)
	for frame in 5:
		await physics_frame
		hive.player.velocity = Vector3(0,-10,0)
		hive.player.move_and_slide()
	assert(hive.player.is_on_floor(),"Not grounded in region%d at%s" % [region,hive.player.position])
	assert(hive.hive_curse.region_at_player() == region,"Source polygon/floor binding failed")
func lizard() -> void:
	assert(hive.curse.request_timed_form(2,120))
	hive.curse.advance(hive.curse.WARNING_SECONDS)
	assert(hive.player_form == 2)
func run() -> void:
	hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	current_scene = hive
	await process_frame
	await physics_frame
	hive.set_development_mode(false)
	hive.set_physics_process(false)
	hive.curse.set_physics_process(false)
	hive.hive_curse.set_physics_process(false)
	hive.executioner_live.set_physics_process(false)
	hive.get_node("Warriors").set_process(false)
	hive.starting_magic.set_process(false)
	hive.monastery_checkpoint = Monastery.initial()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await place(812)
	hive.hive_curse.advance(0)
	assert(hive.hive_curse.checkpoint.enabled and hive.hive_curse.checkpoint.running)
	var timer: Dictionary = hive.hive_curse.checkpoint.duplicate(true)
	hive.hive_curse.advance(0)
	assert(hive.hive_curse.checkpoint == timer)
	lizard()
	await place(818)
	hive.hive_curse.advance(0)
	assert(not hive.hive_curse.checkpoint.enabled and not hive.hive_curse.checkpoint.running)
	assert(hive.hive_curse.checkpoint.human_return_used == [818])
	assert(hive.player_form == 2 and hive.curse.state.phase == 3)
	var path := "user://tests/hive_curse_gates.json"
	assert(hive.quicksave(path).is_empty())
	hive.curse.advance(0)
	assert(hive.player_form == 0)
	assert(hive.quickload(path).is_empty())
	hive.set_physics_process(false)
	assert(hive.player_form == 2 and hive.curse.state.phase == 3)
	assert(hive.hive_curse.checkpoint.human_return_used == [818])
	hive.curse.advance(0)
	assert(hive.player_form == 0)
	await place(812)
	hive.hive_curse.advance(0)
	lizard()
	await place(818)
	hive.hive_curse.advance(0)
	assert(hive.player_form == 2 and hive.curse.state.phase == 2,"Consumed command04 replayed")
	# Unconditional command04 consumers use the same admission and saved history.
	for region in [1259,1260,391]:
		hive.curse.set_requests_enabled(true) # Local command admission fixture, shared player owner.
		await place(region)
		hive.hive_curse.advance(0)
		assert(region in hive.hive_curse.checkpoint.human_return_used)
		assert(hive.curse.state.phase == 3)
		hive.curse.advance(0)
		assert(hive.player_form == 0)
		lizard()
	# The actual shared monastery flag disables both second-pair commands.
	hive.curse.request_human()
	hive.curse.advance(0)
	hive.monastery_checkpoint.globals.GV_RUNES_TRANSLATED = 1
	await place(812)
	hive.hive_curse.checkpoint.running = false
	hive.hive_curse.checkpoint.enabled = false
	hive.curse.set_requests_enabled(false)
	var seed: int = hive.hive_curse.checkpoint.seed
	hive.hive_curse.advance(0)
	assert(not hive.hive_curse.checkpoint.enabled and not hive.hive_curse.checkpoint.running and hive.hive_curse.checkpoint.seed == seed)
	var handoff: Dictionary = hive.area_handoff()
	var before: Dictionary = handoff.duplicate(true)
	var bad: Dictionary = handoff.duplicate(true)
	bad.quests.hive_curse.human_return_used = [818,818]
	assert(not hive.apply_area_handoff(bad).is_empty())
	assert(hive.area_handoff() == before,"Invalid return history changed live state")
	await finish(hive)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene = jungle
	await process_frame
	jungle.set_physics_process(false)
	assert(jungle.apply_area_handoff(handoff).is_empty())
	assert(jungle.quicksave(path).is_empty())
	assert(jungle.quickload(path).is_empty())
	assert(jungle.quest_state.hive_curse == handoff.quests.hive_curse)
	assert(jungle.quest_state.monastery.globals.GV_RUNES_TRANSLATED == 1)
	await finish(jungle)
	print("PASS Hive source gates812/818, command04 return/one-shot, pending-return rollback, four source consumers, translation gate and Jungle disk transport")
	quit()
