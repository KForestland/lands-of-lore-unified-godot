extends SceneTree
const Nav=preload("res://scripts/lol2/creature_navigation.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var nav:=Nav.new()
	if not check(nav.load_graph("res://assets/lol2/generated/creature_nav/L1_DC.json").is_empty(),"Nav graph load failed"):return
	var a:=nav.region_at(Vector3(-1051,0,-5871));var b:=nav.region_at(Vector3(-1206.65,0,-6324.9))
	if not check(a>=0 and b>=0 and a!=b,"Region lookup failed %d %d"%[a,b]):return
	var p=nav.next_point(Vector3(-1051,0,-5871),Vector3(-1206.65,0,-6324.9))
	if not check(p is Vector2,"No portal route from guard39 room to region775"):return
	# Navigation fixture: explicitly spawned/woken guard39 reaches the player without LOS.
	# Region775 only writes control109 state1; encounter admission is tested separately.
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave);current_scene=cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false)
	var spells:=TestMagic.new();cave.add_child(spells);spells.set_process(false);cave.starting_magic=spells
	var pop=cave.guard_population;pop.set_physics_process(false)
	pop.State.spawn(pop.state,"39");pop.State.wake(pop.state,"39")
	if not check(pop.navigation!=null,"Guard navigation not configured"):return
	var t: Vector3=cave.native_translation
	cave.player.global_position=Vector3(-1206.65,32,-6324.9)+t
	cave.player.velocity=Vector3.DOWN*10;cave.player.move_and_slide()
	await physics_frame
	var start: Vector3=pop.bodies["39"].global_position
	var closest:=INF
	for i in range(60*20):
		pop.advance(1.0/60.0)
		await physics_frame
		closest=minf(closest,pop.bodies["39"].global_position.distance_to(cave.player.global_position))
		if cave.roach.model.player_health<30: break
	if not check(pop.state.actors["39"].present and closest<80,"Guard39 never reached the player (closest %.1f)"%closest):return
	print("PASS: L1_DC region-portal graph; guard39 spawned in its side room navigates to the player in region775 (closest %.1f, health %d)"%[closest,cave.roach.model.player_health])
	cave.queue_free();await process_frame;quit()
