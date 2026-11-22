extends "res://tests/helpers/g15_stored_spell_input.gd"
## One real-map component per source-entry, not an earned route. Initial story,
## genuine grants, NPC holds, ray-selected grounded stand and belt selection are
## explicit fixtures. No mocked target, action callback, collision or clock aid.
const GameAreas=preload("res://scripts/lol2/game_areas.gd")
const Discovery=preload("res://scripts/lol2/item_belt_targets.gd")
var row_data:Dictionary
func case_key()->String:return ""
func missing_probe()->bool:return false
func _initialize():main.call_deferred()
func subject()->Node:
 return scene.get(str(row_data.node).trim_prefix("@")) if str(row_data.node).begins_with("@") else scene.get_node(str(row_data.node))
func local_target()->Dictionary:
 var target:Dictionary=Discovery.find(scene)
 if target.is_empty() or target.owner!=subject():return {}
 var key:String=str(target.key).trim_prefix(str(subject().get_instance_id())+":")
 return target if key==str(row_data.target) else {}
func point()->Vector3:
 var n:Node=subject()
 match case_key():
  "hive_flute":return n.SLOT_POINT
  "charger":return n.globes[row_data.target].global_position
  "cemetery_gate":return n.AIM
  "tomb":return n.aims[row_data.target]
  "emperor_slab":return n.SLAB_AIM
  "emperor_door","emperor_socket":return n.AIMS[row_data.target]
  "priest_ashes":return n.AIM
  "citadel_exit":return n.SLOT
  "temple_flute","tree_slot","temple_entrance","spiral_slot","hopper_weight":return n.POINT
  "idol_pedestal":return n.CASES[row_data.target]
  "shard_bowl","ritual_bowl":return n.BOWLS[row_data.target]
  "greenhouse":return n.PLATE
  "ivory_pedestal":return n.PEDESTALS[int(row_data.target)]
  "larkhon":return n.aim()
  "daniel":return n.TARGETS.entry
  "village_guard":return n.TARGETS.village
  "museum_lock":return n.aim_point(int(row_data.target))
 return Vector3.ZERO
func outcome()->bool:
 var n:Node=subject()
 match case_key():
  "hive_flute":return n.occupied()
  "charger":return n.globes[row_data.target].visible
  "cemetery_gate","emperor_slab":return n.opened()
  "tomb":return n.opened(row_data.target)
  "emperor_door":return n.State.opened(n.state())
  "emperor_socket":return n.State.Kit.slot(n.state(),row_data.target).committed
  "priest_ashes":return n.Ankh.committed(scene.quest_state.get("l10_ankh",{}),n.Ankh.TRADE) and n.Ankh.ANKH in scene.item_effects.carried()
  "citadel_exit","temple_entrance":return n.State.unlocked(n.state())
  "temple_flute","spiral_slot":return n.committed(n.state())
  "idol_pedestal","shard_bowl","ritual_bowl":return n.Kit.slot(n.state(),row_data.target).committed
  "greenhouse":return not n.state().silverleaf.is_empty()
  "ivory_pedestal":return int(row_data.target) in n._indexes()
  "tree_slot":return n.Slot.unlocked(n.state().lock)
  "larkhon":return n.State.used(n.state())
  "hopper_weight":return n.Kit.slot(n.state(),"91").committed
  "daniel":return n.opened=="entry" and n.panel.visible
  "village_guard":return n.opened=="village" and n.panel.visible
  "museum_lock":return n.State.is_loaded(n.state,int(row_data.target))
 return false
func view_matches(pickup:bool)->bool:
 if not pickup:return not local_target().is_empty()
 var target:Dictionary=subject().target()
 return target.get("lock",-1)==87
func view_target(pickup:bool=false)->bool:
 var aim:Vector3=subject().aim_point(87) if pickup else point()
 # First retain the genuine saved stand if its real aim/reach already works.
 if await look(aim):
  await frames(3)
  if view_matches(pickup):return true
 var shape:CollisionShape3D
 for child in scene.player.get_children():
  if child is CollisionShape3D and not child.disabled:shape=child;break
 if not require(is_instance_valid(shape),"Actual player collision shape available"):return false
 var space:PhysicsDirectSpaceState3D=scene.get_world_3d().direct_space_state
 var deadline:int=Time.get_ticks_msec()+45000
 var offsets:Array=[]
 if row_data.has("preferred_xz"):offsets.append(Vector3(row_data.preferred_xz[0]-aim.x,0,row_data.preferred_xz[1]-aim.z))
 for radius in [60.0,88.0,116.0,144.0]:
  for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized(),Vector3(1,0,-1).normalized(),Vector3(-1,0,-1).normalized()]:offsets.append(direction*radius)
 for offset:Vector3 in offsets:
  if Time.get_ticks_msec()>deadline:break
  print("NATIVE_E_VIEW ",case_key()," offset=",offset)
  var start:Vector3=aim+offset+Vector3.UP*16
  var floor:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*512,1,[scene.player.get_rid()]))
  if floor.is_empty() or floor.normal.y<0.6:continue
  var stand:Vector3=floor.position+Vector3.UP*33
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=Transform3D(scene.player.global_basis,stand+shape.position);query.collision_mask=1;query.exclude=[scene.player.get_rid()];query.margin=0.01
  if not space.intersect_shape(query,1).is_empty():continue
  scene.player.global_position=stand;scene.player.velocity=Vector3.ZERO
  for tick in 18:
   await physics_frame
   if scene.player.is_on_floor():break
  if not require(hp()>0 and scene.resets==0,"Supplied stand must never require revival or fall recovery"):return false
  if not scene.player.is_on_floor():continue
  if not await look(aim):return false
  await frames(3)
  if view_matches(pickup):return true
 await picture("belt_e_unreachable_"+case_key())
 return require(false,"No grounded source stand with actual aimed target: "+case_key())
