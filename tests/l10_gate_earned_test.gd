extends "res://tests/l8_departure_earned_test.gd"
func continue_village(scene: Node)->void:
 await super.continue_village(scene)
 if failures>0:return
 var change:Dictionary=scene.progression.level_changes.back()
 scene.progression.change_scene_enabled=true
 scene.progression._change_level(change)
 await scene_changed
 var cemetery=current_scene
 for i in 1500:
  await process_frame
  if cemetery.ready_for_review:break
 cemetery.player.set_physics_process(false)
 cemetery.set_physics_process(false)
 check(State.KEY in cemetery.carried_collected,"earned shaman sigil transported into L10")
 var gate=cemetery.get_node("L10MainGate")
 for tick in 600:
  await physics_frame
  cemetery.camera.look_at(gate.AIM,Vector3.UP)
  if gate.reachable():break
  var delta:Vector3=gate.AIM-cemetery.player.position;delta.y=0
  cemetery.move_grounded(delta.normalized(),cemetery.player.get_physics_process_delta_time())
 if not check(gate.reachable(),"physical arrival-to-gate approach at "+str(cemetery.player.position)):return
 # The closed source geometry must actually prevent crossing, even with the sigil carried.
 for tick in 240:
  await physics_frame
  var delta:Vector3=Vector3(-125,cemetery.player.position.y,-1150)-cemetery.player.position
  cemetery.move_grounded(delta.normalized(),cemetery.player.get_physics_process_delta_time())
 check(cemetery.player.position.z>-1040,"closed gate physically blocks passage")
 cemetery.camera.look_at(gate.AIM,Vector3.UP)
 var before:Array=cemetery.carried_collected.duplicate()
 check(not gate.unlock("wrong").ok and cemetery.carried_collected==before and not gate.opened(),"wrong gate item refused")
 check(gate.unlock(State.KEY).ok,"earned sigil opens gate")
 var path:="res://tmp/l10_gate_earned_save.json"
 check(cemetery._quicksave_unrecorded(path).is_empty(),"open gate saved")
 check(cemetery._quickload_unrecorded(path).is_empty(),"open gate reloaded")
 check(gate.opened() and State.KEY in cemetery.carried_collected,"open state and retained sigil persist")
 check(not gate.unlock(State.KEY).ok,"duplicate unlock refused")
 # Walk beyond the two source leaves, not just check an open flag.
 for tick in 420:
  await physics_frame
  var delta:Vector3=Vector3(-125,cemetery.player.position.y,-1150)-cemetery.player.position
  if delta.length()<12:break
  cemetery.move_grounded(delta.normalized(),cemetery.player.get_physics_process_delta_time())
 check(cemetery.player.position.z < -1100,"physically crossed open source leaves at "+str(cemetery.player.position))
 if failures==0:print("PASS continuous earned Act1->L8->L10 gate, actual save/reload and physical crossing; rendered pending")
 cemetery.queue_free();await process_frame
