extends "res://tests/generic_l9_rollout_test.gd"
## Rendered Hidden Caverns components. Supplied clear grounded stands, held root/NPC
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
func run():
 if not check(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered G03 Hidden Caverns components"):return
 folder="user://tests/generic_l17_rollout";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L17_HC.tscn","res://assets/lol2/generated/playtest_starts/c15_l17_hc.json","678e3076befc3ff44ab183353448f1a664f99f900a33a14c8ad191622d411839","lol2-restoration-map-L17_HC"):return
 for id in [50]:
  var point:=point_for(id)
  if not await vantage(id,point):return
  var before:=state(id)
  if id==-1:await click()
  else:await key(KEY_E)
  for tick in 180:await physics_frame
  if not check(int(state(id)[Rules.POSITION])>int(before[Rules.POSITION]) and int(state(id)[Rules.PHASE])==1,"Real E/left completes published motion%d"%id):return
  if not check(scene.progression.route_log.any(func(row):return row.object=="movable:50" and int(row.event)==6),"Preserve the original source-control E caller20 alongside generic motion"):return
  receipts.append({"id":id,"state":state(id),"stand":str(scene.player.position),"input":"left" if id==-1 else "E"})
  await shot("open%d"%id)
 await key(KEY_F5)
 if not await load_slot():return
 for row in receipts:
  if not check(motion_matches(int(row.id),row.state),"F9 restores exact generic motion%d"%int(row.id)):return
 if not check(scene.resets==0,"No recovery in grounded Hidden Caverns components"):return
 var file:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"  "));file.close()
 print("PASS G03 L17 sole rendered real-input source movers and F5/F9; supplied grounded stands, not earned walking")
 quit()
