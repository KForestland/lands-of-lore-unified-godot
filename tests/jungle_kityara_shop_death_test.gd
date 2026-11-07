extends "res://tests/jungle_kityara_live_test.gd"
## Supplied translated-runes prerequisite and hit event; original presence/death/drop
## commands on the real host, then actual shop entry, refusal, save/load and exit.
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[],"equipped_item":"","equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	k=scene.kityara;k.set_physics_process(false)
	scene.quest_state.monastery.globals["GV_RUNES_TRANSLATED"]=1
	k.apply(k.State.enter_region(k.state,k.src,1305,k.context()))
	if not check(k.state.controls["0"].present and int(k.state.locals["21"])==0,"Pre-conversation presence failed"): return
	k.apply(k.State.hit(k.state,k.src,0,k.context()))
	await step(100)
	k.apply(k.State.use_prop(k.state,k.src,64,k.context()))
	if not check(int(k.state.locals["21"])==0 and k.validate(k.checkpoint()).is_empty(),"Original death/drop produced invalid state"): return
	var shop=scene.weapon_shop
	if not check(scene.quest_state.monastery.globals.get("GV_KITYARA_DEAD",0)==1 and shop.state().globals.get("GV_KITYARA_DEAD",0)==1,"Death is not shared with the shop"): return
	if not check(scene.carried_collected.count(Catalog.KITYARA_KNIFE)==1,"Dropped blade was not granted once"): return
	if not check(shop.enter_exterior() and shop.interact("enter"),"Source dead-shop admission rejected"): return
	if not check(not shop.State.active(shop.state()) and not shop.view.patch.visible and not shop.held.visible and not shop.offer_button.visible,"Dead Kityara is speaking or visible in her shop"): return
	var inventory: Array=scene.carried_collected.duplicate()
	if not check(not shop.interact("shortsword") and shop.State.offer(shop.state(),"83-Power orb").is_empty() and scene.carried_collected==inventory,"Dead shop supplied a live conversation/reward"): return
	# Older packets may have only the shared monastery copy; room restoration
	# must still read the death, rather than showing the living shop actor.
	shop.state().globals.erase("GV_KITYARA_DEAD")
	shop.restore()
	if not check(shop.state().globals.get("GV_KITYARA_DEAD",0)==1 and not shop.view.patch.visible,"Legacy death-bank reconciliation failed"): return
	var path:="user://tests/lead_kityara_shop_death.json"
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Death/drop/shop checkpoint rejected"): return
	if not check(scene.weapon_shop.state().room=="WPN" and not scene.weapon_shop.view.patch.visible and scene.carried_collected.count(Catalog.KITYARA_KNIFE)==1,"Death/drop lost on reload"): return
	shop.leave_room();shop.leave_room()
	if not check(not shop.active(),"Empty shop cannot be left"): return
	await finish(scene)
	DirAccess.remove_absolute(path)
	print("PASS Kityara pre-conversation death/drop: shared shop death, empty-room entry, no living dialogue/offer, legacy bank restore, disk save/load, exit. Translation and hit supplied.")
	quit()
