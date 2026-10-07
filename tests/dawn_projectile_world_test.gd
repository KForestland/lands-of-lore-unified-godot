extends SceneTree
const World=preload("res://scripts/lol2/dawn_projectile_world.gd")
class Regions extends RefCounted:
	var limit:=100.0
	func region_at(point: Vector3) -> int:
		return 1 if absf(point.x)<limit and absf(point.z)<limit else -1
var failed:=false
func check(ok: bool, message: String) -> bool:
	if not ok: failed=true;push_error(message);quit(1)
	return ok
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene);current_scene=scene
	var blocker:=StaticBody3D.new();blocker.collision_layer=1
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,4,4);collider.shape=shape;blocker.add_child(collider);scene.add_child(blocker)
	var origin:=Vector3(300,50,-200)
	blocker.position=origin+Vector3(0,10,-25)
	await physics_frame;await physics_frame
	var space:=scene.get_world_3d().direct_space_state
	var nav:=Regions.new()
	var context: Dictionary={"position":[0,0],"height":20,"sprite_height":20,"owner_radius":16,"effect_radius":8,"heading":0,"initial_heading":123,"initial_speed":0,"speed":200,"flags":0}
	var result:=World.launch(space,nav,origin,context)
	if not check(not result.has("error") and not result.accepted and result.regions==[1] and result.world_position==blocker.position,"World collision did not reject projected launch"):return
	var excluded: Array[RID]=[blocker.get_rid()]
	result=World.launch(space,nav,origin,context,null,excluded)
	if not check(result.accepted,"Caster exclusion did not admit launch"):return
	result=World.launch(space,nav,origin,context,null,[],2)
	if not check(result.accepted,"Collision layer filter ignored"):return
	nav.limit=20
	result=World.launch(space,nav,origin,context)
	if not check(result.accepted and result.regions==[-1,1] and result.world_position==origin+Vector3(0,10,0),"Origin fallback did not use actual region queries"):return
	nav.limit=0
	result=World.launch(space,nav,origin,context)
	if not check(not result.accepted and result.regions==[-1,-1] and result.heading==123 and result.speed==0,"Missing regions admitted launch"):return
	nav.limit=100
	result=World.launch(space,nav,origin,context,[100<<16,0])
	if not check(result.accepted and result.heading==16384 and result.world_position==origin+Vector3(25,10,0),"Targeted launch coordinate/bearing conversion differs"):return
	var bad:=context.duplicate(true);bad.height=INF
	if not check(World.launch(space,nav,origin,bad).has("error"),"Accepted invalid world launch"):return
	var start: Array=[0,0,10<<16];var finish: Array=[0,100<<16,10<<16]
	var swept:=World.sweep(space,origin,start,finish,2)
	if not check(swept.blocked and swept.fraction>0 and swept.fraction<0.3 and not swept.contact.is_empty(),"Swept sphere tunneled through blocker"):return
	if not check(World.sweep(space,origin,start,finish,2,excluded).position==finish,"Sweep caster exclusion differs"):return
	var overlapping: Array=[0,25<<16,10<<16]
	if not check(World.sweep(space,origin,overlapping,finish,2).fraction==0,"Initial overlap was ignored"):return
	if not check(not World.sweep(space,origin,start,start,2).blocked,"Zero motion changed free placement"):return
	var Store=preload("res://scripts/lol2/dawn_projectile_store.gd")
	var store:=Store.new();var birth:=store.spawn(63,start,finish,start,0)
	var motion:=store.motion(birth.id,786432)
	if not check(motion.to==finish,"Shared delta did not produce expected100-unit movement"):return
	swept=World.sweep(space,origin,motion.from,motion.to,2)
	if not check(store.moved(birth.id,motion.from,swept.position).is_empty(),"Sweep commit failed"):return
	var checkpoint:=store.checkpoint();var restored:=Store.new()
	if not check(restored.restore(JSON.parse_string(JSON.stringify(checkpoint))).is_empty() and restored.checkpoint()==checkpoint,"Moved position did not survive reload"):return
	if not check(not restored.moved(birth.id,start,finish).is_empty() and restored.checkpoint()==checkpoint,"Stale movement overwrote restored position"):return
	scene.queue_free();await process_frame
	print("PASS: live physics launch collision, RID exclusion, layer mask, real region fallback/failure, targeted bearing and translated source coordinates, swept obstacle/initial overlap, saved motion and stale commit rejection; modern adapter.")
	quit()
