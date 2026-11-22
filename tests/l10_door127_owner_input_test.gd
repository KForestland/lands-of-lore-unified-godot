extends "res://tests/helpers/real_input_player.gd"
## Untouched owner F5, actual F9/W/E/F5; no supplied pose, health or clock.
const Save=preload("res://scripts/lol2/game_save.gd")
const INPUT="res://tests/fixtures/l10_door127_owner_20261115.json"
const PIN="afc5734e2ee34063a66374623f747a0a389ecfa68ab5675ca063b1f42ee47686"
func _initialize():main.call_deferred()
func require(ok:bool,text:String)->bool:
 if not ok:stop("door127",text);quit(1)
 return ok
func state(field:String)->int:return scene.progression.native.field("movable:127",field,-1)
func steady(opened:bool)->bool:
 for tick in 360:
  await physics_frame
  if state("state_0x55") in ([1] if opened else [0,5]):break
 return require(state("position_0x48")== (1073741824 if opened else 0),"Actual E completes the full published quarter-turn without a contact wedge")
func use_leaf(opened:bool,side:String)->bool:
 var p:Node=scene.progression
 var point:Vector3=p.hinges[127].global_transform*p.mover_bounds[127].get_center()
 if not await look(point):return require(false,"Actual mouse aims leaf from "+side)
 var aimed:Dictionary=scene.get_node("GenericObjects").aimed()
 if not require(aimed.get("kind")=="movable" and int(aimed.get("id",-1))==127,"Visible real leaf is usable from "+side):return false
 await tap(KEY_E)
 return await steady(opened)
func cross(x:float,label:String)->bool:
 if not await look(Vector3(x,scene.camera.global_position.y,-2464)):return false
 key_event(KEY_W,true)
 for tick in 240:
  await physics_frame
  if absf(pos().x-x)<4:break
 key_event(KEY_W,false);await frames(3)
 print("DOOR127_W ",label," position=",pos()," health=",hp()," resets=",scene.resets)
 return require(absf(pos().x-x)<6 and scene.resets==0 and hp()>0,"Real W crosses the opened passage "+label)
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1.0 and Engine.physics_ticks_per_second==60,"Rendered ordinary clock1/60"):return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Untouched owner bundle03-45-34 save"):return
 if not require(Save.load_file(self,INPUT).is_empty(),"Full owner save loader"):return
 await scene_changed;use_guard=false;await adopt()
 DirAccess.make_dir_recursive_absolute(Save.slot_path(1).get_base_dir())
 if not require(DirAccess.copy_absolute(INPUT,Save.slot_path(1))==OK,"Install untouched owner save in private slot1"):return
 await tap(KEY_F9);await adopt()
 if not captured():await lclick();await frames(3)
 if not require(state("state_0x55")==1 and state("position_0x48")==1073741824 and pos().distance_to(Vector3(-451.966247558594,32.0467338562012,-2463.53637695312))<1,"F9 preserves owner's body and already-open logical door state"):return
 var body:CollisionObject3D=scene.progression.mover_bodies[127]
 var layer:int=body.collision_layer
 if not require(layer!=0,"Open leaf remains solid"):return
 if not await cross(-553,"from owner's east stand"):return
 if not await use_leaf(false,"west close"):return
 if not require(scene.progression.hinges[127].transform.origin.is_equal_approx(scene.progression.hinge_origin[127]),"Closed leaf retains exact original source pose"):return
 if not await use_leaf(true,"west reopen"):return
 if not await cross(-452,"back east"):return
 if not await use_leaf(false,"east close"):return
 if not await use_leaf(true,"east reopen"):return
 if not require(body.collision_layer==layer,"Closing/reopening never disables leaf collision"):return
 var previous:String=FileAccess.get_sha256(Save.slot_path(1))
 await tap(KEY_F5)
 for tick in 1800:
  await process_frame
  if FileAccess.get_sha256(Save.slot_path(1))!=previous:break
 if not require(FileAccess.get_sha256(Save.slot_path(1))!=previous,"Actual F5 writes updated full world state"):return
 await tap(KEY_F9);await adopt()
 if not captured():await lclick();await frames(3)
 if not await cross(-553,"again after F5/F9"):return
 await look(Vector3(-495,scene.camera.global_position.y,-2443))
 await RenderingServer.frame_post_draw
 var folder:="user://tests/l10_door127/";DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder+"open_solid_leaf_passage.png")
 print("PASS owner127 unchanged F5 -> realF9/migrated open pose -> W passage -> E close/reopen from BOTH sides -> F5/F9 -> W repeated; solid leaf, original closed pose, ordinary1/60, zero resets, no pose/health/clock aids")
 quit()
