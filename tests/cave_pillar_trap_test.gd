extends SceneTree
## Playtest 2026-10-17 report10:58:48 ("2 pillars that you can hit and bring down the stones on the guard pursuing
## you"). Production Cave, actual left click / Q / E from the colonnade; region entries by placing the player on the
## source region floors; guard38 is the source-spawned population actor moved into its source kind10 zones.
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL cave_pillar_trap: ", message); quit(1); return false
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/"+name+".png")
func key(code: Key) -> void:
	var e:=InputEventKey.new(); e.keycode=code; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	var r:=InputEventKey.new(); r.keycode=code; r.pressed=false
	Input.parse_input_event(r); Input.flush_buffered_events(); await process_frame
func click() -> void:
	if scene.get("roach")!=null: scene.roach.model.strike_remaining=0.0
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
## Owner report pose: map X/Y/H -> Godot X+4, H+430, Y+12794.
func pose(x: float, y: float, h: float, yaw: float, pitch: float) -> void:
	scene.player.global_position=Vector3(x+4,h+430,y+12794); scene.player.velocity=Vector3.ZERO
	scene.player.rotation=Vector3(0,yaw,0); scene.camera.rotation=Vector3(pitch,0,0)
	for i in 4: await physics_frame
## Stand on a source region floor and let the owner see the entry edge.
func enter(trap, x: float, y: float, floor_h: float) -> void:
	await pose(x,y,floor_h+40,0,0)
	for i in 30:
		await physics_frame
		if scene.player.is_on_floor(): break
	trap.advance(1.0/60.0)
func aim(trap) -> void:
	var target: Vector3=trap.body.global_position+Vector3(0,float(trap.source.pillar.height)*0.5,0)
	var d: Vector3=target-scene.camera.global_position
	scene.player.rotation.y=atan2(-d.x,-d.z)
	scene.camera.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
	for i in 2: await process_frame
func cooled() -> void:
	var m: Dictionary=scene.starting_magic.magic_state().duplicate(true); m.cooldown=0.0; m.player.mana=maxi(int(m.player.mana),20); scene.starting_magic.commit(m)
func guard_to(x: float, y: float, trap) -> void:
	var g: Dictionary=trap._guard()
	g.body.global_position=g.population.origin()+Vector3(x,-216,y)
	trap.advance(1.0/60.0)
func fighting_xp() -> int:
	return int(scene.quest_state.get("player_reward_state",{}).get("player",{}).get("experience",-1))
func fighting_level() -> int:
	return int(scene.quest_state.get("player_reward_state",{}).get("player",{}).get("level",-1))
func magic_player() -> Dictionary: return scene.starting_magic.magic_state().player
func blocked(trap) -> bool:
	var from: Vector3=scene.native_translation+Vector3(-476,-190,-11000)
	var to: Vector3=scene.native_translation+Vector3(-476,-190,-10850)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1,[scene.player.get_rid()]))
	return not hit.is_empty() and hit.collider==trap.rubble
