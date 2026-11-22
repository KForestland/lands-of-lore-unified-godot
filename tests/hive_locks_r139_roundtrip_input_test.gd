extends "res://tests/hive_locks_r139_input_test.gd"
## Actual owner E prefix/completion; real Hive/Jungle host transfer APIs with
## held scene clocks and two resident roots. Not a real-door/campaign walk.
func same(a:Variant,b:Variant)->bool:
 if (a is int or a is float) and (b is int or b is float):return float(a)==float(b)
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 return typeof(a)==typeof(b) and a==b
func transfer(hive:Node,jungle:Node,label:String)->bool:
 var owner:Node=hive.get_node("HiveDecodedLocks");var before:Dictionary=owner.checkpoint()
 var packet:Dictionary=JSON.parse_string(JSON.stringify(hive.area_handoff(),"",true,true))
 var error:String=jungle.apply_area_handoff(packet)
 if not check(error.is_empty(),"Jungle admits current Hive quest packet "+label+": "+error):return false
 var returned:Dictionary=JSON.parse_string(JSON.stringify(jungle.area_handoff(),"",true,true))
 if not check(same(returned.quests.get(owner.KEY),before),"Jungle retains unknown owner key value-for-value through JSON number normalization "+label):return false
 error=hive.apply_area_handoff(returned,false)
 if not check(error.is_empty() and owner.checkpoint()==before,"Hive round trip restores exact prefix/rise/VM without replay "+label+": "+error):return false
 return true
func run():
 if not await boot_review():return
 var hive:Node=scene;var owner:Node=scene.get_node("HiveDecodedLocks")
 await press_lock(116);await press_lock(116);owner.set_physics_process(false)
 if not check(owner.progress==2,"Real E produces source prefix2"):return
 scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);await settled()
 var jungle:Node=scene
 if not await transfer(hive,jungle,"progress2"):return
 scene=hive;current_scene=hive;scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 owner.set_physics_process(true)
 await press_lock(114);await press_lock(115);await ticks(10);owner.set_physics_process(false)
 if not check(owner.completed and owner.rise>0 and owner.rise<15,"Real E produces a live mid-rise checkpoint"):return
 if not await transfer(hive,jungle,"midrise"):return
 if not check(owner.sound_log.is_empty(),"Return restores state without re-firing native sound groups"):return
 print("PASS R139 actual E partial and mid-rise Hive->Jungle->Hive host transport, canonical serializer keys, exact native/rise preservation; two resident roots and held clocks disclosed, no earned real-door claim")
 quit()
