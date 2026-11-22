extends "res://tests/generic_l10_sitting_test.gd"
## G03 L13 source-grounded ordinary-clock input proof. No production action calls.
## Starts from the same pinned C15 row as Grok; saves/ in his bundle is empty.
func picture(tag:String):
 var dir:="user://tests/g03_l13/";DirAccess.make_dir_recursive_absolute(dir)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+tag+".png")
func start_from_f2()->bool:
 if not require(DisplayServer.get_name()!="headless","Rendered player sitting required"):return false
 if not require(is_equal_approx(Engine.time_scale,1.0) and Engine.physics_ticks_per_second==60,"Ordinary clock1/60 required"):return false
 var original:String=OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
 if not require(not original.is_empty() and FileAccess.file_exists(original),"Set LOL2_ORIGINAL_GAME_EXE to the player's original LOLG.EXE; this acceptance gate must not skip"):return false
 var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate()
 gate.settings_path="user://tests/generic_l13_gate.cfg"
 # The stager copies private test settings but deliberately no player slots.
 # An old remembered EXE would auto-start Cave before our real F2 event.
 # Reset only this test-owned setting; normal player settings/slots are untouched.
 DirAccess.make_dir_recursive_absolute("user://tests")
 var isolated_settings:=ConfigFile.new()
 if not require(isolated_settings.save(gate.settings_path)==OK,"Reset private test gate settings before actualF2"):return false
 root.add_child(gate);current_scene=gate
 for i in 3:await process_frame
 gate.path_field.text=original
 var entry:Dictionary=Starts.manifest().entries.filter(func(e):return e.id=="act2-l13")[0]
 if not require(Starts.file_error(entry).is_empty(),"Pinned canonical C15 Citadel input is staged"):return false
 await tap(KEY_F2)
 for i in 40:
  var focus:Control=root.gui_get_focus_owner()
  if focus!=null and str(focus.name)=="Start_act2-l13":break
  await tap(KEY_TAB if focus==null else KEY_DOWN)
 var focus:Control=root.gui_get_focus_owner()
 if not require(focus!=null and str(focus.name)=="Start_act2-l13","Real keyboard selects Citadel F2 row"):return false
 await picture("f2_start")
 await tap(KEY_ENTER)
 for i in 3000:
  await process_frame
  if current_scene!=gate and is_instance_valid(current_scene) and current_scene.get("ready_for_review")==true:break
 await adopt()
 if not captured():await lclick();await frames(4)
 if not require(area=="L13_RC" and scene.resets==0 and hp()>0 and captured(),"Living walking Citadel start, ordinary capture"):return false
 if not require(not scene.development_mode and not scene.starting_magic.interface_request and not scene.adapter_exit_seeds,"Production input without preview seeds or test bypass"):return false
 receipts.append({"start":"act2-l13","sha256":entry.sha256,"health":hp(),"position":str(pos()),"clock":[Engine.time_scale,Engine.physics_ticks_per_second]})
 return true

