extends "res://tests/g04_floor_input_test.gd"
## Per-area local real-input conservation. Supplied view/stands and held owners
## are disclosed aids. No unaided route or exhaustive object interaction claim.
const Areas=preload("res://scripts/lol2/game_areas.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const ItemRows=preload("res://scripts/lol2/act2_items_catalog.gd")
func area()->String:return ""
func canonical(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value,"",true,true))
func observation()->Dictionary:
 var movers:Dictionary={}
 for id in scene.progression.hinges:movers[str(id)]=var_to_str(scene.progression.hinges[id].transform)
 return {"vm":canonical(scene.progression.native.snapshot()),"pack":scene.carried_collected.duplicate(),"quests":canonical(scene.quest_state),"durability":canonical(scene.progression.struck_durability),"floors":canonical(scene.progression.floor_checkpoint()),"movers":movers}
func supplied_view(point:Vector3,offset:Vector3):
 scene.player.position=point+offset-scene.camera.position;scene.player.velocity=Vector3.ZERO
 await look(point);await ticks(2)
func pickup()->String:
 var owner:Node=scene.act2_items
 for id:String in owner.sprites:
  if not owner.sprites[id].visible:continue
  var point:Vector3=owner.aim_point(id)
  for offset in [Vector3(0,20,40),Vector3(40,20,0),Vector3(0,20,-40),Vector3(-40,20,0),Vector3(0,40,8)]:
   await supplied_view(point,offset)
   if not owner.available(id) or owner.target()!=id:continue
   await key(KEY_E);await ticks(2)
   if id in scene.carried_collected:return id
 return ""
func changed(before:Dictionary,after:Dictionary)->Dictionary:
 var result:Dictionary={}
 for category:String in ["vm","quests","durability","movers"]:
  var rows:Dictionary={}
  for k in after[category]:
   if not before[category].has(k) or canonical(before[category][k])!=canonical(after[category][k]):rows[k]=after[category][k]
  if not rows.is_empty():result[category]=rows
 if before.pack!=after.pack:result.pack=after.pack
 return result
func keep(changes:Dictionary,actual:Dictionary)->Array:
 var losses:Array=[]
 for category in changes:
  if category=="pack":
   if actual.pack!=changes.pack:losses.append("pack")
  else:
   for k in changes[category]:
    if not actual[category].has(k) or canonical(actual[category][k])!=canonical(changes[category][k]):losses.append(str(category)+":"+str(k))
 return losses
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock input census"):return
 var a:=area();scene=load(Areas.ROWS[a].scene).instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 if a=="L17_HC":scene.progression.change_scene_enabled=false # Keep this explicitly local owner census on its area.
 var allowed:Dictionary=preload("res://scripts/lol2/act2_world_checkpoint.gd").mover_limits(a)
 var observed:Dictionary={}
 for id in scene.progression.hinges:
  if not preload("res://scripts/lol2/generic_object_catalog.gd").movables(a).has(int(id)):observed[str(id)]=true
 if not check(allowed.size()==observed.size() and observed.keys().all(func(id):return allowed.has(id)),a+" source-bounded mover save ids equal actual nonGeneric hinge owners"):return
 var arrival:Vector3=scene.player.position
 if a=="L12_CM":scene.get_node("L12RiverRafts").set_physics_process(false) # Separate clock-continuation case; do not attribute autonomous time to E.
 if a=="L17_HC":
  if not check(Grants.grant(scene,"cave:captain:Short_Sword",{"cap":false}).ok,"Disclosed blade fixture uses real API"):return
  scene.set_equipped_item("cave:captain:Short_Sword")
 var before:=observation();var action:=""
 if a=="L19_BC":
  scene.player.position=Vector3(120,32,350);scene.player.velocity=Vector3.ZERO
  await ticks(3);await key(KEY_E);await ticks(3)
  if not check(scene.quest_state.get("l19_belial_horn",{}).get("taken",false),"ActualE takes source horn"):return
  action="E:Belial horn"
 elif a=="L17_HC":
  scene.player.position=scene.get_node("L17BeastBlade").WEST_AT;scene.player.velocity=Vector3.ZERO
  await ticks(3);await key(KEY_E);await ticks(3)
  if not check(scene.quest_state.get("l17_beast_blade",{}).get("cut",false),"ActualE cuts the strand owner with the carried blade"):return
  action="E:beast strands"
 else:
  action=await pickup()
  if not check(not action.is_empty(),a+" realE takes one actually aimed source item"):return
 var after:=observation();var changes:=changed(before,after)
 if not check(not changes.is_empty(),"Real input changes saved world state"):return
 # Supplied views are local fixtures; save from the genuinely settled arrival.
 scene.player.position=arrival;scene.player.velocity=Vector3.ZERO;scene.set_physics_process(true)
 for i in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 if not check(scene.can_save().is_empty(),"Grounded save admission: "+scene.can_save()):return
 await key(KEY_F5);await ticks(2)
 var saved:=Saves.read_document(Saves.slot_path(Session.for_tree(self).last_slot))
 if not check(saved.error.is_empty(),a+" actualF5 slot validates"):return
 if not await reload():return
 var restored:=observation();var losses:=keep(changes,restored)
 var folder:="user://tests/g04_census/";DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder+a+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"area":a,"action":action,"changes":changes,"restored":restored,"lost":losses,"aids":"Local supplied view/stand and held host/creatures, save from grounded arrival. Not earned or exhaustive object interaction.","before":before,"after":after},"  ",true,true)+"\n");file.close()
 print("CENSUS ",a," action=",action," kept_categories=",changes.keys()," LOST=",losses)
 if not check(losses.is_empty(),a+" real-input changed fields surviveF5/F9: "+str(losses)):return
 if not check(scene.resets==0 and scene.starting_magic.health()>0,"Living local census no recovery"):return
 print("PASS G04 ",a," actualE/F5/F9 local world state; supplied stands disclosed")
 quit()
