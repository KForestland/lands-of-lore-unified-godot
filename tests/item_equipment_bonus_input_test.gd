extends "res://tests/item_equipment_input_test.gd"
const FINE:="museum:item11:Fine_Longsword"
const MIGHT:="act2:L9_DR:item53"
const CHARM:="act2:L12_CM:kenneth_charm"
func main():
 if not await boot_map("L10_DC"):return
 var creatures:Node=scene.act2_creatures;creatures.set_physics_process(false)
 if not await grant_scrolls([FINE,MIGHT,CHARM]):return
 for id:String in [FINE,MIGHT,CHARM]:
  if not await equip_click(id):return
 if not require(preload("res://scripts/lol2/player_combat.gd").damage(scene,true)==8 and preload("res://scripts/lol2/player_defense.gd").scalar(scene)==30,"Effective armed8 retained; protection30 remains live"):return
 if not require(preload("res://scripts/lol2/item_catalog.gd").fixed_damage(FINE)==12 and preload("res://scripts/lol2/player_equipment.gd").fixed_bonus(scene)==25,"Original12+15+10 remain intact as data, not effective damage"):return
 await tap(KEY_ESCAPE)
 var chosen:String="";var stand:=Vector3.ZERO
 var offset:Vector3=scene.camera.global_position-scene.player.global_position
 for id in creatures.bodies:
  var body:Node3D=creatures.bodies[id]
  if creatures.state.actors[id].health<200 or not creatures.state.actors[id].present or creatures.peaceful_actor(id) or body.collision_layer==0:continue
  for step in [Vector3(70,0,0),Vector3(-70,0,0),Vector3(0,0,70),Vector3(0,0,-70)]:
   var top:Vector3=body.global_position+step+Vector3.UP*96
   var floor:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top+Vector3.DOWN*256,1,[scene.player.get_rid()]))
   if floor.is_empty():continue
   var candidate:Vector3=floor.position+Vector3.UP*32
   var ray:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+offset,body.global_position+Vector3.UP*24,3,[scene.player.get_rid()]))
   if not ray.is_empty() and ray.collider==body:chosen=id;stand=candidate;break
  if chosen!="":break
 if not require(chosen!="","Existing hostile and unobstructed stand"):return
 if not await stand_at(stand):return
 if not await look(creatures.bodies[chosen].global_position+Vector3.UP*24):return
 var before:int=creatures.state.actors[chosen].health
 await button(MOUSE_BUTTON_LEFT,Vector2(640,360));await frames(3)
 if not require(creatures.state.actors[chosen].health==before-32,"Real left strike keeps armed8 through unchanged Act2x4"):return
 if not await disk_cycle("native_equipment_bonus"):return
 if not require(preload("res://scripts/lol2/player_combat.gd").damage(scene,true)==8 and preload("res://scripts/lol2/player_defense.gd").scalar(scene)==30,"F9 keeps compatibility damage and protection"):return
 print("PASS actual inventory sword/gauntlets/charm, table terms remain data, effective8/realleft32 under unchangedscale4, F5/F9; genuinegrant/heldNPC/oneclearstand fixtures")
 quit()