func source_route(name:String)->Array:return fixture(name).points
func get_lower()->bool:
 if not await walk(source_route("l13_egg_door_walk.json"),"Grok egg globe"):return false
 await tap(KEY_1)
 await act(Vector3(-3254,43.5,5330),"Spark original globe420",KEY_Q)
 if not require(scene.get_node("L13EggDoor").state().opened,"ActualQ opens original egg door106"):return false
 if not await walk([[-3320,5500],[-3320,5200],[-3260,5000],[-3260,4800]],"Grok open egg doorway"):return false
 if not await walk(source_route("l13_basin_walk.json"),"Grok eye approach"):return false
 await act(Vector3(-3270,-26.5,4210),"Use original eye switch")
 if not require(scene.get_node("L13Eggs").state().eye_open,"ActualE opens original irises107/108"):return false
 if not await walk([[-3100,4210],[-2900,4210],[-2650,4210],[-2460,4210]],"Grok egg chamber"):return false
 await act(Vector3(-2171,166,4165),"Spark original egg vent",KEY_Q)
 if not require(scene.get_node("L13Eggs").state().vent_broken,"ActualQ breaks original vent"):return false
 if not await walk(source_route("l13_elevator_walk.json"),"Grok elevator approach"):return false
 var lift:Node=scene.get_node("L13Elevator")
 await act(lift.aim(),"Spark original elevator",KEY_Q)
 if not require(lift.state().started,"ActualQ starts native elevator"):return false
 for tick in 6400:
  if lift.state().motion.remaining==0:break
  await physics_frame
 if not require(lift.state().motion.remaining==0 and absf(float(lift.state().motion.height)+1040)<1,"Actual cab reaches lower native landing"):return false
 if not await walk([[-4860,3090],[-4860,2820],[-4839,2600],[-4839,2240]],"Grok lower landing"):return false
 if not await checkpoint("g03_l13_lower_f5"):return false
 await picture("lower_checkpoint")
 return true
const LOWER_INPUT:="res://tmp/g03_l13_inputs/lower_f5.json"
const LOWER_SHA:="56c0bad83be98816fc07371c888ec8fca02dfcba8580b8c042e5ec75c0957407"
func proof_phase()->String:return "stairs"
func restore_lower()->bool:
 if not require(FileAccess.get_sha256(LOWER_INPUT)==LOWER_SHA,"Untouched real-input lowerF5 pin"):return false
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(LOWER_INPUT,Slots.slot_path(1))==OK,"Install untouched game-written lowerF5 for actualF9"):return false
 await tap(KEY_F9);await adopt()
 return require(area=="L13_RC" and scene.resets==0 and hp()>0 and scene.player.is_on_floor(),"Living actualF9 lower checkpoint")
func vault_stand()->bool:
 if not await walk(source_route("l13_prison_walk.json").slice(0,5),"Grok vault corridor"):return false
 return await walk([[-4593,1741]],"Grok exact vault stand")
func vault_proof()->bool:
 if not await vault_stand():return false
 await look(Vector3(-4534,-995.5,1767));await picture("vault_before")
 var native=scene.progression.native
 var travel_before:int=native.field("movable:84",native.FIELD_TRAVEL,0)
 var closed:Transform3D=scene.progression.hinges[84].transform
 await tap(KEY_E);await ticks(90);await picture("vault_after")
 var travel_after:int=native.field("movable:84",native.FIELD_TRAVEL,0)
 print("PROP250 actualE native travel before=",travel_before," after=",travel_after," byte25=",native.field("prop:250",native.FIELD_BYTE25,0))
 if not require(travel_after==95 and travel_after!=travel_before,"ActualE dispatches prop250 and native84 reaches source angle95"):return false
 var opened:Transform3D=scene.progression.hinges[84].transform
 if not require(not opened.is_equal_approx(closed),"Actual native84 geometry moves, not just a flag"):return false
 if not await checkpoint("g03_vault_open"):return false
 await tap(KEY_F9);await adopt();await ticks(150)
 native=scene.progression.native
 print("VAULT F9 byte25=",native.field("prop:250",native.FIELD_BYTE25,0)," travel=",native.field("movable:84",native.FIELD_TRAVEL,0)," physical target delta=",scene.progression.hinges[84].transform.origin.distance_to(scene.progression.mover_targets[84].origin))
 if not require(native.field("movable:84",native.FIELD_TRAVEL,0)==95 and native.field("prop:250",native.FIELD_BYTE25,0)==1 and scene.progression.hinges[84].transform.origin.distance_to(scene.progression.mover_targets[84].origin)<0.5 and scene.progression.hinges[84].transform.basis.get_rotation_quaternion().angle_to(scene.progression.mover_targets[84].basis.get_rotation_quaternion())<0.005,"RealF9 preserves both native switch state and physical open vault pose"):return false
 await tap(KEY_E);await ticks(3)
 if not require(native.field("prop:250",native.FIELD_BYTE25,0)==1 and native.field("movable:84",native.FIELD_TRAVEL,0)==95,"Busy native predicates refuse another E without inventing a phase"):return false
 if not await restore_lower():return false
 if not require(scene.progression.native.field("prop:250",scene.progression.native.FIELD_BYTE25,0)==0 and scene.progression.native.field("movable:84",scene.progression.native.FIELD_TRAVEL,0)==travel_before,"Earlier realF9 restores the closed pre-click world"):return false
 if not await vault_stand():return false
 await look(scene.camera.global_position+Vector3(-200,200,0));await lclick()
 if not require(scene.interface_hud.attack_swing.icon.visible and scene.progression.native.field("prop:250",scene.progression.native.FIELD_BYTE25,0)==0,"Off-target real left-click still attacks and leaves switch untouched"):return false
 await ticks(60)
 await look(Vector3(-4534,-995.5,1767));await lclick()
 if not require(not scene.interface_hud.attack_swing.icon.visible and scene.progression.native.field("prop:250",scene.progression.native.FIELD_BYTE25,0)==1,"Aimed real left-click uses prop250 before the attack"):return false
 await ticks(90);await picture("vault_left_click")
 return require(scene.progression.native.field("movable:84",scene.progression.native.FIELD_TRAVEL,0)==95,"Left-click follows the same native opener path as E")
