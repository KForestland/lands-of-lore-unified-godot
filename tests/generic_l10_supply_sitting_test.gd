extends "res://tests/generic_l10_bracers_return_test.gd"
## Continue the realF5 after gold91; test the ordinary crouch/side pickup.
const GOLD91_INPUT:="res://tmp/generic_l10_inputs/generic_l10_gold91.json"
const GOLD91_PIN:="459543b2b44d0baba280471b3622e8fa788596cd4acb0e37ad0d15ce372bda47"
func actual_contact_clear()->bool:
 var collider:CollisionShape3D=scene.player.get_child(0)
 var shape:Shape3D=collider.shape.duplicate();shape.height-=0.1
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
 query.transform=collider.global_transform;query.transform.origin.y+=0.05
 query.collision_mask=scene.player.collision_mask;query.exclude=[scene.player.get_rid()]
 var hits:Array=scene.get_world_3d().direct_space_state.intersect_shape(query)
 if not hits.is_empty():print("RELOAD CONTACT overlaps=",hits," pose=",pos())
 return hits.is_empty()
func main():
 if not await start_from_f2():return
 if not require(FileAccess.get_sha256(GOLD91_INPUT)==GOLD91_PIN,"Untouched earned gold91 F5 pin"):return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(GOLD91_INPUT,Slots.slot_path(1))==OK,"Install untouched gold91 actualF5"):return
 var old:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt()
 if not require(scene.get_instance_id()!=old and area=="L10_DC" and hp()>0,"RealF9 resumes actual opened gold91"):return
 var supply:Dictionary=fixture("l10_two_empty_walk.json")
 if not await walk(supply.lid.points,"crypt top67 and original empty56"):await picture("stop");quit(1);return
 var generic:Node=scene.get_node("GenericObjects")
 var point:Vector3=scene.progression.hinges[67].transform*scene.progression.mover_bounds[67].get_center()
 await act(point,"Open original crypt top67")
 await ticks(60)
 if not require(scene.progression.generic_contact_pauses.get(67,0)>0 and scene.progression.native.field("movable:67","state_0x55",0)==2,"The moving crypt top pauses before squeezing the standing body"):return
 if not require(pos().y>=31.8,"The moving cover preserves the actual floor contact"):return
 if not require("hold C" in generic.hint.text,"An aimed blocked mover gives actionable posture feedback"):return
 await look(scene.camera.global_position+Vector3(0,400,1));await frames(4)
 if not require(generic.aimed().get("id",-1)!=67 and "Step aside" in generic.pause_hint.text and generic.pause_hint.is_visible_in_tree(),"Paused lid67 remains explained while the player looks away"):return
 await picture("crypt67_paused_lookaway")
 await look(point)
 print("CONTACT BEFORE SAVE pos=",pos()," collider=",scene.player.get_child(0).shape," height=",scene.player.get_child(0).shape.height," crouched=",scene.crouched," fit_active=",scene.body_fit.active)
 var saved_position:int=scene.progression.native.field("movable:67","position_0x48",0)
 if not await checkpoint("crypt67_blocked_safe"):return
 var prior_host:int=scene.get_instance_id()
 await tap(KEY_F9);await adopt();await ticks(30)
 if not require(scene.get_instance_id()!=prior_host and area=="L10_DC" and scene.resets==0 and hp()>0,"RealF9 restores the safe blocked motion into a new living host"):return
 print("CONTACT RELOAD height=",scene.player.get_child(0).shape.height," crouched=",scene.crouched," fit_active=",scene.body_fit.active," saved=",saved_position," actual=",scene.progression.native.field("movable:67","position_0x48",0)," phase=",scene.progression.native.field("movable:67","state_0x55",0)," pos=",pos())
 if not require(not scene.crouched and scene.player.get_child(0).shape.height==46.0 and scene.progression.native.field("movable:67","state_0x55",0)==2 and scene.progression.native.field("movable:67","position_0x48",0)>=saved_position and pos().y>=31.8 and actual_contact_clear(),"Reloaded motion remains blocked at safe contact after ordinary clock resumes"):return
 key_event(KEY_C,true);await ticks(6)
 if not require(scene.crouched,"Real held C crouches while approaching the low crypt cover"):return
 await ticks(60)
 if not require(scene.progression.native.field("movable:67","state_0x55",0)==1,"The same motion resumes and completes after actual crouch clears it"):return
 print("GL56 heldC stand=",pos()," eye=",scene.camera.global_position," pauses=",scene.progression.generic_contact_pauses.get(67,0))
 if not await take_item("act2:L10_DC:item56","original empty56 while crouched"):return
 key_event(KEY_C,false);await ticks(6)
 if not await walk(supply.free.points,"original loose globe8"):await picture("stop");quit(1);return
 if not await take_item("act2:L10_DC:item8","original empty8"):return
 if not await checkpoint("two_original_empty_globes"):return
 if not require(hp()>0 and scene.resets==0 and stops.is_empty(),"Real crouch/supply leg has no recovery or death"):return
 var f:=FileAccess.open("user://tests/generic_l10_sitting/supply_receipt.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"CONTINUATION ONLY; full fresh pilot outstanding","input_sha256":GOLD91_PIN,"receipts":receipts,"resets":scene.resets},"  "));f.close()
 print("PASS B realF9 gold91 -> actualW/Ecrypt67, heldC/Eoriginal56, W/Eoriginal8/F5; no supplied pose/health/clock/action handlers")
 quit()