func boot_case()->bool:
 var scene_path:String=GameAreas.ROWS[row_data.area].scene
 if not str(row_data.get("checkpoint","")).is_empty():
  if not await boot_legacy("res://"+row_data.checkpoint,row_data.sha256,row_data.format,scene_path):return false
 else:
  scene=load(scene_path).instantiate()
  if row_data.area=="L3_DH":scene.introduction_state="complete"
  if scene.get("adapter_exit_seeds")!=null:scene.adapter_exit_seeds=false
  root.add_child(scene);current_scene=scene
  var ready:=false
  for tick in 3000:
   await process_frame
   if scene.get("ready_for_review") is bool and not scene.ready_for_review:continue
   if scene.get("walkthrough_ready") is bool and not scene.walkthrough_ready:continue
   if scene.is_node_ready() and is_instance_valid(scene.get("item_effects")):ready=true;break
  if not require(ready,"Actual area host ready"):return false
  use_guard=false;await adopt()
  if not captured():await lclick()
 for property in ["act2_creatures","return_population","dino_population","villager_population"]:
  var population:Variant=scene.get(property)
  if is_instance_valid(population):population.set_physics_process(false)
 if scene.has_node("Warriors"):scene.get_node("Warriors").set_physics_process(false)
 if is_instance_valid(scene.get("progression")):scene.progression.change_scene_enabled=false
 for id:String in row_data.get("grant",[]):
  if id in scene.item_effects.carried():continue
  var sync:bool=scene.get("carried_collected") is Array
  if not require(Grants.grant(scene,id,{"cap":false,"history":"act2_once" if id.begins_with("act2:") else "none","sync":sync}).ok,"Disclosed genuine-ID item fixture"):return false
 if case_key()=="village_guard":
  var initial:Dictionary=subject().State.initial();initial.gift="recovered";initial.temple_visited=true
  scene.quest_state.l8_journey=initial
 if case_key()=="museum_lock":
  # Genuine original pickup via E, not a fabricated key-history grant.
  var n:Node=subject()
  if not await view_target(true):return false
  await tap(KEY_E);await frames(4)
  if not require(n.State.KEY in scene.item_effects.carried(),"Original real E picks up museum key87"):return false
 return require(hp()>0 and scene.resets==0 and scene.player_form==0,"Living Human input component, no recovery")
