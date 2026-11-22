extends "res://tests/helpers/real_input_player.gd"
## Component replay of untouched robot area saves. Setup is disclosed; actions are real input.
const AreaSave=preload("res://scripts/lol2/act2_save.gd")
const SOCKET_INPUT:="res://tmp/generic_l10_inputs/generic_robot_socket158.json"
const SOCKET_PIN:="6b0efe3607f3f27777e674fbe2ab616d80b3de398627acdb63c783a806f27aa0"
func _initialize():main.call_deferred()
func check(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1)
 return ok
func boot(input:String,pin:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame
 if not check(FileAccess.get_sha256(input)==pin,"Untouched robot area-save input pin"):return false
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review:break
 var saved:=AreaSave.read_save(input,"lol2-restoration-map-L10_DC")
 if not check(saved.error.is_empty() and scene.apply_save(saved.state).is_empty(),"Actual game-written robot area-save fixture applies"):return false
 area="L10_DC";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 await ticks(4)
 return check(scene.resets==0 and hp()>0 and not scene.development_mode,"Live production walking context after disclosed fixture setup")
func main():
 if not check(DisplayServer.get_name()!="headless","Rendered socket replay"):return
 if not await boot(SOCKET_INPUT,SOCKET_PIN):return
 var tombs:Node=scene.get_node("L10Tombs")
 if not check(not tombs.opened("158") and tombs.bodies["158"].collision_layer!=0,"Saved socket158 and physical door159 begin closed"):return
 var body:StaticBody3D=tombs.bodies["158"]
 var normal:Vector3=body.global_basis.z.normalized()
 if (pos()-body.global_position).dot(normal)<0:normal=-normal
 var before_side:float=(pos()-body.global_position).dot(normal)
 await act(tombs.aims["158"],"ActualE socket158 from the robot's original approach")
 if not check(tombs.opened("158") and tombs.state().slots["158"].committed and body.collision_layer==0 and int(tombs.renderer.modes[159])==2,"ActualE commits158, selects original door159 open frame2 and clears its collision"):return
 var outside:Vector3=body.global_position+normal*65
 var inside:Vector3=body.global_position-normal*65
 if not await walk([[outside.x,outside.z],[inside.x,inside.z]],"physical crossing of opened159"):quit(1);return
 if not check((pos()-body.global_position).dot(normal)<-40 and scene.resets==0,"ActualW crosses the original door159 plane without a recovery"):return
 var dir:="user://tests/generic_l10_robot_checks";DirAccess.make_dir_recursive_absolute(dir)
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(dir+"/door159_crossed.png")
 var file:=FileAccess.open(dir+"/socket158.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"component from original robot save; apply_save/capture setup disclosed","input_sha256":SOCKET_PIN,"committed":tombs.opened("158"),"door159_selector":tombs.renderer.modes[159],"door159_collision":body.collision_layer,"side_before":before_side,"side_after":(pos()-body.global_position).dot(normal),"position":str(pos()),"resets":scene.resets},"  "));file.close()
 print("PASS robot158 replay: actualE commits socket158, original door159 frame2/collision0, actualW crosses its plane; tombs.panels is obsolete, use opened(158), bodies[158] and renderer.modes[159]")
 quit()
