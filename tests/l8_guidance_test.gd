extends "res://tests/l12_logs_approach_earned_test.gd"
## L8 night-jungle guidance (DEVIATIONS 0306) and the shaman-serum refusal (DEVIATIONS 0308).
## 1) guidance_for() picks only earned-knowledge notes; 2) the owner's darker_jungle quicksave COPY (early arrival, no Act 2
## progress) shows the guardian line, records the note and refuses L8->L12 with it, without errors; 3) the owner's platform
## report point shows the torch line with the lit count, which follows an actual Spark receipt; 4) the shaman's serum
## refuses a standalone use and stays carried. Player placement here is a presentation probe, not a progression route.
const Guardian=preload("res://scripts/lol2/l8_larkhon_state.gd")
const Larkhon=preload("res://scripts/lol2/l8_larkhon.gd")
const Trade=preload("res://scripts/lol2/l8_shaman_trade.gd")
const MyJournal=preload("res://scripts/lol2/my_journal.gd")
const Controller=preload("res://scripts/lol2/player_item_controller.gd")
const ItemState=preload("res://scripts/lol2/player_item_state.gd")
class Magic:
 extends Node
 func health()->int:return 30
 func magic_state()->Dictionary:return {"player":{"mana":10,"maximum":100}}
class Host:
 extends Node3D
 var player_form:=0
 var carried_collected: Array=[]
 var item_effect_checkpoint: Dictionary={}
 var inventory: Control
 var starting_magic: Node
 var feedback: Array=[]
 func save_feedback(text:String)->void:feedback.append(text)
func stages()->void:
 var leaf:="act2:L10_DC:silverleaf164"
 check(Larkhon.guidance_for({},[])=="larkhon_join_tribe","no Act 2 progress: join the tribe first (owner 2026-11-05)")
 var member:={"l8_tribe":{"phase":"departed"}}
 check(Larkhon.guidance_for(member,[leaf])=="larkhon_ask_shaman","initiated, no trade: shaman")
 var traded:={"l8_tribe":{"phase":"departed"},"l8_shaman_trade":{"version":1,"slots":{Trade.TARGET:{"committed":true,"occupied":"","receipts":[Trade.TARGET]}},"leaf":leaf}}
 check(Larkhon.guidance_for(traded,[Trade.SERUM])=="larkhon_serum_needs_leaf","serum carried: mix with Silverleaf")
 var mixed:=traded.duplicate(true);mixed.l8_larkhon={"version":1,"slots":{Guardian.SERUM:{"committed":true,"occupied":"","receipts":[Guardian.SERUM]}},"leaf":leaf,"serum":Trade.SERUM,"active":false,"sleep":0.0}
 check(Larkhon.guidance_for(mixed,[Guardian.VAPORS])=="larkhon_vapors_unactivated","vapors mixed: activate and use")
 var active:=mixed.duplicate(true);active.l8_larkhon.active=true
 check(Larkhon.guidance_for(active,[Guardian.VAPORS])=="","active dose keeps the existing right-click line")
 var used:=mixed.duplicate(true);used.l8_larkhon.slots[Guardian.CHEST]={"committed":true,"occupied":Guardian.VAPORS,"receipts":[Guardian.CHEST]}
 check(Larkhon.guidance_for(used,[])=="","used dose: no guidance")
 for id in ["larkhon_join_tribe","larkhon_must_sleep","larkhon_ask_shaman","larkhon_serum_needs_leaf","larkhon_vapors_unactivated","tree_torches_unlit"]:
  check(MyJournal.hints().has(id) and str(MyJournal.hints()[id]).length()<=130,"short journal note "+id)
func serum_refusal()->void:
 var host=Host.new();var controller=Controller.new();var magic=Magic.new()
 host.starting_magic=magic;host.inventory=Control.new();host.item_effect_checkpoint=ItemState.initial();host.carried_collected=[Trade.SERUM]
 controller.host=host
 check(not controller.use(Trade.SERUM) and Trade.SERUM in host.carried_collected,"shaman serum standalone use refused and kept")
 check(host.item_effect_checkpoint.spent.is_empty() and host.feedback==[Controller.SERUM_REFUSAL],"refusal spends nothing and explains the mix")
 host.inventory.free();magic.free();controller.free();host.free()
func run():
 stages();serum_refusal()
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/owner_saves/darker_jungle_quicksave.json"
 if not check(FileAccess.get_sha256(path)=="7bafaec9f21a38d6a73656a0b3b2ea3433520c2a37d1ccce1019800f03f7f0ef","owner darker_jungle quicksave copy (2026-11-03)"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"owner save applies"):quit(1);return
 prepare(scene)
 for key in ["l8_journey","l8_tribe","l8_shaman_trade","l8_larkhon","l8_tree"]:check(not scene.quest_state.has(key),"owner save has no "+key)
 var guardian=scene.get_node("L8Larkhon");var tree=scene.get_node("L8Tree")
 check(guardian.guidance()=="larkhon_join_tribe","owner state (not yet in the tribe): earned stage is 'join the tribe'")
 await process_frame
 check(guardian.hint.text=="","no guardian line far from the guardian")
 # Presentation probe: stand on the river side of the guardian.
 var body:Vector3=scene.act2_creatures.bodies["115"].global_position
 scene.player.global_position=body+Vector3(-300,0,0);scene.player.velocity=Vector3.ZERO
 for i in 4:await process_frame
 var text:String=str(MyJournal.hints()["larkhon_join_tribe"])
 check(guardian.hint.text==text,"guardian line shown near the guardian: "+guardian.hint.text)
 check("larkhon_join_tribe" in MyJournal.notes(scene),"note recorded in My Journal")
 check(MyJournal.notes(scene).count("larkhon_join_tribe")==1,"note recorded once")
 scene.progression._change_level({"level":12,"selector":1,"scene":"res://scenes/lol2/maps/L12_CM.tscn"})
 check(scene.progression.native_log.back().get("owner")=="l8_larkhon","unearned L8->L12 still refused")
 check(scene.interface_hud.hint.text=="The Larkhon guards the cave entrance. "+text,"refusal carries the guidance: "+scene.interface_hud.hint.text)
 # Owner's platform report point (-1038,-2302, H132).
 scene.player.global_position=Vector3(-1038,132,-2302)
 for i in 4:await process_frame
 check(guardian.hint.text=="","guardian line hidden away from the guardian")
 check(tree.hint.text=="Five torches ring this platform — light each with Spark (Human). Lit 0 of 5.","torch line at the owner's platform point: "+tree.hint.text)
 check("tree_torches_unlit" in MyJournal.notes(scene),"torch note recorded")
 check(tree.spark("1338",1),"Spark receipt on torch1338")
 for i in 2:await process_frame
 check(tree.hint.text.ends_with("Lit 1 of 5."),"lit count follows the receipt: "+tree.hint.text)
 var error:String=scene._quicksave_unrecorded("res://tmp/l8_guidance_owner_probe_save.json")
 check(error.is_empty(),"owner probe save: "+error)
 error=scene._quickload_unrecorded("res://tmp/l8_guidance_owner_probe_save.json")
 check(error.is_empty(),"owner probe reload (journal notes + partial torches): "+error)
 check(MyJournal.notes(scene).has("tree_torches_unlit") and scene.get_node("L8Tree").state().lit==["1338"],"notes and lit torch survive reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS L8 guidance: earned-stage notes, owner early-arrival guardian line/journal/refusal, platform torch line with lit count, shaman serum refusal")
 quit(0 if failures==0 else 1)
