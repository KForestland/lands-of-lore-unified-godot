extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for pair in [["res://scenes/lol2/jungle_walkthrough.tscn","dawn"],["res://scenes/lol2/hive_review.tscn","dawn20"]]:
		var scene=load(pair[0]).instantiate();root.add_child(scene);current_scene=scene
		await process_frame;await physics_frame
		scene.set_physics_process(false)
		var dawn=scene.get(pair[1]);dawn.set_physics_process(false)
		var point: Array=dawn.src.actor.position
		var context: Dictionary={"position":[roundi(float(point[0])*65536),roundi(-float(point[2])*65536)],"height":int(point[1])+40,"sprite_height":20,"owner_radius":16,"effect_radius":8,"heading":0,"initial_heading":0,"initial_speed":0,"speed":200,"flags":0}
		var before: Dictionary=dawn.checkpoint()
		var result: Dictionary=dawn.query_projectile_launch(context)
		if result.has("error") or result.regions.is_empty() or result.regions.all(func(r):return r<0):
			push_error("Real host launch could not resolve caster region: %s %s"%[pair,result]);quit(1);return
		if dawn.checkpoint()!=before:
			push_error("Launch query changed encounter checkpoint");quit(1);return
		# Supplied allocation: actual host save/load must retain effects and consumed
		# damage state even after the in-memory owner is cleared.
		var birth: Dictionary=dawn.projectiles.spawn(int(dawn.ID),result.position,result.position,result.position,int(result.heading))
		assert(birth.allocated)
		var moved: Dictionary=dawn.move_projectile(birth.id,7864,8.0)
		assert(not moved.has("error"),str(moved))
		assert(dawn.projectiles.checkpoint().effects[0].position==moved.position)

		var event: Dictionary={"enabled":true,"collision":0,"target":1,"distance":65536,"movement_heading":int(result.heading),"collision_heading":int(result.heading)}
		assert(dawn.projectiles.contact(birth.id,event).request)
		# Supplied projectile starting inside the actual player capsule exercises
		# the real overlap/RID boundary and actual host health setter.
		var local: Vector3=scene.player.global_position-dawn.origin()
		var player_point: Array=[roundi(local.x*65536),roundi(-local.z*65536),roundi(local.y*65536)]
		var caster_point: Array=[player_point[0]-(100<<16),player_point[1],player_point[2]]
		var damaging: Dictionary=dawn.projectiles.spawn(int(dawn.ID),player_point,player_point,caster_point,0)
		var player_hit: Dictionary=dawn.move_projectile(damaging.id,1,1.0)
		assert(not player_hit.has("error") and player_hit.blocked,str(player_hit))
		var damage_context: Dictionary={"player_heading":32768,"guard":0,"mode":1,"scalar":0,"descriptors":[],"player_magic_level":10,"global223d4":0,"flags228":0}
		var health_before: int=scene.starting_magic.health()
		var damage: Dictionary=dawn.damage_projectile_player(damaging.id,player_hit,0,damage_context)
		assert(not damage.has("error") and damage.loss==10,str(damage))
		assert(scene.starting_magic.health()==health_before-10)
		var health_after: int=scene.starting_magic.health()
		var pending: Dictionary=dawn.projectiles.checkpoint()
		var path: String="user://tests/projectiles_"+str(pair[1])+".json"
		var save_error: String=scene.quicksave(path)
		assert(save_error.is_empty(),save_error)
		assert(dawn.projectiles.restore(dawn.projectiles.initial()).is_empty())
		scene.starting_magic.set_health(health_before)
		var load_error: String=scene.quickload(path)
		assert(load_error.is_empty(),load_error)
		assert(dawn.projectiles.checkpoint()==pending)
		assert(scene.starting_magic.health()==health_after)
		assert(not dawn.damage_projectile_player(damaging.id,player_hit,0,damage_context).requested)
		assert(scene.starting_magic.health()==health_after)

		assert(not dawn.projectiles.contact(birth.id,event).request)
		var packet: Dictionary=dawn.checkpoint();var invalid:=packet.duplicate(true)
		invalid.projectiles.effects[0].contact.counter=-1
		assert(not dawn.restore(invalid).is_empty() and dawn.checkpoint()==packet)
		invalid=packet.duplicate(true);invalid.projectiles.effects[0].owner=999
		assert(not dawn.restore(invalid).is_empty() and dawn.checkpoint()==packet)
		assert(dawn.restore(before).is_empty() and dawn.projectiles.checkpoint()==dawn.projectiles.initial())
		DirAccess.remove_absolute(path)
		print("HOST launch: %s region=%s accepted=%s world=%s"%[pair[1],result.regions,result.accepted,result.world_position])
		scene.queue_free();for i in 3:await process_frame
	print("PASS: both production Dawn hosts resolve launch regions and physics without query mutation; supplied allocations survive host disk saves, reject invalid restore, suppress repeated damage, and accept legacy packets. Explicit motion and real player capsule/health damage survive disk reload without duplicate loss; native stats supplied, no AI cast creation.")
	quit()
