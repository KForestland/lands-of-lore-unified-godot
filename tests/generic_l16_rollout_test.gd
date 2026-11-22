extends "res://tests/generic_l9_rollout_test.gd"
## Rendered City components. Supplied clear grounded stands, held root/NPC
## clocks; real E/left/F5/F9, pinned earned C15. No earned-route claim.
func point_for(id:int)->Vector3:
 if scene.progression.hinges.has(id):return scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
 var bounds:=AABB();var first:=true
 for face in pack.faces:
  if face.get("placement_kind")=="movable" and int(face.get("source_index",-1))==id:
   for point in face.points:
    var v:=Vector3(point[0],point[1],point[2])
    if first:bounds=AABB(v,Vector3.ZERO);first=false
    else:bounds=bounds.expand(v)
 return bounds.get_center()
func boot(file:String,input:String,sha:String,format:String)->bool:
 if not await super.boot(file,input,sha,format):return false
 # Both untouched City checkpoints were written during the timed Beast curse.
 # Leave the real player/curse clock live while idle; never assign a form.
 if scene.player_form!=0:
  scene.set_physics_process(true)
  for tick in 60*180:
   await physics_frame
   if scene.player_form==0 and int(scene.curse.state.phase)==0:break
  scene.set_physics_process(false)
 return check(scene.player_form==0 and scene.player.is_on_floor() and scene.resets==0,"Original curse expires naturally on the grounded arrival before Human-only use")
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered G03 City components at ordinary1/60"):return
 folder="user://tests/generic_l16_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L16_CA.tscn","res://tests/fixtures/g03_l16_ground_b387ca96.json","b387ca96a3d514bcfb6e16dc3d7fea37883f2724ec506baa5fec1d985aef844a","lol2-restoration-map-L16_CA"):return
 if not check(not Catalog.movables("L16_CA").has(103),"Existing dragon-mouth collision adapter retains exclusive103 ownership"):return
 for id in [0,53,74]:
  var point:=point_for(id)
  if not await vantage(id,point):return
  var before:=state(id)
  if id==53:await click()
  else:await key(KEY_E)
  for tick in 180:await physics_frame
  if not check(int(state(id)[Rules.POSITION])>int(before[Rules.POSITION]) and int(state(id)[Rules.PHASE])==1,"Real E/left completes published motion%d"%id):return
  receipts.append({"id":id,"state":state(id),"stand":str(scene.player.position),"input":"left" if id==53 else "E"})
  await shot("open%d"%id)
 await key(KEY_F5)
 if not await load_slot():return
 for row in receipts:
  if not check(motion_matches(int(row.id),row.state),"F9 restores exact generic motion%d"%int(row.id)):return
 if not check(scene.resets==0,"No recovery in grounded City components"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS G03 L16 three rendered real-input source movers and F5/F9; supplied grounded stands, not earned walking")
 quit()
