extends "res://tests/bj14_sol_input_walk.gd"
## F-06 local two-process integration: pinned initial pack; real tomb/rail/pickup input.
## Explicit native handoff calls and one supplied L9 segment start are counted aids.
## This checks state across maps, not an unaided campaign or an earned travel route.
const GameSave=preload("res://scripts/lol2/game_save.gd")
var phase:=0
var folder:=""
func handoff(level:int,selector:int,path:String)->void:
	scene.progression._change_level({"level":level,"selector":selector,"scene":path})
	await scene_changed;scene=current_scene
	for i in 1800:
		await process_frame
		if scene.ready_for_review and scene.get("starting_magic")!=null:break
	scene.interface_hud.set_cursor(false);root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await ticks(24)
func run()->void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-phase="):phase=int(arg.get_slice("=",1))
		if arg.begins_with("--save-proof="):folder=arg.substr(13)
	if phase==1:
		assert(await load_input("globe"))
		assert(await walk(route("l10_two_empty_walk.json","door"),"saved-world tomb91 approach"))
		var tomb=scene.get_node("L10Tombs");await look(tomb.aims["91"]);await tap(KEY_E);await ticks(12)
		assert(tomb.opened("91"),"real E opens tomb91")
		assert(await walk(route("l10_two_empty_walk.json","lid"),"saved-world pickup56 approach"))
		await look(scene.act2_items.aim_point("act2:L10_DC:item56"));await tap(KEY_E);await ticks(6)
		assert("act2:L10_DC:item56" in scene.carried_collected,"real E changes pack")
		assert(scene.resets==0 and scene.starting_magic.health()>0)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/tomb_and_pickup.png")
		await handoff(9,0,"res://scenes/lol2/dragon_level.tscn")
		# One disclosed segment start at the pinned rail approach; retain the transferred pack/quests.
		scene.player.position=Vector3(631.826477,152.040985,-5800.340820);scene.player.velocity=Vector3.ZERO
		await ticks(12)
		assert(await walk([[639,-5700],[639,-5655]],"saved-world rail approach"))
		await look(Vector3(639,160,-5596));await click();await ticks(12)
		assert("480" in scene.get_node("L9NobleRails").state().broken,"real click breaks rail480")
		assert(scene.resets==0 and scene.starting_magic.health()>0)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/broken_rail.png")
		await handoff(8,1,"res://scenes/lol2/darker_jungle.tscn")
		assert(scene.can_save().is_empty(),scene.can_save());await tap(KEY_F5);await ticks(4)
		var read:=GameSave.read_document(GameSave.slot_path(1))
		assert(read.error.is_empty() and read.state.area=="L8_SJ")
		for area in ["L8_SJ","L9_DR","L10_DC"]:assert(read.state.native_bank.has(area))
		assert(scene.resets==0)
		print("PASS phase1 real tomb E, pickup E, rail click; explicit handoff/segment aids; F5 in L8; resets=0")
		quit();return
	var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate();root.add_child(gate);current_scene=gate
	await process_frame;gate.path_field.text=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	var button:Button=gate.find_child("Continue",true,false);assert(button!=null and not button.disabled)
	button.grab_focus();await tap(KEY_ENTER)
	if current_scene==gate:await scene_changed
	scene=current_scene
	for i in 1800:
		await process_frame
		if scene.ready_for_review and scene.get("starting_magic")!=null:break
	await ticks(12)
	assert("act2:L10_DC:item56" in scene.carried_collected,"pack retained after quit/Continue")
	assert(scene.quest_state.l10_tombs.slots["91"].committed and "480" in scene.quest_state.l9_noble_rails.broken)
	await handoff(10,1,"res://scenes/lol2/maps/L10_DC.tscn")
	assert(scene.get_node("L10Tombs").opened("91") and scene.get_node("L10Tombs").bodies["91"].collision_layer==0,"late tomb owner built from loaded quests")
	await handoff(9,0,"res://scenes/lol2/dragon_level.tscn")
	var rails=scene.get_node("L9NobleRails")
	assert("480" in rails.state().broken and rails.bodies[480].collision_layer==0,"late rail owner built from loaded quests")
	assert("act2:L10_DC:item56" in scene.carried_collected and scene.resets==0)
	print("PASS phase2 real Continue: changed pack, physical L10 tomb and L9 rail all retained; resets=0")
	quit()
