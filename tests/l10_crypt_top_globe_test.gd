extends "res://tests/generic_prop_input_test.gd"
## OF5 component updated for G02: reported crypt83 has no globe but IS a
## decoded click-bit lid. Globe55 is underneath separate movable51.
## Supplied settled component vantages/NPC hold are disclosed, not earned walking.
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered crypt/globe component"):return
 folder="user://tests/l10_crypt_top_globe";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 var point:Vector3=scene.progression.hinges[83].global_transform*scene.progression.mover_bounds[83].get_center()
 if not await pose(Vector3(1358.23,22.04,-1269.01),point):return
 var nearest:=INF
 for id in scene.act2_items.sprites:
  if str(id).begins_with("act2:L10_DC:") and int(scene.act2_items.rows[id].definition)==98:nearest=minf(nearest,scene.camera.global_position.distance_to(scene.act2_items.aim_point(id)))
 if not check(nearest>400,"Reported crypt83 has no placed empty globe"):return
 var before:Transform3D=scene.progression.hinges[83].transform
 if not await action(83):return
 for tick in 90:await physics_frame
 if not check(scene.progression.hinges[83].position.distance_to(before.origin)>1,"ActualE moves source click-bit lid83 despite its empty event list"):return
 var globe:="act2:L10_DC:item55"
 point=scene.progression.hinges[51].global_transform*scene.progression.mover_bounds[51].get_center()
 if not await pose(Vector3(1320,42.05,-1854),point):return
 await aim(scene.act2_items.aim_point(globe))
 if not check(not scene.act2_items.available(globe),"Closed lid51 occludes globe55; no through-lid take"):return
 if not await action(51):return
 for tick in 120:await physics_frame
 # The south floor gives a real under-lid ray; the old east stand hits51.
 if not await pose(Vector3(1272,32.05,-1930),scene.act2_items.aim_point(globe)):return
 scene.set_physics_process(true)
 var crouch:=InputEventKey.new();crouch.keycode=KEY_C;crouch.physical_keycode=KEY_C;crouch.pressed=true
 Input.parse_input_event(crouch);Input.flush_buffered_events()
 for tick in 12:await physics_frame
 if not check(scene.crouched,"Actual heldC crouches under the raised crypt lid"):return
 await aim(scene.act2_items.aim_point(globe))
 print("GLOBE55 open51 available=",scene.act2_items.available(globe)," stand=",scene.player.position," generic=",scene.get_node("GenericObjects").aimed())
 await key(KEY_E)
 crouch.pressed=false;Input.parse_input_event(crouch);Input.flush_buffered_events()
 if not check(globe in scene.carried_collected,"ActualE takes55 after opening its own lid51"):return
 if not check(scene.resets==0 and scene.starting_magic.health()>0,"Crypt component finishes living without recovery"):return
 await shot("globe55_after_lid51")
 print("PASS OF5 component: crypt83 opens by actualE and has no globe; old east ray hits51; actualE opens51, heldC and actualE take55 from clear south floor; disclosed grounded vantages,0resets")
 quit()
