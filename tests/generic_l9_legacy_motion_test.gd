extends SceneTree
## Isolated codec vectors on the actual binder/mesh/body; clock/VM vectors
## are declared test aids. Separate from the rendered E/left sample.
const World=preload("res://scripts/lol2/act2_world_checkpoint.gd")
const Rules=preload("res://scripts/lol2/generic_object_rules.gd")
func _initialize():run.call_deferred()
func run():
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 assert(scene.ready_for_review)
 scene.set_physics_process(false);scene.progression.set_physics_process(false);scene.act2_creatures.set_physics_process(false)
 var progression:Node=scene.progression
 var driver:Node=scene.get_node("GenericObjects")
 assert(progression.hinges.has(55) and not World.snapshot(progression).movers.has("55"),"Generic ownership emits exactly one canonical motion packet")
 var original:Dictionary=World.snapshot(progression)
 var legacy:Dictionary=original.duplicate(true)
 var expected:=Transform3D(Basis(Vector3.UP,-0.5),progression.hinge_origin[55])
 legacy.movers["55"]=World.encode(expected)
 progression.native.set_field("movable:55",Rules.TRAVEL,0) # Actual old source writes only the close target0.
 var routes:int=progression.route_log.size();var changes:int=progression.level_changes.size()
 assert(World.error(legacy,"L9_DR").is_empty(),"Source-known old non-generic55 pose remains admitted")
 assert(World.restore(progression,legacy).is_empty() and driver.restore().is_empty())
 assert(progression.hinges[55].transform.is_equal_approx(expected),"Old angular pose converts to 16.16 without losing physical orientation")
 assert(progression.native.field("movable:55",Rules.PHASE,0)==3,"Known old close target continues from the restored angle")
 var body:AnimatableBody3D=progression.mover_bodies[55]
 print("LEGACY BODY immediate=",PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)," node=",body.global_transform)
 await physics_frame
 await physics_frame # physics_frame resumes before the server step; allow one completed step.
 print("LEGACY BODY synchronized=",PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)," node=",body.global_transform)
 assert(progression.hinges[55].transform.is_equal_approx(expected) and not progression.is_physics_processing(),"Physics sync is not a mover advance")
 assert(PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM).is_equal_approx(body.global_transform),"Restored collision agrees before the next mover tick")
 assert(progression.route_log.size()==routes and progression.level_changes.size()==changes,"Restore replays no use, completion or level event")
 driver.sync()
 var duplicate:Dictionary=legacy.duplicate(true);duplicate.movers["55"]=World.encode(Transform3D(Basis(Vector3.UP,-0.8),progression.hinge_origin[55]))
 assert(World.restore(progression,duplicate).is_empty() and driver.restore().is_empty() and progression.hinges[55].transform.is_equal_approx(expected),"Canonical generic row wins over a legacy duplicate")
 assert(driver.use_movable(55,32.0),"Direct codec use vector stops closing motion")
 assert(progression.native.field("movable:55",Rules.PHASE,-1)==0,"Four-field writes preserve the stopped phase")
 var stopped:int=progression.native.field("movable:55",Rules.POSITION,0)
 progression.advance_movers(1.0/30.0)
 assert(progression.native.field("movable:55",Rules.POSITION,0)==stopped,"Paused generic motion stays stopped")
 # The complete source group5094 includes unrelated unhosted commands and
 # remains atomic in production. Isolate its actual close instruction only
 # as a declared codec vector; never claim the full group executed.
 var source_key:String=progression.native.group_key(1,5094)
 var instructions:Array=progression.native.groups[source_key].filter(func(row):return int(row.opcode)==1 and int(row.target)==55)
 assert(instructions.size()==1 and instructions[0].bytes.hex_encode()=="012037000000","Pinned source close instruction")
 var codec_key:String=progression.native.group_key(1,65535)
 progression.native.groups[codec_key]=instructions.duplicate(true)
 var command:Dictionary=progression.native.execute_group(1,65535)
 assert(command.status=="ran","Isolated native close instruction executes")
 assert(progression.native.field("movable:55",Rules.PHASE,0)==3,"External native close target resumes closing")
 progression.advance_movers(1.0/30.0)
 assert(progression.native.field("movable:55",Rules.POSITION,0)<stopped,"Native close command advances the physical generic mover")
 var bad:Dictionary=legacy.duplicate(true);bad.movers["65535"]=bad.movers["55"]
 assert(not World.error(bad,"L9_DR").is_empty(),"Legacy compatibility never admits an unknown mover")
 # Old58 used the binder's up/heading adapter. Preserve its exact physical
 # continuation through save/restore, then retire that bounded axis only at
 # closed so the next use takes the newly published native slide direction.
 var limit58:Dictionary=World.mover_limits("L9_DR",true)["58"]
 var axis58:Vector3=World.legacy_axis(limit58)
 var old58:=Transform3D(Basis(),progression.hinge_origin[58]+axis58*0.5)
 var sliding:Dictionary=World.snapshot(progression)
 sliding.movers["58"]=World.encode(old58)
 scene.quest_state.generic_objects.areas.L9_DR.movables.erase("58")
 progression.native.set_field("movable:58",Rules.TRAVEL,153)
 assert(World.restore(progression,sliding).is_empty() and driver.restore().is_empty())
 assert(progression.hinges[58].transform.is_equal_approx(old58),"Old non-native slide pose stays physically identical")
 var through_save:Dictionary=preload("res://scripts/lol2/act2_save.gd").snapshot_host(scene)
 assert(through_save.quests.generic_objects.areas.L9_DR.get("legacy_axes",{}).has("58"),"Actual common save boundary captures the legacy axis, without a direct driver sync")
 driver.sync()
 var saved:Dictionary=JSON.parse_string(JSON.stringify(scene.quest_state.generic_objects))
 assert(saved.areas.L9_DR.legacy_axes.has("58") and driver.validate(saved).is_empty(),"Bounded compatibility axis is in the canonical saved packet")
 var malformed:Dictionary=saved.duplicate(true);malformed.areas.L9_DR.legacy_axes["58"][0]+=1000
 assert(not driver.validate(malformed).is_empty(),"Arbitrary motion axes cannot enter a save")
 progression.generic_legacy_axes.clear()
 scene.quest_state.generic_objects=saved
 assert(driver.restore().is_empty() and progression.hinges[58].transform.is_equal_approx(old58),"JSON roundtrip retains the exact old slide pose")
 var instructions58:Array=progression.native.groups[source_key].filter(func(row):return int(row.opcode)==1 and int(row.target)==58)
 assert(instructions58.size()==1 and instructions58[0].bytes.hex_encode()=="01203a000000")
 progression.native.groups[codec_key]=instructions58.duplicate(true)
 assert(progression.native.execute_group(1,65535).status=="ran")
 progression.advance_movers(1.0)
 assert(progression.native.field("movable:58",Rules.POSITION,-1)==0 and not progression.generic_legacy_axes.has(58),"Existing native close returns exactly to the hinge and retires the old axis")
 assert(progression.hinges[58].position.is_equal_approx(progression.hinge_origin[58]),"No jump when the native axis resumes")
 print("PASS L9 old55 rotation/old58 slide physical continuation, bounded saved compatibility axis until closed, body sync/no replay, canonical precedence and external close resume; declared VM/clock vectors")
 quit()
