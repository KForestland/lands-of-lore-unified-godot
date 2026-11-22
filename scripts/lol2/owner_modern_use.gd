extends RefCounted
## Input/reach for explicitly owner-approved modern replacements. E only;
## C remains crouch. No source matcher or original behavior is inferred here.
const WorldInput=preload("res://scripts/lol2/world_input.gd")
static func active(host:Node3D)->bool:
 # Same admission as GenericObjectActions: input can be headless while
 # world_active() retains its ordinary capture-controlled clock semantics.
 var binding:Variant=host.get("progression")
 var magic:Variant=host.get("starting_magic")
 return is_instance_valid(binding) and is_instance_valid(magic) and WorldInput.available() and binding._interaction_active() and magic.health()>0
static func reaches(host:Node3D,point:Vector3,reach:float=150.0)->bool:
 if not active(host):return false
 var offset:Vector3=point-host.camera.global_position
 if offset.length()<0.01 or offset.length()>reach or (-host.camera.global_basis.z).dot(offset.normalized())<0.94:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
static func pressed(event:InputEvent)->bool:
 return event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E
