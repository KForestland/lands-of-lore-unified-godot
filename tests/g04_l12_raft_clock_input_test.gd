extends "res://tests/g04_floor_input_test.gd"
## Autonomous real play clock + W/F5/F9; stop the raft only at capture/restore
## boundaries so exact phase can be compared before another engine tick.
var hold_new_raft:=false
var new_holds:=0
func node_arrived(node:Node):
 if hold_new_raft and node.name=="L12RiverRafts":node.ready.connect(hold_ready.bind(node),CONNECT_ONE_SHOT)
func hold_ready(node:Node):
 node.set_physics_process(false);new_holds+=1
func run():
 node_added.connect(node_arrived)
 scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 var raft:Node=scene.get_node("L12RiverRafts");var initial:float=raft.state().distance
 scene.set_physics_process(true)
 var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events();await ticks(24)
 event=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=false
 Input.parse_input_event(event);Input.flush_buffered_events();await ticks(3)
 scene.set_physics_process(false)
 if not check(float(raft.state().distance)>initial+40,"Autonomous raft advances during actual W/play ticks"):return
 raft.set_physics_process(false)
 await key(KEY_F5);await ticks(2)
 var saved:=Saves.read_document(Saves.slot_path(1))
 if not check(saved.error.is_empty(),"Real F5 saves live raft phase"):return
 var expected:Dictionary=saved.state.area_save.quests.l12_river_rafts
 var boats:Array=[]
 for boat in raft.boats:boats.append(boat.transform)
 hold_new_raft=true
 if not await reload():return
 raft=scene.get_node("L12RiverRafts")
 print("G04 raft saved=",expected," restored=",raft.state()," new_holds=",new_holds," processing=",raft.is_physics_processing())
 if not check(new_holds==1 and not raft.is_physics_processing(),"Exact-phase fixture really holds the new raft before its first tick"):return
 if not check(float(raft.state().distance)==float(expected.distance),"F9 retains exact raft phase before next tick"):return
 for i in boats.size():
  if not check(raft.boats[i].transform.is_equal_approx(boats[i]),"Every restored raft mesh/collision uses saved phase "+str(i)):return
 if not check(scene.resets==0 and scene.starting_magic.health()>0,"Living raft-clock continuation"):return
 print("PASS G04 L12 actualW/autonomous clock/F5/F9 preserves exact raft phase and all three physical transforms; capture/restore clock holds disclosed")
 quit()
