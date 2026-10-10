extends SceneTree
const LATE_ROUTE := [Vector2(1000,-11800),Vector2(1010,-12000),Vector2(1100,-11970),Vector2(1190,-12200),Vector2(1270,-12270),Vector2(1240,-12420),Vector2(1100,-12490),Vector2(890,-12640),Vector2(720,-12840),Vector2(898.500,-13082.500),Vector2(950.750,-13152.500),Vector2(988.250,-13247.000),Vector2(998.979,-13340.128),Vector2(996.729,-13460.628),Vector2(989.250,-13614.500),Vector2(959.750,-13732.250),Vector2(919.000,-13811.250),Vector2(878.250,-13869.250),Vector2(824.500,-13926.750),Vector2(748.750,-13986.250),Vector2(661.500,-14037.500),Vector2(564.000,-14082.000),Vector2(454.250,-14133.000),Vector2(334.250,-14175.500),Vector2(208.500,-14195.500),Vector2(89.500,-14200.750),Vector2(-7.250,-14194.500),Vector2(-77.500,-14191.750),Vector2(-168.888,-14197.641),Vector2(10,-14400),Vector2(-70,-14600),Vector2(-200,-14700),Vector2(-70,-14840),Vector2(-20,-15050),Vector2(15,-15380),Vector2(-150,-15500),Vector2(-360,-15580),Vector2(-340,-15800),Vector2(-130,-15980),Vector2(220,-16100),Vector2(400,-16270),Vector2(520,-16400),Vector2(200,-16430),Vector2(0,-16485),Vector2(-65,-16550),Vector2(-65,-16790)]
var aloe_route := "--aloe-use" in OS.get_cmdline_user_args()
var aloe_evidence: Dictionary = {}
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var spell_evidence: Dictionary = {}
func spell_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if aloe_route:
		for required in ["--starting-spells","--middle-route","--bridge-route","--through-museum"]:
			assert(required in OS.get_cmdline_user_args(),"Aloe earned profile requires " + required)
	if "--route-fast" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
		Engine.physics_ticks_per_second = 240
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready and cave.checkpoint == 120)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if "--late-fixture" in OS.get_cmdline_user_args():
		# Bounded local traversal probe; full acceptance still starts at the entrance.
		cave.player.global_position = Vector3(1146.314,-182.9592,-11559.69)+cave.native_translation
		cave.player.velocity = Vector3.ZERO
		for frame in range(20):
			cave.camera.look_at(cave.indexed_chain.mesh.global_position)
			await physics_frame
		var strike := InputEventKey.new()
		strike.keycode = KEY_E
		strike.pressed = true
		cave._unhandled_input(strike)
		for frame in range(360): await physics_frame
		for door in cave.indexed_doors: assert(door.opening_percent == 100)
		var passed := await walk_stops(cave,LATE_ROUTE)
		print("Late fixture passed=",passed)
		cave.free()
		quit(0 if passed else 1)
		return
	for i in range(20): await physics_frame
	if aloe_route:
		var plant: MeshInstance3D = cave.aloe.plants[791]
		var aloe_target: Vector3 = plant.to_global(plant.mesh.center_offset)
		var walk := InputEventKey.new()
		walk.keycode = KEY_W
		walk.physical_keycode = KEY_W
		walk.pressed = true
		Input.parse_input_event(walk.duplicate())
		for tick in 1800:
			cave.player.look_at(Vector3(aloe_target.x,cave.player.global_position.y,aloe_target.z))
			cave.camera.look_at(aloe_target)
			await physics_frame
			if cave.aloe.target() == 791: break
		walk.pressed = false
		Input.parse_input_event(walk.duplicate())
		assert(cave.aloe.target() == 791 and cave.resets == 0,"Normal entrance walk could not reach Aloe")
		spell_key(KEY_E)
		await physics_frame
		await physics_frame
		assert("cave:prop791:harvest1:Cave_Aloe" in cave.carried_items())
	var mesh: MeshInstance3D = cave.stalagmites.plants[641]
	var target: Vector3 = mesh.to_global(mesh.mesh.center_offset)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	for i in range(900):
		cave.player.look_at(Vector3(target.x,cave.player.global_position.y,target.z))
		cave.camera.look_at(target)
		await physics_frame
		if cave.stalagmites.target() == 641: break
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	print("Entrance walk native=",cave.player.global_position-cave.native_translation," target=",cave.stalagmites.target()," resets=",cave.resets)
	assert(cave.stalagmites.target() == 641 and cave.resets == 0,"Source entrance must reach first weapon without repositioning")
	var take := InputEventKey.new()
	take.keycode = KEY_E
	take.pressed = true
	cave._unhandled_input(take)
	await physics_frame
	await physics_frame
	assert(cave.stalagmites.collected == ["cave:prop641:harvest1:Stalagmite"])
	assert(cave.set_equipped_item(cave.stalagmites.collected[0]))
	if "--captain-route" in OS.get_cmdline_user_args():
		var captain_helper=preload("res://tests/helpers/captain_route_helper.gd").new()
		if not await captain_helper.run(cave):
			cave.free();quit(1);return
		spell_evidence.captain={"grants":cave.captain.state.source.granted.duplicate(),"region":cave.captain.state.region}
	# Continue from the actual pickup position toward the original creature.
	var corridor := [Vector3(-1500,0,-4690),Vector3(-2070,0,-4610),Vector3(-2260,0,-4810),Vector3(-2220,0,-5200),Vector3(-2170,0,-5450)]
	var waypoint := 0
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	var reached := false
	for i in range(4800):
		var enemy: Vector3 = cave.roach.body.global_position+Vector3.UP*6
		var destination: Vector3 = corridor[waypoint]+cave.native_translation if waypoint<corridor.size() else enemy
		var separation := Vector2(destination.x-cave.player.global_position.x,destination.z-cave.player.global_position.z)
		if separation.length()<30 and waypoint<corridor.size(): waypoint += 1
		cave.player.look_at(Vector3(destination.x,cave.player.global_position.y,destination.z))
		cave.camera.rotation = Vector3.ZERO
		if cave.camera.global_position.distance_to(enemy) < 90:
			key.pressed = false
			cave.camera.look_at(enemy)
			Input.parse_input_event(key.duplicate())
			if spell_route and not spell_evidence.has("healing"):
				# Let the live creature land a hit; never inject injury or mana.
				if cave.roach.model.player_health<30:
					var before_health: int=cave.roach.model.player_health
					var before_mana: int=cave.player_magic_checkpoint.player.mana
					spell_key(KEY_2)
					spell_key(KEY_Q)
					if cave.roach.model.player_health>before_health:
						spell_evidence.healing={"health_before":before_health,"health_after":cave.roach.model.player_health,"mana_before":before_mana,"mana_after":cave.player_magic_checkpoint.player.mana}
			elif spell_route and not spell_evidence.has("spark"):
				var before_enemy: int=cave.roach.model.enemy_health
				var before_mana: int=cave.player_magic_checkpoint.player.mana
				spell_key(KEY_1)
				spell_key(KEY_Q)
				if cave.roach.model.enemy_health<before_enemy:
					spell_evidence.spark={"enemy_before":before_enemy,"enemy_after":cave.roach.model.enemy_health,"mana_before":before_mana,"mana_after":cave.player_magic_checkpoint.player.mana}
			elif aloe_route and aloe_evidence.is_empty():
				if cave.roach.model.player_health < 30:
					var before_health: int = cave.roach.model.player_health
					var before_mana: int = cave.player_magic_checkpoint.player.mana
					spell_key(KEY_I)
					await process_frame
					assert(is_instance_valid(cave.inventory))
					cave.inventory.select_item(cave.carried_items().find("cave:prop791:harvest1:Cave_Aloe"))
					cave.inventory.use_button.pressed.emit()
					await process_frame
					await process_frame
					for tick in 120:
						await physics_frame
						if cave.item_effect_checkpoint.aloe.pending == 0: break
					assert(cave.roach.model.player_health > before_health and "cave:prop791:harvest1:Cave_Aloe" not in cave.carried_items())
					aloe_evidence = {"health_before":before_health,"health_after":cave.roach.model.player_health,"mana_before":before_mana,"mana_after":cave.player_magic_checkpoint.player.mana,"spent":cave.item_effect_checkpoint.spent.duplicate()}
			else:
				var strike := InputEventMouseButton.new()
				strike.button_index = MOUSE_BUTTON_LEFT
				strike.pressed = true
				cave._unhandled_input(strike)
		await physics_frame
		if i % 240 == 0: print("Opening route tick=",i," native=",cave.player.global_position-cave.native_translation," enemy=",cave.roach.model.enemy_health," health=",cave.roach.model.player_health)
		if cave.roach.model.enemy_health == 0:
			reached = true
			break
		if cave.resets > 0 or cave.roach.model.player_health == 0: break
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	print("Opening route reached=",reached," native=",cave.player.global_position-cave.native_translation)
	assert(reached and cave.resets == 0,"Entrance, weapon pickup and first creature must connect through ordinary movement")
	if aloe_route: assert(not aloe_evidence.is_empty())
	if spell_route:
		assert(spell_evidence.has("healing") and spell_evidence.has("spark"),"Both starting spells must be earned-route actions")
		print("PASS earned starting spells: ",spell_evidence)
	if "--middle-route" in OS.get_cmdline_user_args():
		var sprint := InputEventKey.new()
		sprint.keycode = KEY_SHIFT
		sprint.physical_keycode = KEY_SHIFT
		sprint.pressed = true
		Input.parse_input_event(sprint)
		var onward := [Vector2(-1550,-5800),Vector2(-1270,-5910),Vector2(-1260,-6160),Vector2(-1150,-6500),Vector2(-1000,-6780),Vector2(-650,-6830),Vector2(-260,-7150),Vector2(-190,-7500),Vector2(60,-7720),Vector2(80,-7900),Vector2(-200,-7910),Vector2(-410,-7740),Vector2(-700,-7830),Vector2(-790,-8170),Vector2(-810,-8500),Vector2(-760,-8820),Vector2(-650,-9230),Vector2(-570,-9620),Vector2(-650,-10080),Vector2(-640,-10250),Vector2(-460,-10410),Vector2(-480,-11000),Vector2(-470,-11300),Vector2(-430,-11520),Vector2(-180,-11750),Vector2(0,-11950),Vector2(260,-11850),Vector2(350,-11590),Vector2(520,-11580),Vector2(790,-11700),Vector2(950,-11570),Vector2(1150,-11570)]
		key.pressed = true
		Input.parse_input_event(key.duplicate())
		for stop in onward:
			var arrived := false
			var last: Vector3 = cave.player.global_position
			var stalled := 0
			for frame in range(1200):
				await fight_population(cave)
				await fight_guards(cave)
				if not Input.is_physical_key_pressed(KEY_W): Input.parse_input_event(key)
				var destination: Vector3 = Vector3(stop.x,cave.player.global_position.y-cave.native_translation.y,stop.y)+cave.native_translation
				cave.player.look_at(destination)
				cave.camera.rotation = Vector3.ZERO
				await physics_frame
				var position: Vector3 = cave.player.global_position-cave.native_translation
				if Vector2(position.x,position.z).distance_to(stop)<25:
					arrived = true
					break
				stalled = stalled+1 if cave.player.global_position.distance_to(last)<0.01 else 0
				last = cave.player.global_position
				if stalled == 30 and stop in [Vector2(-570,-9620),Vector2(-470,-11300)]:
					var jump := InputEventKey.new()
					jump.keycode = KEY_SPACE
					jump.physical_keycode = KEY_SPACE
					jump.pressed = true
					Input.parse_input_event(jump)
					jump = jump.duplicate()
					jump.pressed = false
					Input.parse_input_event(jump)
				if stalled>120 or cave.resets>0 or cave.roach.model.player_health<=0: break
			print("Middle route stop=",stop," arrived=",arrived," native=",cave.player.global_position-cave.native_translation)
			if not arrived:
				for index in range(cave.player.get_slide_collision_count()):
					var hit = cave.player.get_slide_collision(index)
					print("Blocked contact=",hit.get_position()-cave.native_translation," normal=",hit.get_normal())
				key.pressed = false
				Input.parse_input_event(key.duplicate())
				cave.free()
				quit(1)
				return
		key.pressed = false
		Input.parse_input_event(key.duplicate())
		print("PASS continuous entrance-to-chain approach movement")
		key.pressed = true
		Input.parse_input_event(key.duplicate())
		for frame in range(240):
			var chain: Vector3 = cave.indexed_chain.mesh.global_position
			cave.player.look_at(Vector3(chain.x,cave.player.global_position.y,chain.z))
			cave.camera.look_at(chain)
			await physics_frame
			if cave.indexed_chain.can_strike(): break
		key.pressed = false
		Input.parse_input_event(key.duplicate())
		assert(cave.indexed_chain.can_strike(),"Reach chain from the continuous route")
		take = take.duplicate()
		cave._unhandled_input(take)
		for frame in range(360): await physics_frame
		assert(cave.indexed_chain.state.started)
		for door in cave.indexed_doors: assert(door.opening_percent == 100)
		print("PASS continuous entrance-to-chain interaction and both doors open native=",cave.player.global_position-cave.native_translation)
		var path := "user://tests/continuous_chain_route.json"
		assert(cave._quicksave(path).is_empty())
		var expected: Dictionary = cave._save_state()
		var reload_error: String = cave._quickload(path)
		var reloaded: Dictionary = cave._save_state()
		if reloaded != expected:
			for k in expected:
				if reloaded.get(k) != expected[k]: print("Reload differs ",k)
			for pair in [["expected",expected],["reloaded",reloaded]]:
				var dump := FileAccess.open("user://tests/route_reload_%s.json" % pair[0],FileAccess.WRITE)
				dump.store_string(var_to_str(pair[1]));dump.close()
		assert(reload_error.is_empty() and reloaded == expected)
		DirAccess.remove_absolute(path)
		if "--bridge-route" in OS.get_cmdline_user_args():

			if not await walk_stops(cave,LATE_ROUTE):
				cave.free()
				quit(1)
				return
			print("PASS continuous entrance-to-river approach, form=",cave.player_form," curse=",cave.curse.snapshot())
			if "--through-museum" in OS.get_cmdline_user_args():
				if not await finish_cave(cave):
					quit(1)
					return
				quit()
				return
	cave.free()
	print("PASS source entrance-to-first-creature: normal movement, actual pickup and mouse combat, no repositioning/checkpoint jumps or supplied equipment")
	quit()

