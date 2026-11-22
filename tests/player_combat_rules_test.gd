extends SceneTree
const Combat=preload("res://scripts/lol2/player_combat.gd")
const Spies=preload("res://tests/foundation/strike_spies.gd")
class TailSpy extends Node:
	var host:Node
	var last_poison:=-1
	var calls:Array=[]
	func net_hit(id:String,item:String)->bool:
		calls.append(["net",id,item,host.quest_state.weapon_poison.sac,preload("res://scripts/lol2/item_handlers.gd").last_hit_route.item]);return false
	func prism_hit(id:String,item:String)->int:
		calls.append(["prism",id,item,host.quest_state.weapon_poison.sac,preload("res://scripts/lol2/item_handlers.gd").last_hit_route.item]);return 0
func _initialize():run.call_deferred()
func run():
	var host=Spies.Host.new();root.add_child(host)
	host.item_effects=Spies.Bonus.new();host.add_child(host.item_effects)
	for form in 3:
		host.player_form=form
		for item in ["","museum:item11:Fine_Longsword","hive:item0:Wax"]:
			host.equipped_item=item;host.carried_inventory.equipped_item=item
			for carried in [false,true]:
				host.carried_collected=[item] if carried else []
				for rule in [Combat.Armed.EQUIPPED_NAME,Combat.Armed.EQUIPMENT_WEAPON,Combat.Armed.CARRIED_WEAPON_SLOT]:
					var armed:bool=item!="" if rule==Combat.Armed.EQUIPPED_NAME else item=="museum:item11:Fine_Longsword" and (carried or rule==Combat.Armed.EQUIPMENT_WEAPON)
					assert(Combat.armed(host,rule)==armed)
					assert(Combat.may_strike(host,false,rule)==(form==0 and armed if rule==Combat.Armed.CARRIED_WEAPON_SLOT else form!=0 or armed))
					for bonus in [false,true]:
						host.item_effects.enabled=bonus
						var expected:int=12 if form==1 else 1 if form==2 else 8 if armed else 4
						assert(Combat.damage(host,false,rule)==expected)
						assert(Combat.damage(host,true,rule)==expected+(20 if bonus else 0))
	assert(Combat.COOLDOWN==0.45 and Combat.REACH_CREATURE==110 and Combat.REACH_CAVE==96 and Combat.REACH_HIVE==96 and Combat.REACH_PROP==140 and Combat.CONE_DOT==0.9)
	assert(Combat.cooldown_ready(0) and not Combat.cooldown_ready(0.001))
	assert(Combat.cooldown_tick(0.1,0.2)==0 and is_equal_approx(Combat.cooldown_tick(0.45,0.1),0.35))
	assert(Combat.cooldown_tick(0.45,1.0/60.0,1.0/1024.0)==snappedf(0.45-1.0/60.0,1.0/1024.0))
	host.player=CharacterBody3D.new();host.add_child(host.player)
	host.camera=Camera3D.new();host.add_child(host.camera)
	var target=StaticBody3D.new();target.position=Vector3(0,0,-80);target.collision_layer=2;host.add_child(target)
	var target_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,4);target_shape.shape=box;target.add_child(target_shape)
	await physics_frame;await physics_frame
	assert(Combat.aim_ray(host,110,3).collider==target)
	assert(Combat.aim_ray(host,110,1).is_empty())
	assert(Combat.aim_cone(host,Vector3(0,0,-96),96,3,[host.player.get_rid()],target))
	assert(not Combat.aim_cone(host,Vector3(0,0,-96.01),96,3,[host.player.get_rid()],target))
	assert(not Combat.aim_cone(host,Vector3.ZERO,96,3,[host.player.get_rid()],target))
	assert(Combat.facing_point(host,Vector3(40,0,-90)) and not Combat.facing_point(host,Vector3(50,0,-90)))
	var wall=StaticBody3D.new();wall.position=Vector3(0,0,-30);wall.collision_layer=1;host.add_child(wall)
	var wall_shape=CollisionShape3D.new();wall_shape.shape=box;wall.add_child(wall_shape)
	await physics_frame;await physics_frame
	assert(Combat.aim_ray(host,110,3).collider==wall and Combat.aim_ray(host,110,2).collider==target)
	assert(not Combat.aim_cone(host,target.position,96,3,[host.player.get_rid()],target))
	assert(Combat.aim_cone(host,target.position,96,3,[host.player.get_rid(),wall.get_rid()],target))
	var handlers=preload("res://scripts/lol2/item_handlers.gd")
	var feedback=preload("res://scripts/lol2/combat_feedback.gd")
	host.equipped_item="museum:item11:Fine_Longsword"
	for flags in 16:
		host.quest_state={"weapon_poison":{"version":1,"paint":1,"sac":1}}
		handlers.last_hit_route={"item":"unchanged"}
		var tail=TailSpy.new();tail.host=host;host.add_child(tail)
		var opts={"poison":bool(flags&1),"record":bool(flags&2),"net":bool(flags&4),"prism":bool(flags&8)}
		var before:int=feedback.landed_hits
		assert(Combat.after_landed(host,tail,"spy",opts) and feedback.landed_hits==before+1)
		assert(tail.last_poison==(0x40 if opts.poison else -1) and host.quest_state.weapon_poison.sac==(0 if opts.poison else 1))
		assert(handlers.last_hit_route.item==(host.equipped_item if opts.record else "unchanged"))
		var expected:Array=[]
		for name in ["net","prism"]:
			if opts[name]:expected.append([name,"spy",host.equipped_item,0 if opts.poison else 1,host.equipped_item if opts.record else "unchanged"])
		assert(tail.calls==expected,"poison then record then net/prism ordering")
		tail.free()
	host.carried_inventory.equipped_item="museum:prop280:Prism"
	var tail=TailSpy.new();tail.host=host;host.add_child(tail)
	assert(Combat.after_landed(host,tail,"hive",{"record":true,"net":true,"armed_rule":Combat.Armed.EQUIPMENT_WEAPON}))
	assert(handlers.last_hit_route.item==host.carried_inventory.equipped_item and tail.calls[0][2]==host.carried_inventory.equipped_item)
	tail.free()
	host.free();print("PASS player_combat_rules: explicit armed/refusal/bonus options and unchanged constants/cooldown rounding");quit()
