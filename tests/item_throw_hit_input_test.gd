extends "res://tests/item_consumables_input_test.gd"
const AXE:="jungle:weapon_shop:Long_Arm"
func main():
 if not await boot_map("L10_DC"):return
 var creatures:Node=scene.act2_creatures
 creatures.set_physics_process(false)
 if not await grant_scrolls([AXE]):return
 var chosen:String="";var stand:=Vector3.ZERO
 var offset:Vector3=scene.camera.global_position-scene.player.global_position
 for id in creatures.bodies:
  var body:Node3D=creatures.bodies[id]
  if creatures.state.actors[id].health<=8 or not creatures.state.actors[id].present or creatures.peaceful_actor(id) or body.collision_layer==0:continue
  for step in [Vector3(70,0,0),Vector3(-70,0,0),Vector3(0,0,70),Vector3(0,0,-70)]:
   var top:Vector3=body.global_position+step+Vector3.UP*96
   var ground:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top+Vector3.DOWN*256,1,[scene.player.get_rid()]))
   if ground.is_empty():continue
   var candidate:Vector3=ground.position+Vector3.UP*32
   var aimed:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+offset,body.global_position+Vector3.UP*24,3,[scene.player.get_rid()]))
   if not aimed.is_empty() and aimed.collider==body:chosen=id;stand=candidate;break
  if not chosen.is_empty():break
 if not require(not chosen.is_empty(),"Existing visible hostile with clear ground/aim, no fabricated enemy"):return
 var body:Node3D=creatures.bodies[chosen]
 if not await stand_at(stand):return
 if not await look(body.global_position+Vector3.UP*24):return
 var before:int=creatures.state.actors[chosen].health
 if not await use_food(AXE):return
 if not await look(body.global_position+Vector3.UP*24):return
 await button(MOUSE_BUTTON_RIGHT,Vector2(640,360));await frames(3)
 print("THROW_HIT_DIAGNOSTIC id=",chosen," before=",before," after=",creatures.state.actors[chosen].health," hint=",scene.interface_hud.hint.text)
 var loss:int=8*(4 if creatures.interim_scaled(chosen) else 1)
 if not require(creatures.state.actors[chosen].health==maxi(0,before-loss) and scene.carried_collected.count(AXE)==1,"Real returning throw lands compatible armed8 through unchanged Act2 receiver scaling"):return
 print("PASS actual I/right arms LongArm, world right hits existing hostile actor, compatible armed8 and unchanged interim receiver scale, physical rewards; disclosed settled stand/grant/NPC fixture")
 quit()
