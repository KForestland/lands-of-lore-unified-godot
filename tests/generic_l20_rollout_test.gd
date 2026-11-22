extends "res://tests/generic_l9_rollout_test.gd"
## Rendered local class-C components. Supplied clear grounded stands, held
## NPC/root clocks and manually advanced melee cooldown only. No earned route.
var last_aim:=Vector3.ZERO
const Combat=preload("res://scripts/lol2/player_combat.gd")
func life(id:int)->int:return scene.progression.native.field("prop:%d"%id,scene.progression.NativeHost.FIELD_BYTE26,0)
func prop_stand(id:int)->bool:
 var world:Node=scene.get_node("GenericObjects")
 var view:Node3D=world.prop_views[id]
 var row:Dictionary=view.pack.selectors["%d:%d"%[view.template,view.selector]]
 var point:Vector3=view.global_position+Vector3.UP*(float(row.bottom)+(float(row.state_height)-float(row.top_trim)-float(row.bottom))*0.25)
 for radius in [24.0,32.0,48.0,64.0,80.0,100.0,120.0]:
  for direction in 24:
   var side:Vector3=point+Vector3(sin(direction*TAU/24),0,cos(direction*TAU/24))*radius
   var ray:=PhysicsRayQueryParameters3D.create(side+Vector3.UP*10,side-Vector3.UP*240,1|256,[scene.player.get_rid()])
   var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   if floor_hit.is_empty() or floor_hit.normal.y<0.7:continue
   var at:Vector3=floor_hit.position+Vector3.UP*32.05
   if not free_at(at):continue
   if not await pose(at,point):return false
   if not player_clear():continue
   await aim(point)
   var target:Dictionary=world.aimed()
   if target.get("kind")=="cover" and int(target.get("id",-1))==id and target.get("prop",false):
    last_aim=point
    print("G03 L20 PROP ",id," stand=",scene.player.position," aim=",point);return true
 return check(false,"Clear grounded visible class-C prop%d"%id)
func cool_melee():
 # NPC motion/attacks remain held in these supplied stands. This explicit
 # clock aid advances only the existing strike lock at the actual frame rate.
 for tick in 30:
  await physics_frame
  scene.act2_creatures.strike_remaining=Combat.cooldown_tick(scene.act2_creatures.strike_remaining,1.0/60.0)
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary L20 component clock"):return
 folder="user://tests/generic_l20_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L20_BB.tscn","res://assets/lol2/generated/playtest_starts/c15_l20_bb.json","576d17bb004fd11521770ffbc6a125cb6925806df508442c3ab44c7e408a43e5","lol2-restoration-map-L20_BB"):return
 var world:Node=scene.get_node("GenericObjects")
 if not check(world.prop_views.size()==6 and world.cover_bodies.is_empty(),"All six original props bound without L10 cover bodies"):return
 for id in [144,145,153]:
  if not await prop_stand(id):return
  var before:int=life(id)
  await click();await cool_melee()
  if not check(life(id)<before,"Actual left reduces native prop durability%d"%id):return
  if id==144:
   for strike_index in 80:
    if life(id)<=0:break
    await click();await cool_melee()
   if not check(life(id)==0,"Actual repeated strikes cross original threshold1"):return
   var fired:Array=scene.progression.route_log.filter(func(row):return row.object=="prop:144" and int(row.event)==9)
   if not check(fired.size()==1 and fired[0].results.any(func(row):return row.get("status")=="ran" and int(row.get("group",-1))==4902),"Original full threshold group4902 runs once"):return
   if not check(world.prop_views[id].mesh.visible and world.prop_views[id].selector==0,"No invented terminal hide or broken selector at zero prop life"):return
  receipts.append({"id":id,"life":life(id),"selector":world.prop_views[id].selector,"stand":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"aim":[last_aim.x,last_aim.y,last_aim.z],"input":"left"})
  await shot("struck%d"%id)
 var release:int=scene.progression.native.field(scene.progression.NativeHost.PLAYER_REF,"released_by",-1)
 await key(KEY_F5)
 if not await load_slot():return
 world=scene.get_node("GenericObjects")
 for row in receipts:
  var id:int=int(row.id)
  if not check(life(id)==int(row.life) and world.prop_views[id].selector==int(row.selector) and world.prop_views[id].mesh.visible,"F9 preserves prop life/art%d without replay"%id):return
 if not check(scene.progression.native.field(scene.progression.NativeHost.PLAYER_REF,"released_by",-1)==release and not scene.progression.route_log.any(func(row):return row.object in ["prop:144","prop:145","prop:153"] and int(row.event)==9),"F9 keeps native release field without replaying strike groups"):return
 if not check(scene.resets==0,"Grounded L20 components never recover a fall"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS L20 three rendered real-left class-C props, full threshold1, exact prop-class F5/F9 and original artwork; local stand/cooldown aids")
 quit()
