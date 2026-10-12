extends SceneTree
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	func world_active() -> bool:return on and health()>0
func _initialize() -> void:run.call_deferred()
func freeze(node: Node) -> void:
	node.set_physics_process(false);node.set_process(false)
	for child in node.get_children():freeze(child)
func run() -> void:
	for pair in [["res://scenes/lol2/jungle_walkthrough.tscn","dawn"],["res://scenes/lol2/hive_review.tscn","dawn20"]]:
		var scene=load(pair[0]).instantiate();root.add_child(scene);current_scene=scene
		await process_frame;await physics_frame
		freeze(scene)
		var d=scene.get(pair[1]);d.set_physics_process(false)
		scene.starting_magic.set_process(false)
		var magic:=TestMagic.new();magic.host=scene;scene.add_child(magic);magic.set_process(false);scene.starting_magic=magic
		# Supplied hostile story state; attacks themselves must be produced by the
		# real encounter advance, with actual space queries and player health.
		d.state.present=true;d.state.b5=12;d.state.owner_state=50 if pair[1]=="dawn" else 20
		d.state.sighted=true;d.state.clip={};d.hold=false;d._sync_body(0.0)
		var caster: Vector3=d.population.bodies[d.ID].global_position
		var found:=false
		for i in 16:
			var angle:=TAU*i/16
			scene.player.global_position=caster+Vector3(sin(angle)*150,40,cos(angle)*150)
			await physics_frame
			var ray: Dictionary=d.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(caster+Vector3.UP*40,scene.player.global_position,3,[d.population.bodies[d.ID].get_rid()]))
			if not ray.is_empty() and ray.get("rid")==scene.player.get_rid():found=true;break
		assert(found,"No clear attack lane")
		# A real collision body between caster and player must prevent casting.
		var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(35,100,35);shape.shape=box;wall.add_child(shape);scene.add_child(wall)
		wall.global_position=(caster+Vector3.UP*40+scene.player.global_position)/2
		await physics_frame
		for i in 180:d.advance(1.0/60)
		assert(d.combat.saved.shots==0,"Cast through an obstructed lane")
		wall.queue_free();await physics_frame;await physics_frame
		var hp: int=magic.health()
		for i in 180:
			d.advance(1.0/60)
			if not d.combat.saved.bolts.is_empty():break
		assert(d.combat.saved.shots==1 and d.combat.saved.bolts.size()==1,"No automatic projectile")
		assert(d.combat.visuals.size()==1,"Projectile not presented")
		var pending: Dictionary=d.combat.checkpoint()
		magic.on=false;d.advance(1.0);assert(d.combat.checkpoint()==pending);magic.on=true
		paused=true;d.advance(1.0);assert(d.combat.checkpoint()==pending);paused=false
		var path: String="user://tests/modern_"+pair[1]+".json"
		assert(scene.quicksave(path).is_empty())
		d.combat.restore(d.combat.initial())
		assert(scene.quickload(path).is_empty())
		freeze(scene)
		await physics_frame
		assert(d.combat.checkpoint()==pending,"In-flight state changed on disk reload: "+str(pending)+" -> "+str(d.combat.checkpoint()))
		for i in 120:
			d.advance(1.0/60)
			if magic.health()<hp:break
		assert(magic.health()<hp and d.combat.saved.bolts.is_empty(),"Automatic hit missing or unconsumed: hp="+str(hp)+" now="+str(magic.health())+" player="+str(scene.player.global_position)+" combat="+str(d.combat.checkpoint()))
		var after: int=magic.health()
		assert(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty())
		d.advance(0.01);assert(magic.health()==after,"Consumed hit repeated after reload")
		var before: Dictionary=d.checkpoint();var bad:=before.duplicate(true);bad.combat.cooldown=-1
		assert(not d.restore(bad).is_empty() and d.checkpoint()==before)
		d.state.b5=0;d.combat.saved.windup=0.5;d.advance(0.01)
		assert(d.combat.saved.windup==0 and d.combat.saved.bolts.is_empty())
		DirAccess.remove_absolute(path)
		print("HOST automatic combat PASS ",pair[1]," health ",hp," -> ",after)
		scene.queue_free();for i in 3:await process_frame
	print("PASS: both real Dawn hosts automatically charge/fire/hit; world gating, visible bolts, in-flight disk restore, consumed-hit persistence, atomic invalid restore and hostility cancellation.")
	quit()