## Source population Roaches now pursue and bite. Fight any that engage nearby
## through the production mouse strike; never inject damage, health or position.
var population_kills: Array = []
func fight_population(cave: Node) -> void:
	var live = cave.roach_population_live
	if live == null: return
	for round in range(2400):
		var target := ""
		var closest := 90.0
		for id in live.bodies:
			if cave.roach_population.actors[id].health<=0: continue
			var d: float = live.bodies[id].global_position.distance_to(cave.player.global_position)
			# Engaged actors, or any living body close enough to block the path.
			if cave.roach_population.live[id].mode==0 and d>=45: continue
			if d<closest: closest=d;target=id
		if target.is_empty() or cave.roach.model.player_health<=0: return
		var held := InputEventKey.new()
		held.keycode = KEY_W;held.physical_keycode = KEY_W;held.pressed = false
		Input.parse_input_event(held)
		var point: Vector3 = live.bodies[target].global_position+Vector3(0,6,0)
		cave.player.look_at(Vector3(point.x,cave.player.global_position.y,point.z))
		cave.camera.look_at(point)
		if cave.roach.model.strike_remaining<=0:
			var strike := InputEventMouseButton.new()
			strike.button_index = MOUSE_BUTTON_LEFT
			strike.pressed = true
			cave._unhandled_input(strike)
		await physics_frame
		if cave.roach_population.actors[target].health<=0:
			population_kills.append({"actor":int(target),"health":cave.roach.model.player_health})
			print("Population Roach",target," defeated; player health=",cave.roach.model.player_health)
	cave.camera.rotation = Vector3.ZERO

