extends "res://tests/generic_l10_persistence_test.gd"
## Rendered presentation component: pinned checkpoints, supplied grounded poses
## and held NPC/root clocks. Real E/Q/F5/F9; not the earned pilot sitting.
func aim(point:Vector3):
 var offset:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var mouse:=InputEventMouseMotion.new()
 mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events()
 for tick in 3:await physics_frame
func globe_colour(view:Node3D)->Color:
 await RenderingServer.frame_post_draw
 var image:Image=root.get_texture().get_image()
 var at:Vector2=scene.camera.unproject_position(view.global_position+Vector3(0,48,0))
 var result:=Color(0,0,0,0)
 for y in range(-2,3):
  for x in range(-2,3):result+=image.get_pixel(int(at.x)+x,int(at.y)+y)
 return result/25.0
func click():
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  event.position=Vector2(640,360);event.global_position=event.position
  Input.parse_input_event(event);Input.flush_buffered_events();await physics_frame
func boot(file:String,input:String,sha:String,format:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame
 scene=load(file).instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review:break
 if not check(FileAccess.get_sha256(input)==sha,"Pinned component input"):return false
 var read:=AreaSave.read_save(input,format)
 if not check(read.error.is_empty() and scene.apply_save(read.state).is_empty(),"Game-written component checkpoint applies"):return false
 scene.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 return true
func socket_vantage(tombs:Node,id:String)->bool:
 var point:Vector3=tombs.aims[id]
 for radius in [64.0,80.0,96.0,128.0]:
  for direction in 16:
   var side:Vector3=point+Vector3(sin(direction*TAU/16),0,cos(direction*TAU/16))*radius
   var query:=PhysicsRayQueryParameters3D.create(side+Vector3.UP*10,side-Vector3.UP*120,1|256,[scene.player.get_rid()])
   var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
   if floor_hit.is_empty() or floor_hit.normal.y<0.7:continue
   await pose(floor_hit.position+Vector3.UP*32.05,point)
   if tombs.target()==id:
    print("SOCKET VANTAGE ",id," stand=",scene.player.position," aim=",point);return true
 return check(false,"An actual grounded crosshair/LOS vantage must exist for socket"+id)
class EPassWitness extends Node:
 var presses:=0
 func _unhandled_input(event:InputEvent):
  if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:presses+=1
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered selector/input component"):return
 folder="user://tests/generic_prop_input";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 var charger:Node=scene.get_node("Act2Chargers")
 if not check(charger.selector_views.size()==2,"Both Cemetery chargers have original selector views"):return
 if not await pose(Vector3(1072,-125,-3485),scene.act2_items.aim_point("act2:L10_DC:item44")):return
 await key(KEY_E)
 if not check("act2:L10_DC:item44" in scene.carried_collected,"RealE takes the source empty globe"):return
 if not await pose(Vector3(1153,-125,-3553),charger.globes["L10:yellow"].global_position):return
 var charge_point:Vector3=charger.globes["L10:yellow"].global_position
 var offset:Vector3=charge_point-scene.camera.global_position
 var turned:Vector3=offset.rotated(Vector3.UP,0.4)
 await aim(scene.camera.global_position+turned)
 await click()
 if not check(not charger.globes["L10:yellow"].visible and scene.interface_hud.attack_swing.icon.visible,"A nearby charger off the crosshair does not steal an attack"):return
 await aim(charge_point)
 await click()
 if not check(charger.selector_views["L10:yellow"].selector==1 and charger.globes["L10:yellow"].visible,"Real left click selects original occupied charger artwork"):return
 await shot("charger_occupied")
 await key(KEY_F5)
 if not await load_slot():return
 charger=scene.get_node("Act2Chargers")
 if not check(charger.selector_views["L10:yellow"].selector==1,"F9 restores occupied artwork"):return
 await aim(charger.globes["L10:yellow"].global_position)
 await key(KEY_E)
 if not check(charger.selector_views["L10:yellow"].selector==3 and not charger.globes["L10:yellow"].visible,"RealE retrieval selects source empty-again artwork"):return
 await key(KEY_F5)
 if not await load_slot():return
 charger=scene.get_node("Act2Chargers")
 if not check(charger.selector_views["L10:yellow"].selector==3 and scene.carried_collected.count("act2:L10_DC:item44:charged:yellow")==1,"Retrieved frame and exactly one output survive F9"):return
 # R106: globe55 must stay takeable while socket158 is in use range.
 var tombs_before:Node=scene.get_node("L10Tombs")
 if not await pose(Vector3(1218,32,-1853),scene.act2_items.aim_point("act2:L10_DC:item55")):return
 if not check(not tombs_before.opened("158") and tombs_before.target().is_empty(),"Looking at globe55 does not target nearby socket158"):return
 var witness:=EPassWitness.new();scene.add_child(witness);scene.move_child(witness,0)
 var before_yellow:Array=scene.carried_collected.duplicate()
 var pickup:bool=scene.act2_items.available("act2:L10_DC:item55")
 print("SOCKET NEGATIVE item55 available=",pickup," actual target=",scene.act2_items.target()," generic ray=",scene.get_node("GenericObjects").aimed())
 await key(KEY_E)
 if not check(not tombs_before.opened("158") and scene.carried_collected==before_yellow and witness.presses==1,"An occluded globe does not let socket158 swallow E or spend a charged globe through a wall"):return
 if not await socket_vantage(tombs_before,"158"):return
 if not check(tombs_before.target()=="158","Actual crosshair selects socket158 before E"):return
 await key(KEY_E)
 if not check(tombs_before.opened("158") and tombs_before.bodies["158"].collision_layer==0 and int(tombs_before.renderer.modes[159])==2,"RealE spends the carried yellow globe only on aimed socket158, showing and clearing door159"):return
 await shot("socket158_door159")
 if not await boot("res://scenes/lol2/dragon_level.tscn","res://tmp/generic_l10_inputs/l9_tower_entry_earned_save.json","143201e6274bcd3fe99f79b37d2f5dbe42faf8f6da82de688ca6ab100adb02b3","lol2-restoration-dragon-preview"):return
 var tower:Node=scene.get_node("L9Tower");tower.set_physics_process(false)
 if not check(tower.selector_views.size()==4 and scene.get_node("Act2Chargers").selector_views.size()==1,"All five Ruins prop views attach"):return
 if not await pose(Vector3(-3620,32,-900),tower.aims["1090"]):return
 if not check(tower.selector_views["1090"].selector==0,"Orb starts with original dark selector"):return
 await shot("orb_dark")
 var dark:Color=await globe_colour(tower.selector_views["1090"])
 await key(KEY_1);await key(KEY_Q)
 for tick in 6:await physics_frame
 if not check("1090" in tower.state().orbs and tower.selector_views["1090"].selector==1 and tower.selector_views["1090"].mesh.visible,"RealQ selects original red orb, keeps the stand and opens its stair field"):return
 if not check(not tower.blocker.is_region_blocked(1171),"Actual Spark releases the original field regions"):return
 for tick in 60:await physics_frame
 await shot("orb_red")
 var red:Color=await globe_colour(tower.selector_views["1090"])
 print("Rendered globe sample dark=",dark," lit=",red)
 if not check(red.r>dark.r+0.2 and red.r>red.g*1.2 and red.g>0.15,"The actual rendered globe turns bright red, without a stale dark batch over it"):return
 await key(KEY_F5)
 if not await load_slot():return
 tower=scene.get_node("L9Tower")
 if not check(tower.selector_views["1090"].selector==1 and tower.selector_views["1090"].mesh.visible and not tower.blocker.is_region_blocked(1171),"F9 restores original red orb and open field"):return
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://tmp/generic_l10_inputs/l10_blue_return_earned_save.json","c208c0d1c8eac5d697fdd543a366dc467bfe41df815f64a250564bc38dd2405c","lol2-restoration-map-L10_DC"):return
 var tombs:Node=scene.get_node("L10Tombs")
 if not await pose(Vector3(2962,32,-3005),tombs.aims["154"]):return
 await key(KEY_E)
 if not check(tombs.opened("154"),"RealE offers the actually carried blue globe at154"):return
 var priest:Node=scene.get_node("L10Priest")
 if not await pose(Vector3(3336,32,-3010),priest.AIM):return
 var priest_offset:Vector3=priest.AIM-scene.camera.global_position
 await aim(scene.camera.global_position+priest_offset.rotated(Vector3.UP,0.4));await click()
 if not check(not priest.state().urn_given and scene.interface_hud.attack_swing.icon.visible,"A nearby priest off the crosshair does not steal an attack"):return
 await aim(priest.AIM);await click()
 if not check(priest.URN in scene.carried_collected and priest.state().urn_given,"Real left click speaks with the priest and grants his original urn"):return
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://tmp/generic_l10_inputs/l10_emperor_inner_earned_save.json","805015924528cfca48cd79bda00b0265179a6df531388169263db1908198696b","lol2-restoration-map-L10_DC"):return
 var emperor:Node=scene.get_node("L10Emperor")
 if not await pose(Vector3(3207,-17.954,-1270),emperor.AIMS.remains):return
 await aim(scene.camera.global_position+Vector3(0,200,0.1));await click()
 if not check(not emperor.room_active,"Looking away inside the room still attacks, rather than using the remains"):return
 await aim(emperor.AIMS.remains);await click()
 if not check(emperor.room_active and paused,"Real aimed left click opens the original Emperor room"):return
 await key(KEY_E)
 if not check(emperor.State.REMAINS in scene.carried_collected and not paused,"The modal's own realE takes the original remains"):return
 print("PASS B rendered E/left/Q/F5/F9 original charger0/1/3, L9 red orb/field, blue154/priest left urn and aimed Emperor left/modal E; pinned component fixtures and supplied poses, not earned chain")
 quit()