func run_missing()->bool:
 var target:Dictionary=local_target()
 var absent:Array=scene.item_effects.carried().filter(func(id):return not Discovery.accepts(target,id))
 # Explicit initial absence fixture, not a legal-loss or earned-route claim.
 # Live F08 correctly refuses discarding these protected quest resources.
 # Build the admitted initial packet through the real loader instead; gameplay
 # remains unable to perform this destructive fixture transition.
 var initial:Dictionary=scene.area_snapshot().duplicate(true)
 initial.inventory.collected=initial.inventory.collected.filter(func(id):return id in absent)
 initial.quests.act2_items.carried=initial.quests.act2_items.carried.filter(func(id):return id in absent)
 if not require(scene.apply_save(initial).is_empty(),"Disclosed missing-material initial save fixture admitted by actual loader"):return false
 await frames(3)
 if not await view_target():return false
 if not assert_item_action_saveable("explicit missing-material fixture BEFORE E"):return false
 var before:Dictionary=subject().state().duplicate(true)
 scene.item_effects.advance_belt(0.0)
 await tap(KEY_E);await frames(4)
 await picture("belt_e_missing_"+case_key())
 var word:String={"idol_pedestal":"Jkar idol","shard_bowl":"green crystal shard","ritual_bowl":"Poison Paint"}[case_key()]
 if not require(not outcome() and scene.interface_hud.hint.text.contains(word),"Real E names the missing material: "+word+"; screen="+scene.interface_hud.hint.text):return false
 if not require(subject().state()==before and scene.item_effects.carried()==absent,"Missing-item E changes neither owner state nor owned items"):return false
 if not await disk_cycle("belt_missing_"+case_key()):return false
 return require(not outcome() and hp()>0 and scene.resets==0,"Refused initial state remains usable through F5/F9")
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_belt_native_e_inputs.json"))
 row_data=manifest.rows[case_key()]
 if not await boot_case():return
 if not await view_target():return
 if missing_probe():
  if not await run_missing():return
  print("PASS real E missing ",case_key()," names material, changes no owner/items, F5/F9; explicit valid initial absence fixture, not a legal resource-loss witness")
  quit();return
 var target:Dictionary=local_target()
 var needed:String=Discovery.pick(target,scene.item_effects.carried())
 if not require(not needed.is_empty(),"Required item is actually carried for "+case_key()):return
 if case_key() in ["citadel_exit","spiral_slot","temple_entrance","emperor_slab","tree_slot"]:
  if not require(scene.item_effects.carried().count(needed)==1,"The exact required copy is unique before real E"):return
  print("RECOVERABLE_LAST_COPY ",case_key()," id=",needed," copies=",scene.item_effects.carried().count(needed))
 if not require(not outcome(),"The intended owner action has NOT already occurred"):return
 if bool(row_data.get("unrelated_hand",false)):
  var selected:=false
  for id in scene.item_effects.carried():
   if not Discovery.accepts(target,id):scene.hand_item=id;selected=true;break
  if not require(selected,"Disclosed unrelated hand selection comes from genuinely carried items"):return
 scene.item_effects.advance_belt(0.0)
 if not require(scene.item_effects.put_on_belt(needed,0),"Required carried reference in a nonactive belt slot"):return
 var belt:Dictionary=scene.item_effects.belt_state()
 if case_key()=="hive_flute":
  belt.active=0 # Existing disclosed belt-selection component fixture.
  var held_before:Array=scene.item_effects.carried().duplicate()
  await tap(KEY_F);await frames(3)
  if not require(scene.item_effects.carried()==held_before and scene.interface_hud.hint.text=="You play the flute." and scene.elevator.checkpoint.flute_signal==1,"Hive real F may play the reusable flute without spending it"):return
  if not require(preload("res://scripts/lol2/quest_resource_protection.gd").removing(scene,held_before,needed).contains("Temple oil passage"),"Future Temple obligation is active on the real Hive checkpoint host"):return
  if not await disk_cycle("hive_protected_flute_before_E"):return
  if not require(needed in scene.item_effects.carried(),"Hive carried_quest_checkpoint and protected flute survive actual F5/F9"):return
  belt=scene.item_effects.belt_state()
 belt.slots[4]=-1;belt.ages[4]=0;belt.active=4 # Deliberate belt-selection fixture, not pack/story mutation.
 if not require(belt.active==4 and not Discovery.accepts(target,scene.item_effects.BeltState.resolve(belt,4,scene.item_effects.carried())),"Active slot does NOT fit the target"):return
 print("NATIVE_E_BEFORE ",case_key()," native=",target.get("native_e")," actor_lock=",scene.actor_input_locked() if scene.has_method("actor_input_locked") else false," paused=",paused," hand=",scene.get("hand_item"))
 for name in ["GenericObjects","GenericWorld"]:
  var generic:Node=scene.get_node_or_null(name)
  if is_instance_valid(generic) and generic.has_method("aimed"):print("NATIVE_E_GENERIC ",generic.aimed())
 await tap(KEY_E);await frames(4)
 if case_key()=="daniel":
  var speech:Node=scene.get_node("L8HulineSpeech")
  if speech.input_locked():
   # r19o gives an aimed Huline's native speech priority over the regional
   # Daniel meeting. Finish that real speech, then E opens the meeting.
   if not require(subject().opened.is_empty(),"Original native speech keeps its priority over the meeting"):return
   await picture("belt_e_native_huline_priority")
   await tap(KEY_ENTER);await frames(4)
   if not require(not speech.input_locked(),"Real Enter completes the native speech"):return
   await tap(KEY_E);await frames(4)
 await picture("belt_e_native_"+case_key())
 print("NATIVE_E_AFTER ",case_key()," outcome=",outcome()," opened=",subject().get("opened")," paused=",paused," hint=",scene.interface_hud.hint.text)
 if not require(outcome(),"Plain real E preserves the native owner action with required item NONactive: "+case_key()):return
 if case_key() in ["daniel","village_guard"]:await tap(KEY_ESCAPE);await frames(3)
 if not await disk_cycle("belt_native_e_"+case_key()):return
 if case_key() not in ["daniel","village_guard"] and not require(outcome(),"Native owner result survives actual F5/F9: "+case_key()):return
 print("PASS native E ",case_key()," required carried but NONactive, actual owner outcome, F5/F9, alive0resets; local checkpoint/grant/stand/NPC/selection fixtures explicitly disclosed, not an earned walk")
 quit()