## Source guards spawn/wake from cave regions; engage active or adjacent ones through
## the production strike input; heal with spell keys when low. No injection.
func fight_guards(cave: Node) -> void:
	for property in ["guard_population","wild_roach_population"]:
		await fight_scripted_population(cave,cave.get(property))

func fight_scripted_population(cave: Node, pop) -> void:
	if pop == null: return
	const Live = preload("res://scripts/lol2/creature_live_rules.gd")
	for round in range(3600):
		var target := ""
		var closest := 110.0
		for id in pop.bodies:
			var a: Dictionary = pop.state.actors[id]
			if a.health <= 0 or not a.present: continue
			var d: float = pop.bodies[id].global_position.distance_to(cave.player.global_position)
			var active: bool = pop.state.live[id].mode != Live.IDLE or (a.woken and d < 70)
			if (active or d < 45) and d < closest: closest = d;target = id
		if target.is_empty() or cave.roach.model.player_health <= 0: return
		if cave.roach.model.player_health <= 12 and cave.player_magic_checkpoint.player.mana >= 2:
			spell_key(KEY_2);spell_key(KEY_Q)
		var held := InputEventKey.new();held.keycode = KEY_W;held.physical_keycode = KEY_W;held.pressed = false
		Input.parse_input_event(held)
		var point: Vector3 = pop.targets()[str(pop.config.get("target_prefix","creature"))+target].point
		cave.player.look_at(Vector3(point.x,cave.player.global_position.y,point.z))
		cave.camera.look_at(point)
		# Lizard natural melee is only1; use the earned starting Spark instead
		# of standing in a long exchange and spending all mana on Healing.
		if cave.player_form==2 and cave.roach.model.player_health>12 and cave.player_magic_checkpoint.player.mana>=1 and pop.aimed()==target:
			spell_key(KEY_1);spell_key(KEY_Q)
		if pop.strike_remaining <= 0 and pop.aimed() == target:
			var strike := InputEventMouseButton.new();strike.button_index = MOUSE_BUTTON_LEFT;strike.pressed = true
			pop._unhandled_input(strike)
		elif closest > 60:
			var press := InputEventKey.new();press.keycode = KEY_W;press.physical_keycode = KEY_W;press.pressed = true
			Input.parse_input_event(press)
		await physics_frame
		if round%240==239:
			print("Combat ",pop.name_of(target),target," enemy=",pop.state.actors[target].health," player=",cave.roach.model.player_health," mana=",cave.player_magic_checkpoint.player.mana," form=",cave.player_form," aimed=",pop.aimed())
		if pop.state.actors[target].health <= 0: print(pop.name_of(target)," ",target," defeated; player health=",cave.roach.model.player_health)
	cave.camera.rotation = Vector3.ZERO

