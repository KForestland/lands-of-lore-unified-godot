extends "res://tests/helpers/real_input_player.gd"
## Strict pilot sitting, staged incrementally. Entry is the owner's pinned C15 F2 Cemetery start.
const Starts=preload("res://scripts/lol2/playtest_starts.gd")
const Slots=preload("res://scripts/lol2/game_save.gd")
var receipts:Array=[]
func _initialize():main.call_deferred()
func require(ok:bool,message:String)->bool:
 if not ok:stop("sitting",message);quit(1)
 return ok
func picture(tag:String):
 var dir:="user://tests/generic_l10_sitting/";DirAccess.make_dir_recursive_absolute(dir)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+tag+".png")
func start_from_f2()->bool:
 if not require(DisplayServer.get_name()!="headless","Rendered player sitting required"):return false
 if not require(is_equal_approx(Engine.time_scale,1.0) and Engine.physics_ticks_per_second==60,"Ordinary clock1/60 required"):return false
 var original:String=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
 if not require(not original.is_empty() and FileAccess.file_exists(original),"Set LOL2_ORIGINAL_GAME_EXE to the player's original LOLG.EXE; this acceptance gate must not skip"):return false
 var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate()
 gate.settings_path="user://tests/generic_l10_gate.cfg"
 # The stager copies private test settings but deliberately no player slots.
 # An old remembered EXE would auto-start Cave before our real F2 event.
 # Reset only this test-owned setting; normal player settings/slots are untouched.
 DirAccess.make_dir_recursive_absolute("user://tests")
 var isolated_settings:=ConfigFile.new()
 if not require(isolated_settings.save(gate.settings_path)==OK,"Reset private test gate settings before actualF2"):return false
 root.add_child(gate);current_scene=gate
 for i in 3:await process_frame
 gate.path_field.text=original
 var entry:Dictionary=Starts.manifest().entries.filter(func(e):return e.id=="act2-l10")[0]
 if not require(Starts.file_error(entry).is_empty(),"Pinned canonical C15 Cemetery input is staged"):return false
 await tap(KEY_F2)
 for i in 40:
  var focus:Control=root.gui_get_focus_owner()
  if focus!=null and str(focus.name)=="Start_act2-l10":break
  await tap(KEY_TAB if focus==null else KEY_DOWN)
 var focus:Control=root.gui_get_focus_owner()
 if not require(focus!=null and str(focus.name)=="Start_act2-l10","Real keyboard selects Cemetery F2 row"):return false
 await picture("f2_start")
 await tap(KEY_ENTER)
 for i in 3000:
  await process_frame
  if current_scene!=gate and is_instance_valid(current_scene) and current_scene.get("ready_for_review")==true:break
 await adopt()
 if not captured():await lclick();await frames(4)
 if not require(area=="L10_DC" and scene.resets==0 and hp()>0 and captured(),"Living walking Cemetery start, ordinary capture"):return false
 if not require(not scene.development_mode and not scene.starting_magic.interface_request and not scene.adapter_exit_seeds,"Production input without preview seeds or test bypass"):return false
 receipts.append({"start":"act2-l10","sha256":entry.sha256,"health":hp(),"position":str(pos()),"clock":[Engine.time_scale,Engine.physics_ticks_per_second]})
 return true
func take_item(id:String,label:String)->bool:
 var items:Node=scene.act2_items
 if not require(not id in scene.carried_collected,label+" begins uncollected"):return false
 await act(items.aim_point(id),"Take "+label)
 if not require(id in scene.carried_collected and not items.sprites[id].visible,"RealE takes "+label):return false
 receipts.append({"action":"take","id":id,"position":str(pos()),"health":hp(),"resets":scene.resets})
 return true
func charge_one(id:String)->bool:
 var charger:Node=scene.get_node("Act2Chargers")
 var before:Array=scene.carried_collected.duplicate()
 await act(charger.globes[id].global_position,"Place empty globe")
 if not require(not charger.state().slots.get(id,{}).get("occupied","").is_empty(),"RealE inserts/charges at "+id):return false
 await act(charger.globes[id].global_position,"Retrieve charged globe")
 if not require(charger.state().slots[id].occupied.is_empty() and scene.carried_collected!=before,"RealE retrieves changed globe identity at "+id):return false
 receipts.append({"action":"charge/retrieve","id":id,"position":str(pos()),"pack":scene.carried_collected.duplicate(),"health":hp(),"resets":scene.resets})
 return true
