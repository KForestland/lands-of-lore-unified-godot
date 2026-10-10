extends SceneTree
## Supplied location/story fixture; real host, camera visibility, combat and save transport.
const State=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Aura=preload("res://scripts/lol2/player_spark_aura_state.gd")
var scene
var ctrl
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func point_camera() -> void:
	var p: Vector3=Vector3(3592,-15,-4145)+ctrl.population.origin()
	scene.player.global_position=p+Vector3(0,32,80)
	scene.player.rotation=Vector3.ZERO
	scene.camera.look_at(p+Vector3.UP*40,Vector3.UP)
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	ctrl=scene.exit_encounter;ctrl.set_physics_process(false)
	for pop in [scene.dino_population,scene.villager_population]: pop.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	point_camera()
	await physics_frame
	ctrl._visible_spawn()
	if not check(not ctrl.visibility.seen and ctrl.targets().is_empty(),"Pre-story visibility spawned guards or latched a rejected predicate"):return
	# Real named story banks, not a supplied context Callable.
	scene.quest_state.monastery.globals.GV_RUNES_TRANSLATED=1
	scene.quest_state.monastery.globals.GV_MET_BACATTA=1
	if not check(scene._exit_context().shared["14"]==1 and scene._exit_context().shared["18"]==1,"Named source flags not mapped"):return
	# Region1921 presence is supplied until the Bacatta component owns its production admission.
	if not check(not ctrl.visibility.present,"Prop552 incorrectly source-present"):return
	ctrl.set_prop_present(true)
	# Looking away cannot activate the prop.
	scene.player.rotation.y=PI
	ctrl._visible_spawn()
	if not check(not ctrl.visibility.seen,"Offscreen prop admitted visibility"):return
	point_camera()
	ctrl._visible_spawn()
	if not check(ctrl.visibility.seen and ctrl.targets().size()==3,"Visible source prop did not spawn guards"):return
	var groups: int=ctrl.effect_log.filter(func(e):return e.type=="group" and e.group==10720).size()
	ctrl._visible_spawn()
	if not check(ctrl.effect_log.filter(func(e):return e.type=="group" and e.group==10720).size()==groups,"Visibility spawned twice"):return
	if not check(scene.starting_magic.aura.targets().has("jungleexitguard60") and Aura.valid_target("jungleexitguard60") and not Aura.valid_target("jungleexitguard61"),"Production spell target transport missing"):return
	# Immediate save after real melee must first mirror health and source events atomically.
	if not check(ctrl.population.receive_damage("60",8),"Production guard melee rejected"):return
	var path:="user://tests/jungle_exit_scene.json"
	var error: String=scene.quicksave(path)
	if not check(error.is_empty(),"Production save rejected: "+error):return
	var saved: Dictionary=ctrl.checkpoint()
	if not check(saved.encounter.actors["60"].health==247 and saved.guards.actors["60"].health==247,"Immediate damage/save mirror lost health"):return
	ctrl.population.receive_damage("60",8)
	if not check(scene.quickload(path).is_empty() and ctrl.checkpoint()==saved,"Host disk rollback differs"):return
	var handoff: Dictionary=scene.area_handoff()
	if not check(Save.Quests.validate(handoff.quests).is_empty() and handoff.quests.jungle_exit_encounter==saved,"Area handoff dropped encounter"):return
	var invalid: Dictionary=Save.read_save(path).state.duplicate(true)
	invalid.quests.jungle_exit_encounter.visibility.seen=1
	var before: Dictionary=ctrl.checkpoint();var position: Vector3=scene.player.position
	if not check(not scene.apply_save(invalid).is_empty() and ctrl.checkpoint()==before and scene.player.position==position,"Malformed packet mutated host"):return
	# Continue the actual source hit/pose/timer/death path to the bridge movie.
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.interface_hud.set_cursor(false)
	for i in range(20): ctrl.advance(0.1)
	for id in State.GUARDS: ctrl.population.receive_damage(id,300,false,20)
	ctrl.checkpoint()
	for i in range(400):
		if ctrl.active(): break
		ctrl.advance(0.1)
	if not check(ctrl.active() and ctrl.encounter.ending.movie=="HW-BRDGE.VQA","Source combat/timer branch did not start bridge movie"):return
	ctrl.advance(0.8)
	var movie_path:="user://tests/jungle_exit_scene_movie.json"
	if not check(scene.quicksave(movie_path).is_empty(),"Host mid-movie save rejected"):return
	var movie_saved: Dictionary=ctrl.checkpoint()
	ctrl.advance(20.0)
	if not check(not ctrl.active() and scene.is_physics_processing(),"Movie did not release host movement"):return
	scene.set_physics_process(false)
	if not check(scene.quickload(movie_path).is_empty() and ctrl.checkpoint()==movie_saved and ctrl.active() and not scene.is_physics_processing(),"Host mid-movie load failed to restore pause/clock"):return
	if not check(not scene.open_inventory() and not scene.starting_magic.world_active(),"Movie allowed inventory/combat"):return
	var old_path: String=scene.interface_hud.save_path
	scene.interface_hud.save_path=movie_path
	var save_key:=InputEventKey.new();save_key.keycode=KEY_F5;save_key.pressed=true
	Input.parse_input_event(save_key);await process_frame
	scene.interface_hud.save_path=old_path
	if not check(Save.read_save(movie_path).state.quests.jungle_exit_encounter.movie.phase=="playing","F5 did not preserve active movie"):return
	ctrl.advance(20.0);scene.set_physics_process(false)
	# Legacy packet without optional encounter resets it to source absence.
	var legacy: Dictionary=Save.read_save(path).state.duplicate(true)
	legacy.quests.erase("jungle_exit_encounter")
	if not check(scene.apply_save(legacy).is_empty() and ctrl.targets().is_empty() and not ctrl.visibility.seen,"Legacy load retained later guards"):return
	# Supplied prop presence; occluder prevents admission even with story flags set.
	ctrl.set_prop_present(true)
	point_camera()
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(120,180,4);shape.shape=box;wall.add_child(shape);scene.add_child(wall)
	wall.global_position=Vector3(3592,30,-4105)+ctrl.population.origin()
	await physics_frame
	ctrl._visible_spawn()
	if not check(not ctrl.visibility.seen,"Occluded prop admitted visibility"):return
	wall.queue_free();await physics_frame
	ctrl._visible_spawn()
	if not check(ctrl.visibility.seen,"Removing occlusion did not allow first visibility"):return
	# Daniel knowledge in shop bank disarms predicate182 while local41 remains zero.
	ctrl.restore(ctrl.initial());ctrl.set_prop_present(true);scene.quest_state.weapon_shop.globals.GV_LUTHER_KNOWS_ABOUT_DANIEL=1
	ctrl._visible_spawn()
	if not check(not ctrl.visibility.seen and scene._exit_context().shared["47"]==1,"Weapon-shop story flag ignored"):return
	print("PASS: production Jungle exit named story admission, camera/frustum/occlusion and saved latch, real melee scale10, spell targets, immediate damage save, disk rollback, quest handoff, malformed atomicity and legacy absence; supplied location/story/region1921-presence fixture, not earned route")
	scene.queue_free();await process_frame;quit()