func walk_stops(cave: Node, stops: Array) -> bool:
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	var previous_stop: Vector2 = Vector2.INF
	for stop in stops:
		var arrived := false
		var last: Vector3 = cave.player.global_position
		var stalled := 0
		var form_waits := 0
		var ledge_jumps := 0
		var frame := 0
		while frame < 1800:
			frame += 1
			await fight_population(cave)
			await fight_guards(cave)
			if not Input.is_physical_key_pressed(KEY_W): Input.parse_input_event(key)
			var destination: Vector3 = Vector3(stop.x,cave.player.global_position.y-cave.native_translation.y,stop.y)+cave.native_translation
			cave.player.look_at(destination)
			cave.camera.rotation = Vector3.ZERO
			await physics_frame
			var p: Vector3 = cave.player.global_position-cave.native_translation
			if Vector2(p.x,p.z).distance_to(stop)<(10.0 if stop.y < -13000 and stop.y > -14250 else 25.0):
				arrived = true
				break
			stalled = stalled+1 if cave.player.global_position.distance_to(last)<0.01 else 0
			last = cave.player.global_position
			if stalled>60 and ledge_jumps<3 and cave.curse.snapshot().phase == 0:
				# No pending shape change explains the stall (e.g. a human at a low sloped ledge): jump, like a player.
				ledge_jumps += 1
				var hop := InputEventKey.new();hop.keycode = KEY_SPACE;hop.physical_keycode = KEY_SPACE;hop.pressed = true
				Input.parse_input_event(hop)
				hop = hop.duplicate();hop.pressed = false
				Input.parse_input_event(hop)
				print("Ledge jump ",ledge_jumps," at stop=",stop," native=",cave.player.global_position-cave.native_translation," form=",cave.player_form)
				stalled = 0
				continue
			if stalled>120 and form_waits<3 and cave.curse.snapshot().phase in [1,2]:
				# Timed curse shape does not fit here: wait in place for the next
				# natural shape change, as a player would. No form injection.
				form_waits += 1
				var waiting_form: int = cave.player_form
				print("Curse wait start curse=",cave.curse.snapshot()," active=",cave.curse.active()," mouse=",Input.mouse_mode)
				var held := key.duplicate();held.pressed = false
				Input.parse_input_event(held)
				var cramped := 0
				for wait in range(60000):
					await physics_frame
					if cave.player_form != waiting_form: break
					# Curse ended but this spot is too low to stand up ("You need room to change back"): like a
					# player, walk back toward the previous stop until the natural change back succeeds.
					cramped = cramped+1 if cave.curse.snapshot().phase == 3 else 0
					if cramped > 120 and previous_stop != Vector2.INF:
						var back: Vector3 = Vector3(previous_stop.x,cave.player.global_position.y-cave.native_translation.y,previous_stop.y)+cave.native_translation
						cave.player.look_at(back)
						cave.camera.rotation = Vector3.ZERO
						if not Input.is_physical_key_pressed(KEY_W): Input.parse_input_event(key)
					elif Input.is_physical_key_pressed(KEY_W): Input.parse_input_event(held)
				print("Curse wait at stop=",stop," form ",waiting_form,"->",cave.player_form," curse=",cave.curse.snapshot()," active=",cave.curse.active()," mouse=",Input.mouse_mode)
				Input.parse_input_event(key)
				stalled = 0
				frame = 0
				continue
			if stalled>120 or cave.resets>0 or cave.roach.model.player_health<=0: break
		previous_stop = stop
		print("Late route stop=",stop," arrived=",arrived," native=",cave.player.global_position-cave.native_translation," form=",cave.player_form)
		if not arrived:
			for index in range(cave.player.get_slide_collision_count()):
				var hit = cave.player.get_slide_collision(index)
				print("Blocked contact=",hit.get_position()-cave.native_translation," normal=",hit.get_normal()," collider=",hit.get_collider().name if hit.get_collider() else "?")
			if cave.roach_population_live != null:
				for id in cave.roach_population_live.bodies:
					var d: float = cave.roach_population_live.bodies[id].global_position.distance_to(cave.player.global_position)
					if d < 150: print("Nearby Roach",id," d=",d," health=",cave.roach_population.actors[id].health," live=",cave.roach_population.live[id])
			print("Curse at stall=",cave.curse.snapshot()," active=",cave.curse.active()," health=",cave.roach.model.player_health)
			if cave.guard_population != null:
				for id in cave.guard_population.bodies:
					var gd: float = cave.guard_population.bodies[id].global_position.distance_to(cave.player.global_position)
					if gd < 200: print("Nearby Guard",id," d=",gd," actor=",cave.guard_population.state.actors[id]," live=",cave.guard_population.state.live[id])
			key = key.duplicate()
			key.pressed = false
			Input.parse_input_event(key)
			return false
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	return true

