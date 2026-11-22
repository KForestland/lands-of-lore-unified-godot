extends "res://tests/helpers/g15_stored_spell_input.gd"
## Museum component: original key pickup, real E; disclosed introduction/pose fixtures.
func _initialize():main.call_deferred()
func view_lock(lock:int)->bool:
 var point:Vector3=scene.key_locks.aim_point(lock)
 for side in [Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0),Vector3(0,0,-1)]:
  scene.player.global_position=point+side*45-Vector3(0,scene.camera.position.y,0)
  scene.player.velocity=Vector3.ZERO
  if not await look(point):return false
  await physics_frame
  if scene.can_reach_item(point):return true
 return require(false,"Disclosed key stand has a real reach/aim ray")
func main():
 scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state="complete"
 root.add_child(scene);current_scene=scene
 scene.set_physics_process(false);scene.sword_transfer.set_process(false);scene.gallery.set_physics_process(false)
 use_guard=false;await adopt()
 if not captured():await lclick()
 if not await view_lock(87):return
 await tap(KEY_E);await frames(12)
 var key:String=scene.key_locks.State.KEY
 var value:Dictionary=scene.item_effects.belt_state()
 if not require(scene.carried_collected.count(key)==1 and scene.item_effects.Catalog.definition(key) in value.slots,"Real E takes original key and automatically belts it"):return
 if not await view_lock(88):return
 await frames(12)
 if not require(scene.item_effects.smart_item==key and not scene.key_locks.State.is_loaded(scene.key_locks.state,88),"Looking at its door highlights key but never opens it"):return
 await picture("belt_smart_key")
 await tap(KEY_E);await frames(4)
 if not require(scene.key_locks.State.is_loaded(scene.key_locks.state,88) and key not in scene.carried_collected,"Real E uses the fitted key on its real original lock"):return
 await tap(KEY_E);await frames(12)
 if not require(scene.carried_collected.count(key)==1,"Real E retrieves original key once"):return
 scene.set_physics_process(true)
 if not await stand_at(Vector3(-3796,34,-369)):return
 var saved:Dictionary=scene.item_effects.belt_state().duplicate(true)
 if not await disk_cycle("belt_museum_key"):return
 if not require(scene.item_effects.belt_state()==saved and scene.carried_collected.count(key)==1,"Actual F5/F9 preserves belt and unique key"):return
 print("PASS Museum real key pickup -> belt -> aim/glow/no-autouse -> E original door -> retrieval -> F5/F9; introduction/pose component fixtures, no earned-walk claim")
 quit()
