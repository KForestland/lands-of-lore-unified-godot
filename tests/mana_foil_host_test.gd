extends SceneTree
const IDS=["cave:control75:Mana_foil","jungle:magic_shop:Mana_foil"]
const Grants=preload("res://scripts/lol2/item_grants.gd")
var scene
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
 if not ok:printerr("FAIL foil: "+message);quit(1)
 return ok
func freeze():
 scene.set_physics_process(false);scene.player.set_physics_process(false)
 scene.item_effects.set_process(false);scene.starting_magic.set_process(false)
func use_ui(id:String)->bool:
 if not check(scene.open_inventory(),"inventory open"):return false
 await process_frame
 var index:=-1
 for j in scene.inventory.item_list.item_count:
  if str(scene.inventory.item_list.get_item_metadata(j))==id:index=j
 if not check(index>=0,"foil missing"):return false
 scene.inventory.select_item(index)
 if not check(scene.inventory.use_button.visible and scene.inventory.use_button.text=="Use Mana Foil","use button"):return false
 scene.inventory.use_button.pressed.emit();await process_frame
 return true
func close_ui():
 if is_instance_valid(scene.inventory):scene.inventory.close()
 await process_frame;await process_frame
func run() -> void:
 scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state="complete";root.add_child(scene);current_scene=scene
 await process_frame;freeze()
 # Only the actual prior-area Cave identity belongs in Museum's validator.
 # The later Jungle-shop identity was formerly consumed before save, masking
 # an invalid initial fixture when the no-effect rule started keeping it.
 scene.carried_collected.append(IDS[0])
 var magic:Dictionary=scene.starting_magic.magic_state().duplicate(true)
 magic.player.maximum=100;magic.player.mana=10;scene.starting_magic.commit(magic)
 scene.player_form=1
 if not check(not scene.item_effects.use(IDS[0]),"transformed use admitted"):return
 scene.player_form=0
 if not await use_ui(IDS[0]):return
 if not check(scene.starting_magic.magic_state().player.mana==60 and IDS[0] in scene.item_effects.state().spent and IDS[0] not in scene.carried_collected and not scene.item_effects.use(IDS[0]),"Cave foil +50, consumption and repeat refusal"):return
 await close_ui()
 DirAccess.make_dir_recursive_absolute("user://tests")
 var path:="user://tests/mana_foil_used.json"
 var error:String=scene.quicksave(path)
 if not check(error.is_empty() and scene.quickload(path).is_empty(),"Museum consumed foil save/load: "+error):return
 var packet:Dictionary=scene.inventory_state()
 scene.queue_free();await process_frame;await process_frame
 scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
 root.add_child(scene);current_scene=scene;await process_frame;freeze()
 if not check(scene.apply_inventory_handoff(packet).is_empty(),"Actual Museum-to-Jungle inventory transport"):return
 if not check(Grants.grant(scene,IDS[1],{"cap":false}).ok,"Disclosed Jungle-shop foil fixture on its admitted host"):return
 magic=scene.starting_magic.magic_state().duplicate(true);magic.player.mana=100;scene.starting_magic.commit(magic)
 if not await use_ui(IDS[1]):return
 if not check(IDS[1] in scene.carried_collected and IDS[1] not in scene.item_effects.state().spent and scene.starting_magic.magic_state().player.mana==100 and scene.inventory.detail_text.text=="Your mana is already full.","Full-mana foil kept with its reason"):return
 await close_ui()
 error=scene.quicksave(path)
 if not check(error.is_empty() and scene.quickload(path).is_empty(),"Jungle kept foil save/load: "+error):return
 if not check(IDS[0] in scene.item_effects.state().spent and IDS[1] not in scene.item_effects.state().spent and IDS[1] in scene.carried_collected,"Fresh loads retain consumed and kept ownership"):return
 print("PASS Cave foil in Museum +50/consume/form/repeat/save; real inventory handoff to Jungle; Jungle foil full-mana refusal/kept/save. Explicit supplied item/pool fixtures, not earned input.")
 quit()
