extends SceneTree
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	scene.player.position=Vector3.ZERO # Isolated idle fixture, outside herd perception.
	var dinos=scene.dino_population;dinos.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var magic:=TestMagic.new();scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
	var before: Dictionary=scene.quest_state.duplicate(true)
	var sprite=dinos.sprites["21"]
	var initial_texture=sprite._material.get_shader_parameter("indices")
	for i in range(8): dinos.advance(1.0/16)
	assert(dinos.view().live["21"].mode==dinos.Live.IDLE and dinos.clocks["21"]==0.5)
	assert(scene.quest_state==before) # Animation alone must not initialize quest progress.
	assert(sprite._material.get_shader_parameter("indices")!=initial_texture)
	magic.running=false;dinos.advance(1.0)
	assert(dinos.clocks["21"]==0.5)
	magic.running=true
	for i in range(16): dinos.advance(1.0/16)
	assert(sprite._material.get_shader_parameter("indices")==initial_texture)
	# Once a population exists, the shared audio/pose cursor persists idle phase.
	dinos.state()
	for i in range(12): dinos.advance(1.0/16)
	var saved: Dictionary=scene.quest_state.jungle_dino_population.duplicate(true)
	var texture=sprite._material.get_shader_parameter("indices")
	dinos.advance(0.25)
	scene.quest_state.jungle_dino_population=dinos.State.canonical(JSON.parse_string(JSON.stringify(saved)))
	dinos.restore()
	assert(dinos.clocks["21"]==saved.audio["21"].time)
	assert(sprite._material.get_shader_parameter("indices")==texture)
	scene.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: original idle frames loop, pause, legacy quest non-mutation and exact phase/texture restore")
	quit()
