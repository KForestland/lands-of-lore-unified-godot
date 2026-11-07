extends SceneTree
const Controller=preload("res://scripts/lol2/cave_guard_encounter.gd")
const Body=preload("res://scripts/lol2/player_form_body.gd")
class Host extends Node3D:
	var native_translation:=Vector3.ZERO
	var player: CharacterBody3D
	var camera: Camera3D
	var inventory: Node
	var player_form:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var host:=Host.new();root.add_child(host)
	var floor_body:=StaticBody3D.new();floor_body.position=Vector3(0,-286,-16615);var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,2,1000);floor_shape.shape=box;floor_body.add_child(floor_shape);host.add_child(floor_body)
	host.player=CharacterBody3D.new();host.player.collision_layer=2;host.player.collision_mask=1;host.add_child(host.player);var collider:=CollisionShape3D.new();host.player.add_child(collider)
	host.camera=Camera3D.new();host.player.add_child(host.camera);host.camera.current=true;host.camera.cull_mask=2;assert(Body.apply(host.player,host.camera,0,false))
	host.player.global_position=Vector3(-9,-252,-16615)
	var controller:=Controller.new();host.add_child(controller);assert(controller.setup(host).is_empty())
	for i in range(30):
		await physics_frame;host.player.velocity=Vector3(0,-30,0);host.player.move_and_slide()
	assert(host.player.is_on_floor())
	host.inventory=Node.new();host.add_child(host.inventory)
	controller.advance(1.0/60,true,0)
	assert(controller.input_locked() and host.inventory==null and controller.applied_pending==2)
	assert(absf(host.player.global_position.x-44)<0.01 and absf(host.player.global_position.z+16667)<0.01)
	assert(controller.state.sequence.phase=="playing")
	await physics_frame;await physics_frame
	var packet:=controller.checkpoint();assert(controller.validate_packet(packet).is_empty())
	# The main save validator must reject malformed encounter packets before host mutation.
	var Save=preload("res://scripts/lol2/walkthrough_save.gd")
	assert(Save.validate({"guard_encounter":packet},0)=="This is not a restoration walkthrough save.")
	var rejected:=packet.duplicate(true);rejected.applied_pending=0
	assert(Save.validate({"guard_encounter":rejected},0)=="Guard host effects not committed.")
	controller.advance(2,false,0);assert(controller.checkpoint()==packet and controller.movie.voice.stream_paused)
	for i in range(2400):
		var previous_selector: int=controller.state.sequence.selector
		controller.advance(1.0/60,true,0)
		if controller.state.sequence.selector!=previous_selector:
			await physics_frame;await physics_frame
		if controller.state.sequence.phase=="complete":break
	assert(controller.state.sequence.phase=="complete" and not controller.input_locked())
	assert(controller.state.delayed.left==120)
	for i in range(60):controller.advance(1.0/60,true,0)
	packet=controller.checkpoint();assert(packet.encounter.delayed.left==60)
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file:=FileAccess.open("user://tests/cave_guard_runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(packet));file.close()
	for i in range(60):controller.advance(1.0/60,true,0)
	await physics_frame;await physics_frame
	assert(controller.state.delayed.fired and controller.delayed_voice.playing)
	assert(controller.restore(JSON.parse_string(FileAccess.get_file_as_string("user://tests/cave_guard_runtime.json"))).is_empty())
	assert(not controller.state.delayed.fired and not controller.delayed_voice.playing)
	var player_position: Vector3=host.player.global_position
	for i in range(60):controller.advance(1.0/60,true,0)
	assert(controller.state.groups.count(5050)==1 and host.player.global_position==player_position)
	await physics_frame;await physics_frame
	var bad:=controller.checkpoint();bad.applied_pending=0;var before:=controller.checkpoint();assert(not controller.restore(bad).is_empty());assert(controller.checkpoint()==before)
	print("PASS guard runtime controller: grounded plate->reposition/focus, six clips/control release, moving geometry, world pause, delayed voice, disk rollback/no replayed reposition, atomic invalid save. Synthetic floor; full Cave route/region navigation untested.")
	controller.movie.voice.stop();controller.delayed_voice.stop()
	await physics_frame;await physics_frame
	host.queue_free()
	await process_frame;await process_frame
	quit()
