extends SceneTree
## Owner r12l F10 2026-10-28 15:36:05: a peaceful Kelsrick stood in the knife-out crouch (selector 0). Unwoken he shows
## the upright arms-crossed stand (selector 18, longplay 61:02); awake he keeps the fight-ready idle (selector 0).
const Kelsrick=preload("res://scripts/lol2/jungle_kelsrick.gd")
const Population=preload("res://scripts/lol2/scripted_creature_population.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host:=Node3D.new();var player:=CharacterBody3D.new()
	var script:=GDScript.new();script.source_code="extends Node3D\nvar player: CharacterBody3D\nvar camera: Camera3D\nvar quest_state:={}\n";script.reload()
	host.set_script(script);host.player=player;host.add_child(player);root.add_child(host)
	var camera:=Camera3D.new();camera.position=Vector3(-1713,40,-5409);host.add_child(camera);host.camera=camera
	var population:=Population.new();population.configure(Kelsrick.POP_CONFIG);host.add_child(population)
	var error:=population.setup(host)
	check(error.is_empty(),"setup: "+error)
	if error.is_empty():
		var lib=population.library
		var calm: Dictionary=population.src.definitions["7"].clips.get("peaceful",{})
		check(int(calm.get("selector",-1))==18 and int(calm.get("frames",0))==lib.frame_count(7,18),"Kelsrick has a peaceful clip on selector 18")
		check(not population.state.actors["64"].woken,"Kelsrick starts unwoken")
		population.present()
		check(lib.last_texture==lib.textures[2965][0] or lib.last_texture==lib.textures[2965][1],"peaceful Kelsrick shows the arms-crossed stand (resource 2965), not the knife crouch")
		Generic.wake(population.state,"64")
		population.state.actors["64"].rise=999.0
		population.present()
		check(lib.last_texture==lib.textures[2296][0] or lib.last_texture==lib.textures[2296][1],"awake idle Kelsrick keeps the knife-ready stand (resource 2296)")
	host.queue_free()
	if failures:
		push_error("FAIL: %d Kelsrick pose checks" % failures);quit(1);return
	print("PASS Kelsrick peaceful pose: unwoken selector 18 stand, awake selector 0")
	quit()
