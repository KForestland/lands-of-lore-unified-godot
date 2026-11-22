extends SceneTree
## Small real-physics fixtures, not an earned walk. No map/media or state cheats.
const Contact=preload("res://scripts/lol2/generic_mover_contact.gd")
const Body=preload("res://scripts/lol2/player_form_body.gd")
class Host extends Node3D:
 var player:CharacterBody3D
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func box(parent:Node,at:Vector3,size:Vector3,moving:bool=false)->PhysicsBody3D:
 var body:PhysicsBody3D=AnimatableBody3D.new() if moving else StaticBody3D.new()
 body.collision_layer=1;body.collision_mask=0;body.position=at
 if moving:body.sync_to_physics=false
 var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);parent.add_child(body)
 return body
func run():
 var host:=Host.new();root.add_child(host)
 box(host,Vector3(0,-5,0),Vector3(600,10,600))
 box(host,Vector3(0,105,0),Vector3(600,10,600))
 var platform:AnimatableBody3D=box(host,Vector3(0,4,0),Vector3(100,8,100),true)
 var player:=CharacterBody3D.new();host.player=player
 player.collision_layer=2;player.collision_mask=1;player.position=Vector3(0,40.05,0)
 var collider:=CollisionShape3D.new();collider.shape=Body.shape_for(0);collider.position=Vector3(0,-9,0);player.add_child(collider);host.add_child(player)
 for tick in 8:
  await physics_frame;player.velocity=Vector3(0,-1,0);player.move_and_slide()
 check(player.is_on_floor(),"Fixture genuinely rests on the moving support")
 var original:Transform3D=platform.global_transform
 var lift:Transform3D=original;lift.origin.y+=60
 check(not Contact.may_advance(host,platform,lift),"A carrying lift refuses to crush the full body into the ceiling")
 var sideways:Transform3D=original;sideways.origin.x+=60
 check(Contact.may_advance(host,platform,sideways),"A clear horizontal support movement remains available")
 check(platform.global_transform==original,"Admission queries never move the actual platform")
 platform.queue_free();await physics_frame
 # A door can sweep through the player midway and end clear on both sides.
 var door:AnimatableBody3D=box(host,Vector3.ZERO,Vector3(80,100,2),true)
 door.get_child(0).position=Vector3(40,50,0)
 player.position=Vector3(55,32.05,-55)
 for tick in 3:await physics_frame
 var turn:=Transform3D(Basis(Vector3.UP,PI/2),Vector3.ZERO)
 check(not Contact.may_advance(host,door,turn),"Quarter-turn checks the swept arc, not only its clear endpoint")
 var away:=Transform3D(Basis(Vector3.UP,-PI/2),Vector3.ZERO)
 check(Contact.may_advance(host,door,away),"The opposite clear door arc can open")
 if failures==0:print("PASS generic mover contacts: live standing support, ceiling crush refusal, clear carry, read-only admission and intermediate door-arc contact")
 quit(0 if failures==0 else 1)
