extends "res://tests/bj14_sol_input_walk.gd"
func scenario()->String:return "fences"

# A walking player does not attack through tomb walls. Keep all actors and their
# physics live; choose only enemies visible from the camera for optional combat.
func nearby_enemy()->String:
 var pop=scene.act2_creatures
 var best:="";var distance:=80.0
 for id in pop.bodies:
  var actor:Dictionary=pop.state.actors[id]
  if not actor.present or actor.health<=0 or pop.peaceful_actor(id):continue
  var d:float=scene.player.global_position.distance_to(pop.bodies[id].global_position)
  if d>=distance:continue
  var query:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,pop.bodies[id].global_position+Vector3.UP*24,1|256|512,[scene.player.get_rid()])
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   if not proof.has("occluded_combat_candidates"):proof["occluded_combat_candidates"]={}
   if not proof.occluded_combat_candidates.has(id):
    proof.occluded_combat_candidates[id]={"health":actor.health,"obstruction":str(hit.collider.get_path()),"player_position":str(scene.player.position)}
    print("FENCE skip occluded enemy ",id," hp ",actor.health," obstruction ",hit.collider.get_path()," at ",scene.player.position)
   continue
  distance=d;best=id
 return best
