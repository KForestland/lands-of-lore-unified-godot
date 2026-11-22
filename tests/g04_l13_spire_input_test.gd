extends "res://tests/g04_floor_input_test.gd"
## Local held view/stand vectors; actual Q/F5/F9, not an earned route.
const Combat=preload("res://scripts/lol2/player_combat.gd")
func run():
 scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 var arrival:Vector3=scene.player.position;var spires:Node=scene.get_node("L13Spires");var id:=170
 var point:Vector3=spires.aims[id];var found:=false
 for direction in 16:
  var offset:=Vector3(sin(direction*TAU/16)*96,0,cos(direction*TAU/16)*96)
  scene.player.position=point+offset-scene.camera.position;scene.player.velocity=Vector3.ZERO
  await look(point);await ticks(2)
  var hit:Dictionary=Combat.aim_ray(scene,512,1)
  if not hit.is_empty() and hit.collider==spires.receivers[id]:found=true;break
 if not check(found,"Actual crosshair sees original spire170 receiver"):return
 await key(KEY_1);await key(KEY_Q);await ticks(3)
 if not check("170" in spires.state().lit and spires.visuals[id].visible and scene.progression.native.locals.get(16,0)==1,"Real Q lights source spire, selector and local16"):return
 scene.player.position=arrival;scene.player.velocity=Vector3.ZERO;scene.set_physics_process(true)
 for i in 120:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 await key(KEY_F5);await ticks(2)
 var saved:=Saves.read_document(Saves.slot_path(1))
 if not check(saved.error.is_empty() and "170" in saved.state.area_save.quests.l13_spires.lit,"Actual F5 records lit spire"):return
 if not await reload():return
 spires=scene.get_node("L13Spires")
 if not check("170" in spires.state().lit and spires.visuals[id].visible and spires.receivers[id].collision_layer==0 and scene.progression.native.locals.get(16,0)==1,"F9 retains lit visual, receiver and script local without replaying Spark"):return
 print("PASS G04 L13 realQ/F5/F9 keeps original spire170 lit selector/receiver/local16; supplied held view/stand, no earned claim")
 quit()