func checkpoint(tag:String)->bool:
 # Native local transports also leave a cached floor flag until physics runs.
 for tick in 4:await physics_frame
 for tick in 180:
  await physics_frame
  if scene.player.is_on_floor():break
 if not require(scene.player.is_on_floor() and hp()>0 and scene.resets==0,"Living grounded earned checkpoint without fall recovery: "+tag):return false
 var path:=Slots.slot_path(1)
 var before:String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
 var stood:Vector3=pos()
 await tap(KEY_F5)
 var read:=Slots.read_document(path)
 if not require(read.error.is_empty() and read.state.area==area,"RealF5 writes earned stage "+tag):return false
 var saved:Array=read.state.area_save.player.position
 if not require(FileAccess.get_sha256(path)!=before and Vector3(saved[0],saved[1],saved[2]).distance_to(stood)<1.0,"New F5 document belongs to the actual standing pose, not a previous save"):return false
 var directory:="user://tests/generic_l10_sitting/checkpoints/";DirAccess.make_dir_recursive_absolute(directory)
 var copy:=directory+tag+".json"
 if not require(DirAccess.copy_absolute(path,copy)==OK,"Retain game-written stage without editing it"):return false
 receipts.append({"checkpoint":tag,"sha256":FileAccess.get_sha256(copy),"area":area,"position":str(pos()),"health":hp(),"resets":scene.resets})
 return true
func main():
 if not await start_from_f2():return
 var route:Dictionary=fixture("l10_tomb_walk.json")
 if not await walk(route.pickup,"entry to first original globe"):await picture("stop");quit(1);return
 if not await take_item("act2:L10_DC:item44","original empty44"):return
 if not await walk(route.charger,"first yellow charger"):await picture("stop");quit(1);return
 if not await charge_one("L10:yellow"):return
 if not await checkpoint("yellow44"):return
 if not await return_to_ruins():return
 await finish_stage()
func return_to_ruins()->bool:
 var route:Dictionary=fixture("l10_tomb_walk.json")
 var retreat:Array=route.charger.duplicate(true);retreat.reverse()
 if not await walk(retreat,"back from the yellow charger"):await picture("stop");quit(1);return false
 retreat=route.pickup.duplicate(true);retreat.reverse()
 if not await walk(retreat,"earned return up the Cemetery stairs"):await picture("stop");quit(1);return false
 var revisit:Dictionary=fixture("l9_white_revisit_walk.json")
 if not await walk(revisit.statue.points.slice(40),"F2 approach to the winged statue"):await picture("stop");quit(1);return false
 var row:Array=scene.progression.exit_objects["control:150"][0].position
 await act(Vector3(row[0],row[1],row[2]),"Use the winged statue")
 if not await checkpoint("before_ruins_mirror"):return false
 if not await walk(revisit.mirror42.points,"walk into the native Ruins mirror",{"final_reach":2.0}):await picture("stop");quit(1);return false
 if not await travelled("Native Cemetery mirror to Ruins"):await picture("stop");quit(1);return false
 if not require(area=="L9_DR" and "act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"Native arrival carries the actually charged globe"):return false
 if not await checkpoint("first_ruins"):return false
 return true
func finish_stage():
 if not require(scene.resets==0 and hp()>0 and stops.is_empty(),"No fall recovery/death/stall"):return
 await picture("first_charged_globe")
 var f:=FileAccess.open("user://tests/generic_l10_sitting/receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"phase":"FIRST RUINS ARRIVAL ONLY, full pilot outstanding","receipts":receipts,"resets":scene.resets,"stops":stops},"  "));f.close()
 print("PASS B sitting first Ruins arrival ONLY: realF2 Cemetery -> realW globe44/yellow charger -> return stairs -> statue/mirror -> native L9; realF5 checkpoints, no pose/clock/health aids, resets0")
 quit()
