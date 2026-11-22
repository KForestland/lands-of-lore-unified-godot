extends "res://tests/generic_l10_table_input_test.gd"
## Rendered components on the pinned earned C15 input, supplied clear grounded
## stands, held NPC/root clocks; real mouse/left/E/F5/F9. Not an earned route.
func item_owner(id:int)->Node:
 return scene.area_world_items if scene.area_world_items.sprites.has(id) else scene.act2_items
func identity(id:int)->String:
 return scene.area_world_items.id_of(id) if scene.area_world_items.sprites.has(id) else "act2:L8_SJ:item%d"%id
func item_point(id:int)->Vector3:
 return scene.area_world_items.aim_point(id) if scene.area_world_items.sprites.has(id) else scene.act2_items.aim_point(identity(id))
func target_matches(id:int)->bool:
 var owner:Node=item_owner(id)
 return owner.target()==id if owner==scene.area_world_items else owner.target()==identity(id)
func item_stand(id:int)->bool:
 var point:=item_point(id)
 for radius in [48.0,64.0,80.0,32.0]:
  for direction in 24:
   var side:Vector3=point+Vector3(sin(direction*TAU/24),0,cos(direction*TAU/24))*radius
   var query:=PhysicsRayQueryParameters3D.create(side+Vector3.UP*10,side-Vector3.UP*240,1|256,[scene.player.get_rid()])
   var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
   if floor_hit.is_empty() or floor_hit.normal.y<0.7:continue
   var at:Vector3=floor_hit.position+Vector3.UP*32.05
   if not free_at(at):continue
   if not await pose(at,point):return false
   if not player_clear():continue
   await aim(point)
   if target_matches(id):
    print("G03 L8 SAMPLE id=",id," stand=",scene.player.position," point=",point)
    return true
 return check(false,"Grounded visible original item%d within original pickup reach"%id)
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered G03 Savage Jungle components"):return
 folder="user://tests/generic_l8_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/darker_jungle.tscn","res://assets/lol2/generated/playtest_starts/c15_l8_sj.json","9606beab57fdb8d246e3f322ba328a1ae965dba1027dda7b4eef5cb55d4c6425","lol2-restoration-darker-jungle"):return
 if not check(scene.area_world_items.sprites.size()+scene.act2_items.sprites.size()==46,"All46 core pickup rows have exactly one live presentation owner"):return
 # Control token is an existing main-chain form teacher; the other two cover
 # both original pickup owners, including the owner's former duplicate eggs.
 for id in [31,20,44]:
  if id==44:
   # Original region1843 is floor-40/ceiling-8: the Lizard fits this
   #32-high source band. Use Control just learned from the actual token.
   await key(KEY_3)
   for down in [true,false]:
    var cast:=InputEventKey.new();cast.keycode=KEY_Q;cast.physical_keycode=KEY_Q;cast.ctrl_pressed=true;cast.pressed=down
    Input.parse_input_event(cast);Input.flush_buffered_events();await physics_frame
   if not check(scene.player_form==2,"Actual Ctrl+Q changes to Lizard for the source low band"):return
  if not await item_stand(id):return
  var before:int=scene.carried_collected.size()
  if id==44:await key(KEY_E)
  else:await click()
  if not check(identity(id) in scene.carried_collected and scene.carried_collected.size()==before+1,"Real left/E takes exactly one source item%d"%id):return
  if id!=44 and not check(not scene.interface_hud.attack_swing.icon.visible,"Aimed usable pickup wins over attack"):return
  receipts.append({"id":id,"identity":identity(id),"input":"E" if id==44 else "left","stand":str(scene.player.position)})
  await shot("taken%d"%id)
 if not check("curse3" in scene.starting_magic.magic_state().spellbook.learned,"Normal Control Token pickup still teaches its school"):return
 await key(KEY_F5)
 if not await load_slot():return
 for receipt in receipts:
  var id:int=int(receipt.id)
  if not check(scene.carried_collected.count(receipt.identity)==1,"F9 retains exactly one copy of%d"%id):return
  var owner:Node=item_owner(id)
  var sprite:Node3D=owner.sprites[id] if owner==scene.area_world_items else owner.sprites[receipt.identity]
  if not check(not sprite.visible,"F9 retains taken presentation of%d"%id):return
 if not check(20 in scene.area_world_items.collected and scene.resets==0,"Shared pickup history and no recovery retained"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS G03 L8 three rendered real-input pickups across both owners, usable left wins, normal Control teaching, exact F5/F9; supplied grounded stands, not earned walking")
 quit()
