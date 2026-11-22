extends "res://tests/g04_floor_input_test.gd"
## Supplied local L9 stand/unlocked selector; actual E/F5/F9. Hold new mover
## before its first tick to distinguish restored position from re-opening.
const Area=preload("res://scripts/lol2/act2_save.gd")
const REF:="movable:115"
var hold_new:=false
var holds:=0
func freeze_ready(node:Node):node.set_physics_process(false);holds+=1
func arrived(node:Node):
 if hold_new and node.get_script()!=null and node.get_script().resource_path=="res://scripts/lol2/act2_progression.gd":node.ready.connect(freeze_ready.bind(node),CONNECT_ONE_SHOT)
func run():
 node_added.connect(arrived)
 scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene;await settled()
 var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/L9_DR.json"))
 state.player.position=[-1387,52,-8516]
 if not check(scene.apply_save(state).is_empty(),"Supplied original local door checkpoint applies"):return
 scene.progression.native.set_field(REF,"byte_0x25",1) # Explicit unlocked-door prerequisite fixture.
 await look(scene.progression.movable_position(115));await ticks(2)
 if not check(scene.progression.aimed()==115,"Actual aim selects native door115"):return
 await key(KEY_E);await ticks(5);scene.progression.set_physics_process(false)
 var saved_pose:Transform3D=scene.progression.hinges[115].transform
 if not check(not saved_pose.is_equal_approx(Transform3D(Basis(),scene.progression.hinge_origin[115])) and not saved_pose.is_equal_approx(scene.progression.mover_targets[115]),"RealE produced an actual mid-motion door position"):return
 await key(KEY_F5);await ticks(2)
 var read:=Saves.read_document(Saves.slot_path(1))
 if not check(read.error.is_empty(),"ActualF5 captures mid-motion door checkpoint"):return
 hold_new=true
 if not await reload():return
 if not check(holds==1 and not scene.progression.is_physics_processing(),"New mover is really held before first tick"):return
 var actual:Transform3D=scene.progression.hinges[115].transform
 print("G04 mid-door expected=",saved_pose," restored=",actual," target=",scene.progression.mover_targets[115])
 if not check(actual.is_equal_approx(saved_pose),"F9 restores physical mid-motion door instead of restarting it at closed"):return
 var body:AnimatableBody3D=scene.progression.mover_bodies[115]
 var physics:Transform3D=PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
 if not check(physics.is_equal_approx(body.global_transform),"Restored moving door collision agrees with drawn pose"):return
 print("PASS G04 realE/F5/F9 exact mid-motion native door and physical collision; local stand/unlock/clock holds disclosed")
 quit()
