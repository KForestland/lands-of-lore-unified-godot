extends "res://tests/generic_l10_persistence_test.gd"
## Local rendered input ownership, not an earned walk. Genuine packet, two supplied poses and a passive input witness.
class AttackWitness extends Node:
 var clicks:=0
 func _unhandled_input(event:InputEvent):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:clicks+=1
func aim_point(point:Vector3):
 var offset:Vector3=point-scene.camera.global_position
 var yaw:=atan2(-offset.x,-offset.z);var pitch:=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var mouse:=InputEventMouseMotion.new();mouse.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/0.003,-(pitch-scene.camera.rotation.x)/0.003)
 Input.parse_input_event(mouse);Input.flush_buffered_events()
 for tick in 3:await physics_frame
func left():
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=Vector2(640,360)
  Input.parse_input_event(event);Input.flush_buffered_events();await physics_frame
func aura():
 await key(KEY_1)
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_Q;event.physical_keycode=KEY_Q;event.shift_pressed=true;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await physics_frame
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered cover input proof"):return
 folder="user://tests/generic_l10_cover";DirAccess.make_dir_recursive_absolute(folder)
 scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene
 for tick in 1800:
  await process_frame
  if scene.ready_for_review:break
 var input_path:="res://assets/lol2/generated/playtest_starts/c15_l10_dc.json"
 if not check(FileAccess.get_sha256(input_path)=="6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","Canonical C15 component input"):return
 var incoming:=AreaSave.read_save(input_path,"lol2-restoration-map-L10_DC")
 if not check(incoming.error.is_empty() and scene.apply_save(incoming.state).is_empty(),"Genuine packet supplies its actual carried/equipped sword"):return
 scene.act2_creatures.set_physics_process(false)
 if not await pose(Vector3(1283,32,-3290),Vector3(1283,39,-3368)):return
 var witness:=AttackWitness.new();scene.add_child(witness);scene.move_child(witness,0)
 await aim_point(scene.camera.global_position+Vector3(0,300,0.1));await left()
 if not check(witness.clicks==1,"Positive control: an ordinary sky click reaches the attack witness"):return
 for tick in 30:await physics_frame
 await aim_point(Vector3(1283,39,-3368))
 var swing:Node=scene.interface_hud.attack_swing
 var prior_swing:Tween=swing.swing_tween
 var target:Dictionary=scene.get_node("GenericObjects").aimed()
 if not check(target.get("kind")=="movable" and int(target.id)==107,"Chest107 really aimed before use"):return
 await key(KEY_C)
 if not check(int(state(107)[Rules.PHASE])==0,"C retains crouch binding; it does not use the chest"):return
 await left()
 if not check(swing.swing_tween==prior_swing,"A use click never starts the HUD attack animation"):return
 for tick in 60:await physics_frame
 if not check(int(state(107)[Rules.PHASE])==1 and witness.clicks==1,"Actual left click opens chest and does not reach attack dispatch"):return
 await shot("left_use_wins")
 # Opening must expose the original contents to a player, not only move a lid.
 # Approach the existing chest on W; keep its body/front collision intact.
 scene.set_physics_process(true)
 var globe:="act2:L10_DC:item48"
 await aim_point(scene.act2_items.aim_point(globe))
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events()
  if down:
   for tick in 45:await physics_frame
 await aim_point(scene.act2_items.aim_point(globe));await key(KEY_E)
 if not check(globe in scene.carried_collected,"RealW approach and E take original globe48 from opened chest107 at%s"%scene.player.position):return
 await shot("chest_contents_taken")
 if not await pose(Vector3(1191,32,-4020),Vector3(1191,70,-3956)):return
 scene.set_physics_process(true)
 if not check(absf(scene.player.position.y-32.0)<2.0,"Cover stand is actually on yard floor0, not below another roof"):return
 scene.act2_creatures.set_physics_process(true) # Preserve the real shared strike cooldown; no reset aid.
 await aura()
 var world:Node=scene.get_node("GenericObjects")
 var ref:="control:241";var changes:Array=[]
 var initial_life:int=scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_BYTE26,0)
 if not check(initial_life==100,"Cover241 starts at native100 life"):return
 for hit in 40:
  var old_cap:int=scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_BYTE26,0)
  if old_cap<=0:break
  for tick in 120:
   await physics_frame
   if scene.act2_creatures.strike_remaining<=0.0:break
  await aim_point(Vector3(1191,70,-3956))
  target=world.aimed()
  if target.get("kind")!="cover":
   var ray:Dictionary=scene.progression.PlayerCombat.aim_ray(scene,256.0,1|2)
   if not ray.is_empty():print("COVER_BLOCKER path=",ray.collider.get_path()," layer=",ray.collider.collision_layer," at=",ray.position," from=",scene.camera.global_position," target=",Vector3(1191,70,-3956)," meta=",ray.collider.get_meta_list())
  if not check(target.get("kind")=="cover" and int(target.id)==241,"Actual cover collider is selected before hit%d: %s"%[hit,target]):return
  var before_selector:int=scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_SELECTOR,0)
  var attacks_before:int=witness.clicks
  await left()
  var remaining:int=scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_BYTE26,0)
  if not check(hp_alive() and remaining<old_cap and remaining>=0,"Actual click applies positive clamped cover damage"):return
  if not check(witness.clicks==attacks_before,"Cover hit consumes only one attack input"):return
  var thresholds:Array=[]
  for record in scene.progression.native.object_records(ref):
   if int(record.kind)==9 and (int(record.bytes[9])&7)==3:thresholds.append(int(record.bytes[8]))
  var crossed:Array=Rules.crossed_thresholds(old_cap,remaining,thresholds)
  var expected_selector:int=before_selector
  for threshold in crossed:
   for record in scene.progression.native.object_records(ref):
    if int(record.kind)!=9 or (int(record.bytes[9])&7)!=3 or int(record.bytes[8])!=threshold:continue
    for command in scene.progression.native.groups[scene.progression.NativeHost.group_key(int(record.stream),int(record.group))]:
     if int(command.opcode)==5 and int(command.target)==241:expected_selector=int(command.bytes[4])
  var actual_selector:int=scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_SELECTOR,0)
  if not check(actual_selector==expected_selector,"Every crossed native group runs in sequence"):return
  if remaining==0:expected_selector=3
  if not check(int(world.cover_modes[241])==expected_selector,"Terminal frame or native damage selector is visible"):return
  if not check((world.cover_bodies[241].collision_layer==0)==(remaining==0),"Only zero life releases the physical front"):return
  changes.append({"old_cap":old_cap,"remaining":remaining,"selector":actual_selector,"visible_selector":expected_selector,"crossed":crossed})
  await shot("cover_hit%d"%hit)
  if hit==0:
   for tick in 120:
    await physics_frame
    if scene.player.is_on_floor():break
   await key(KEY_F5)
   var saved:=slot_packet()
   if not check(int(saved.quests.generic_objects.areas.L10_DC.breakables["241"].life)==remaining,"RealF5 records struck life"):return
   if not await load_slot():return
   world=scene.get_node("GenericObjects")
   witness=AttackWitness.new();scene.add_child(witness);scene.move_child(witness,0)
   if not check(scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_BYTE26,0)==remaining and int(world.cover_modes[241])==actual_selector,"FreshF9 restores struck life and frame without replay"):return
   scene.act2_creatures.set_physics_process(true)
   scene.set_physics_process(true)
 if not check(scene.progression.native.field(ref,scene.progression.NativeHost.FIELD_BYTE26,1)==0 and scene.resets==0,"Repeated ordinary-clock strikes reach zero, no fall reset"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify({"component_only":true,"setup":"Canonical carried sword, two supplied poses, NPC clocks held only during use-priority case; live real strike cooldown for covers; passive unhandled-input witness","use_wins":true,"C_not_use":true,"cover":changes,"real_F5_F9":true,"resets":scene.resets},"  "));file.close()
 print("PASS B local rendered left use wins, C stays crouch; realW/E takes original globe48 from opened chest107; sword clicks damage native100-life cover with ordered threshold selectors and zero-life collision release and real cooldown; F5/F9 life/frame persist. Supplied poses, not earned walking.")
 quit()
func hp_alive()->bool:return scene.starting_magic.health()>0
