extends RefCounted
## Modern player-contact admission for the generic pilot. Test a proposed object
## step against the live, full contact body before publishing it to physics.
## A carried body must also have clear space throughout the proposed step.
const TRANSLATION_SAMPLE:=4.0
const ROTATION_SAMPLE:=PI/36.0
static func may_advance(host:Node3D,body:AnimatableBody3D,target:Transform3D)->bool:
 var player:CharacterBody3D=host.player
 if not is_instance_valid(player):return true
 var collider:CollisionShape3D=player.get_child(0) as CollisionShape3D
 if collider==null or collider.shape==null:return true
 if (body.collision_layer & player.collision_mask)==0:return true
 var before:Transform3D=body.global_transform
 if before.is_equal_approx(target):return true
 var angle:float=before.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion())
 var samples:int=maxi(1,maxi(ceili(before.origin.distance_to(target.origin)/TRANSLATION_SAMPLE),ceili(angle/ROTATION_SAMPLE)))
 var space:PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
 var support:=false
 if player.is_on_floor():
  var ray:=PhysicsRayQueryParameters3D.create(player.global_position,player.global_position-Vector3.UP*64,1,[player.get_rid()])
  var hit:Dictionary=space.intersect_ray(ray)
  support=not hit.is_empty() and hit.collider==body
 var capsule:Transform3D=collider.global_transform
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=collider.shape;query.margin=0.0
 var exclusions:Array[RID]=[player.get_rid()]
 if support:exclusions.append(body.get_rid())
 query.exclude=exclusions
 query.collision_mask=player.collision_mask if support else body.collision_layer & player.collision_mask
 for index in range(1,samples+1):
  var sample:Transform3D=before.interpolate_with(target,float(index)/samples)
  # The object stays at its current physics pose during this read-only query.
  # Transform the capsule oppositely to test the object's proposed contact.
  query.transform=sample*before.affine_inverse()*capsule if support else before*sample.affine_inverse()*capsule
  var hits:Array[Dictionary]=space.intersect_shape(query,64)
  for hit in hits:
   if support or hit.collider==body:
    return false
 return true