func run() -> void:
	scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene=scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.curse.set_physics_process(false)
	var trap=scene.get("pillar_trap")
	if trap==null or trap.sprites.size()!=12: return fail("Pillar trap not hosted")
	trap.set_process(false)
	if scene.guard_population==null: return fail("No guard population")
	# Owner pose 10:58:48 (looking north up the colonnade): seven pillars drawn, prop878 intact, no rubble.
	await pose(-510.027,-11325.669,-182.962,-3.038,-0.137)
	trap.advance(1.0/60.0)
	if ["1213","1214","1215","1216","1217","1218","878"].any(func(id): return not trap.sprites[id].is_visible_in_tree()): return fail("Pillars not shown")
	if trap.rubble.visible or blocked(trap): return fail("Rubble present before collapse")
	await capture("owner_1058_48")
	var weapon=preload("res://scripts/lol2/cave_stalagmite.gd")
	scene.stalagmites.restore([weapon.item_id(641,1)])
	if not scene.set_equipped_item(weapon.item_id(641,1)): return fail("Weapon fixture")
	# Unarmed trap (local9 0): a landed hit changes nothing but durability.
	await enter(trap,-476,-11150,-220); await aim(trap); await click()
	if bool(trap.state.rubble) or bool(trap.state.local24) or int(trap.state.pillar.durability)>=2: return fail("Hit before region1929 armed: %s" % [trap.state])
	trap.restore(null)
	# Walk in from the north: 1947 disarms, 1929 arms; region1941 spawns guard38 at its source post.
	await enter(trap,-476,-10946,-220)
	if bool(trap.state.local9): return fail("Region1947 armed")
	await enter(trap,-476,-11017,-220)
	if not bool(trap.state.local9): return fail("Region1929 did not arm")
	await enter(trap,-476,-11144,-220)
	for i in 3: await physics_frame
	var g: Dictionary=trap._guard()
	if g.is_empty() or not bool(g.actor.present): return fail("Guard38 not spawned by region1941")
	# Pebble timer: region1787 starts prop151; a step drops one pebble prop and shakes prop878 (op7 one pass).
	await enter(trap,-650,-10270,-197)
	if not bool(trap.state.timer.enabled): return fail("Region1787 did not start the timer")
	var dropped:=false
	for i in range(16*60):
		trap.advance(1.0/60.0)
		if trap.plays.keys().any(func(id): return id in trap.source.stones): dropped=true; break
	if not dropped or not trap.plays.has("878"): return fail("No pebble fall within 16 s: %s" % [trap.plays])
	var pre:="user://tests/cave_pillar_pre.json"
	await enter(trap,-476,-11150,-220)
	await guard_to(-476,-10880,trap)
	if int(trap.state.local6)!=1: return fail("Guard38 in region1934 did not set local6=1")
	if not scene._quicksave(pre).is_empty(): return fail("Pre save failed")
	# Melee from the colonnade: collapse, rubble, stump, guard crushed, magic200+fighting200, first-solve level.
	var level0:=fighting_level(); var mxp0:=int(magic_player().experience)
	await aim(trap); await click()
	var s: Dictionary=trap.state
	if not bool(s.rubble) or int(s.pillar.selector)!=1 or not bool(s.local24) or bool(s.local31) or bool(s.timer.enabled): return fail("Melee collapse state: %s" % [s])
	if int(g.actor.health)!=0: return fail("Guard38 not crushed")
	if fighting_level()<=level0: return fail("No fighting level-up (first solve)")
	if int(magic_player().experience)==mxp0: return fail("No magic 200")
	if not trap.rubble.visible or not blocked(trap): return fail("Rubble does not block the corridor")
	trap.present(); await capture("collapsed_melee")
	await pose(-476,-11120,-188,3.1416,0.05); trap.present(); await capture("rubble_north")
	await enter(trap,-476,-11150,-220)
	# One-shot: further hits and region120 do nothing more.
	var xp1:=fighting_xp(); await aim(trap); await click()
	await enter(trap,-244,-11692,-215)
	if fighting_xp()!=xp1: return fail("Collapse re-ran")
	var post:="user://tests/cave_pillar_post.json"
	if not scene._quicksave(post).is_empty(): return fail("Post save failed")
	if not scene._quickload(pre).is_empty(): return fail("Pre load failed")
	for i in 3: await physics_frame
	if bool(trap.state.rubble) or trap.rubble.visible or blocked(trap): return fail("Pre load did not restore")
	if not scene._quickload(post).is_empty(): return fail("Post load failed")
	for i in 3: await physics_frame
	if not bool(trap.state.rubble) or not blocked(trap): return fail("Post load did not restore: %s" % [trap.state.rubble])
	# Spark with the guard south of the rubble (region1947, local6 2): collapse, no crush, Spark reward path.
	if not scene._quickload(pre).is_empty(): return fail("Reload pre")
	g=trap._guard()
	await guard_to(-476,-10946,trap)
	if int(trap.state.local6)!=2: return fail("Guard38 in region1947 did not set local6=2")
	scene.set_equipped_item(""); await enter(trap,-476,-11150,-220); await cooled(); await aim(trap); await key(KEY_Q)
	if not bool(trap.state.rubble) or not bool(trap.state.local31): return fail("Spark collapse: %s" % [trap.state])
	if int(g.actor.health)<=0: return fail("Guard38 crushed outside the zone")
	# Leaving south (region283, local24 0) collapses the corridor without a hit; no reward.
	if not scene._quickload(pre).is_empty(): return fail("Reload pre 2")
	g=trap._guard()
	await enter(trap,-559,-11629,-211)
	if not bool(trap.state.rubble) or not bool(trap.state.local24): return fail("Region283 did not collapse")
	# Same prop152 group (local6 1): crush and op2 sub0x0B/0x0C, but no prop150 hit reward (no first-solve level).
	if int(g.actor.health)!=0 or bool(trap.state.local31): return fail("Region283 local6=1 branch")
	# Legacy saves without the field start unarmed; malformed packets are refused.
	if not trap.restore(null).is_empty() or bool(trap.state.rubble): return fail("Legacy restore")
	var bad: Dictionary=trap.checkpoint(); bad.rubble=true
	if trap.restore(bad).is_empty(): return fail("Rubble without stump accepted")
	bad=trap.checkpoint(); bad.local6=3
	if trap.restore(bad).is_empty(): return fail("local6 3 accepted")
	bad=trap.checkpoint(); bad.timer.remaining=99.0
	if trap.restore(bad).is_empty(): return fail("Timer 99 s accepted")
	print("PASS cave_pillar_trap: 7 colonnade pillars + 5 pebble props hosted at the owner pose 10:58:48; hit refused until region1929 arms (1947 disarms); region1941 guard38; region1787 timer drops a pebble and shakes prop878; guard38 in region1934 -> local6 1; actual left click collapses: stump, rubble blocks the corridor, guard crushed, fighting level + magic 200 / fighting 200, timer stopped; one-shot; pre/post disk loads; Q Spark with guard in 1947 (local6 2) collapses without crush; region283 exit collapses without a hit; legacy/malformed packets")
	quit(0)