func finish_cave(cave: Node) -> bool:
	# Cross the first sections, cut one support, then retreat onto the onward
	# intact deck before cutting its second support. No pursuit is invented.
	if not await walk_stops(cave,[Vector2(-65,-17050)]): return false
	for id in [93,95]:
		if id == 95 and not await walk_stops(cave,[Vector2(-65,-17200)]): return false
		for frame in range(3):
			cave.camera.look_at(cave.river_chains.chains[id].target)
			await physics_frame
		if cave.river_chains.target_chain() != id:
			push_error("Walked bridge support is not in reach: " + str(id))
			return false
		var strike := InputEventKey.new()
		strike.keycode = KEY_E
		strike.pressed = true
		cave._unhandled_input(strike)
		await physics_frame
		await physics_frame
		if not cave.river_deck.chain_rule.cut.has(id): return false
	if cave.river_deck.sections[58].body.collision_layer != 0: return false
	var inventory: Dictionary = cave._completion_state().duplicate(true)
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	for frame in range(2400):
		cave.player.rotation = Vector3.ZERO
		cave.camera.rotation = Vector3.ZERO
		await physics_frame
		if cave.chamber_arrival_state == "playing": break
		if cave.resets > 0 or cave.drowning.dead: break
	forward = forward.duplicate()
	forward.pressed = false
	Input.parse_input_event(forward)
	if cave.chamber_arrival_state != "playing" or cave.resets != 0:
		push_error("Continuous bridge crossing failed at " + str(cave.player.global_position-cave.native_translation))
		return false
	print("PASS earned bridge cuts, safe onward crossing and automatic chamber story")
	# Let the original story and destination introduction finish naturally.
	for frame in range(30000):
		await process_frame
		if not is_instance_valid(cave): break
	if is_instance_valid(cave):
		push_error("Chamber story did not finish")
		return false
	var museum = current_scene
	if museum.scene_file_path != "res://scenes/lol2/museum_walkthrough.tscn": return false
	for frame in range(30000):
		await process_frame
		if museum.introduction_state == "complete" and not paused: break
	if museum.introduction_state != "complete": return false
	for frame in range(60): await physics_frame
	if not museum.player.is_on_floor() or museum.resets != 0: return false
	for id in inventory.collected:
		if id not in museum.carried_collected: return false
	if museum.equipped_item != inventory.equipped_item: return false
	var output_path := "user://tests/act1_aloe_museum_arrival.json" if aloe_route else "user://tests/act1_magic_museum_arrival.json" if spell_route else "user://tests/act1_earned_museum_arrival.json"
	if not museum.quicksave(output_path).is_empty(): return false
	if spell_route:
		var report := {"passed":true,"spells":spell_evidence,"output_save":output_path,"output_sha256":FileAccess.get_sha256(output_path),"magic":museum.player_magic_checkpoint,"scope":"Original cave entrance, earned Stalagmite, actual ROACH injury, keyboard Healing and Spark, melee finish, doors/curse/bridge/story through real Museum arrival. No health, mana, inventory, position or form injection after source spawn. Automated steering and4x clock; combat/spell tuning remains provisional."}
		if "--captain-route" in OS.get_cmdline_user_args():
			report.scope += " Includes earned captain introduction, walked lure, aimed Spark surrender and both rewards carried to Museum."
		if aloe_route:
			report["aloe"] = aloe_evidence
			assert(museum.item_effect_checkpoint.spent == aloe_evidence.spent)
			report.scope += " Includes walked Aloe harvest and inventory use after real ROACH injury, consumed history carried into Museum."
		var file := FileAccess.open("res://docs/cave-aloe-earned-walk-checks.json" if aloe_route else "res://docs/cave-starting-spells-walk-checks.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
	print("PASS continuous source cave entrance→weapon/ROACH→chain doors→curse→bridge cuts→chamber story→Museum introduction and grounded saved arrival")
	museum.queue_free()
	await process_frame
	return true
