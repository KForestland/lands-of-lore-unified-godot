extends RefCounted
## Shared player-strike rules. Callers keep their target dispatch, clocks and
## explicit bonus/refusal differences. Receiver-side Act 2 scaling stays there.
const Forms=preload("res://scripts/lol2/player_form_rules.gd")
const Equipment=preload("res://scripts/lol2/player_equipment.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const COOLDOWN:=0.45
const REACH_CREATURE:=110.0
const REACH_CAVE:=96.0
const REACH_HIVE:=96.0
const REACH_PROP:=140.0
const CONE_DOT:=0.9
const DEFAULT_DAMAGE:=8

enum Armed { EQUIPPED_NAME, EQUIPMENT_WEAPON, CARRIED_WEAPON_SLOT }

static func equipped(host:Node,rule:=Armed.EQUIPPED_NAME)->String:
	return str(host.carried_inventory.equipped_item) if rule==Armed.EQUIPMENT_WEAPON else str(host.equipped_item)
static func armed(host:Node,rule:=Armed.EQUIPPED_NAME)->bool:
	var item:=equipped(host,rule)
	match rule:
		Armed.EQUIPMENT_WEAPON:return Equipment.weapon(item)
		Armed.CARRIED_WEAPON_SLOT:return item in host.carried_collected and Catalog.slot(item)=="weapon"
		_:return item!=""
static func may_strike(host:Node,empty_hand_allowed:bool,armed_rule:=Armed.EQUIPPED_NAME)->bool:
	# Museum carried-slot rules also require Human; other props permit natural attacks.
	if armed_rule==Armed.CARRIED_WEAPON_SLOT:return Forms.can_use_weapon(host.player_form) and armed(host,armed_rule)
	return empty_hand_allowed or host.player_form!=0 or armed(host,armed_rule)
static func base_damage(form:int,is_armed:bool)->int:return Forms.melee_damage(form,is_armed)
static func damage(host:Node,with_item_bonus:bool,armed_rule:=Armed.EQUIPPED_NAME)->int:
	var result:=base_damage(host.player_form,armed(host,armed_rule))
	# Item-table terms remain data until original target health ships with them.
	if with_item_bonus:
		var effects=host.get("item_effects")
		if effects!=null and is_instance_valid(effects) and effects.has_method("melee_damage"):result=int(effects.call("melee_damage",result))
	return result
static func cooldown_ready(remaining:float)->bool:return not remaining>0.0
static func cooldown_tick(remaining:float,delta:float,quantum:float=0.0)->float:
	return maxf(0.0,snappedf(remaining-delta,quantum) if quantum>0.0 else remaining-delta)

static func ray_between(host:Node3D,start:Vector3,end:Vector3,mask:int,exclude:Array[RID],hit_from_inside:bool=false)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(start,end,mask,exclude)
	query.hit_from_inside=hit_from_inside
	return host.get_world_3d().direct_space_state.intersect_ray(query)
static func aim_ray(host:Node3D,reach:float,mask:int)->Dictionary:
	var origin:Vector3=host.camera.global_position
	return ray_between(host,origin,origin-host.camera.global_basis.z*reach,mask,[host.player.get_rid()])
static func facing_point(host:Node3D,point:Vector3)->bool:
	var offset:Vector3=point-host.camera.global_position
	return offset.length()>0.01 and (-host.camera.global_basis.z).dot(offset.normalized())>=CONE_DOT
static func aim_cone(host:Node3D,point:Vector3,reach:float,clear_mask:int,exclude:Array[RID],allowed_collider:CollisionObject3D=null)->bool:
	var offset:Vector3=point-host.camera.global_position
	if offset.length()<=0.01 or offset.length()>reach or not facing_point(host,point):return false
	var hit:=ray_between(host,host.camera.global_position,point,clear_mask,exclude,true)
	return hit.is_empty() or hit.collider==allowed_collider

static func after_landed(host:Node,owner:Node,id:String,opts:Dictionary)->bool:
	var item:=equipped(host,int(opts.get("armed_rule",Armed.EQUIPPED_NAME)))
	if bool(opts.get("poison",false)):owner.last_poison=preload("res://scripts/lol2/weapon_poison.gd").spend(host)
	if bool(opts.get("record",false)):preload("res://scripts/lol2/item_handlers.gd").record_hit(item)
	if bool(opts.get("net",false)) and owner.has_method("net_hit"):owner.net_hit(id,item)
	if bool(opts.get("prism",false)) and owner.has_method("prism_hit"):owner.prism_hit(id,item)
	return preload("res://scripts/lol2/combat_feedback.gd").landed(true)