func main():
 use_guard=false
 if not await start_from_f2():return
 var phase:String=OS.get_environment("LOL2_L13_PHASE")
 if phase.is_empty():phase=proof_phase()
 print("G03 PHASE ",phase)
 if phase=="capture":
  if not await get_lower():await picture("stop_lower");quit(1);return
 else:
  if not await restore_lower():return
 if phase=="capture":print("PASS actualF2/globe/eye/vent/elevator/W lower landing/F5 only, ordinary1/60, resets0");quit();return
 if phase=="vault":
  if not await vault_proof():return
 elif phase=="chord":
  if not await walk([[-4882.29,1993.52],[-4806.46,1942.05],[-4770,1870]],"Grok direct approach"):quit(1);return
  if not await walk([[-4947,1707]],"Grok wrong-height chord"):await picture("red_chord");quit(1);return
  await ticks(120);await picture("red_chord")
  if not require(scene.player.is_on_floor() and pos().y>-910 and scene.resets==0,"Original robot chord reaches the native upper floor"):return
 else:
  if not await walk([[-4882.29,1993.52],[-5000,1930],[-5070,1840],[-5090,1770],[-5050,1790],[-4970,1805],[-4904,1800],[-4873,1757],[-4860,1710],[-4872,1683]],"Native teleporter stair strips"):await picture("stop_stairs");quit(1);return
  if not require(scene.player.is_on_floor() and pos().y>-910,"Native stairs reach upper pad floor without recovery"):return
  await picture("upper_stairs")
  if not await checkpoint("g03_l13_upper_f5"):return
  if not await walk([[-4955,1711]],"Actual step onto control53",{"until":func():return pos().x>-4000}):await picture("stop_pad");quit(1);return
  await ticks(60)
  if not require(Vector2(pos().x+3258,pos().z-5589).length()<12 and absf(pos().y-32)<2 and scene.player.is_on_floor(),"Actual step-on runs native group8134 and lands on original upper floor0"):await picture("red_unhosted_pad");return
  await picture("native_pad_landing")
  if not await checkpoint("g03_native_pad_landing"):return
  await tap(KEY_F9);await adopt();await ticks(30)
  if not require(Vector2(pos().x+3258,pos().z-5589).length()<12 and absf(pos().y-32)<2 and scene.player.is_on_floor(),"RealF9 keeps the native teleporter landing living and grounded"):return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Real-input L13 stop proof remains living without recovery/stall"):return
 print("PASS real-input G03 L13 ",phase," ordinary1/60 resets0")
 quit()
