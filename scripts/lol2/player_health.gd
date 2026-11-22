extends Node
## Single live health value for playable scenes. Raw writes preserve the old
## facade, including integers outside the usual save bounds; callers own bounds.
const MAXIMUM:=30
signal changed(before:int,after:int)
var _current:int=MAXIMUM
var current:int:
	get:return _current
	set(v):set_value(v)
func value()->int:return _current
func set_value(v:int)->void:
	var before:=_current
	_current=v
	if before!=v:changed.emit(before,v)
func lose(amount:int)->int:
	set_value(maxi(0,_current-amount));return _current
func heal(amount:int)->int:
	set_value(mini(limit_for(get_parent()),_current+amount));return _current
func restore_full()->void:set_value(limit_for(get_parent()))
func fallen()->bool:return _current<=0

static func owner_for(host:Node)->Node:
	if host==null:return null
	var candidate=host.get("player_health_owner")
	return candidate if candidate!=null and is_instance_valid(candidate) else null
static func attach(host:Node)->void:
	var node:=owner_for(host)
	assert(node!=null,"Playable host must construct its PlayerHealth before loading")
	if node.get_parent()==null:
		node.name="PlayerHealth";host.add_child(node)
static func dispose_unattached(node:Node)->void:
	# Packed scenes can be inspected and freed without ever entering the tree.
	if is_instance_valid(node) and node.get_parent()==null:node.free()
## Compatibility for standalone review/test hosts that do not inherit a playable
## scene base. Actual playable aliases always forward to owner_for(host).
static func read_host(host:Node)->int:
	var node:=owner_for(host)
	if node!=null:return node.value()
	if host.get("roach")!=null:return host.roach.model.player_health
	if host.has_node("Warriors"):return host.get_node("Warriors").health
	return int(host.get("health")) if host.get("health")!=null else MAXIMUM
static func write_host(host:Node,v:int)->void:
	var node:=owner_for(host)
	if node!=null:node.set_value(v)
	elif host.get("roach")!=null:host.roach.model.player_health=v
	elif host.has_node("Warriors"):host.get_node("Warriors").health=v
	else:host.health=v
static func lose_host(host:Node,amount:int)->int:
	var node:=owner_for(host)
	if node!=null:return node.lose(amount)
	var remaining:=maxi(0,read_host(host)-amount)
	write_host(host,remaining);return remaining
static func restore_host(host:Node)->void:
	var node:=owner_for(host)
	if node!=null:node.restore_full()
	elif host.get("roach")!=null or host.has_node("Warriors") or host.get("health")!=null:write_host(host,MAXIMUM)

## Guide-based War Cluster: one20% bonus for60s on today's base30 health.
## Raw health still has ONE owner. Old packets without the optional effect cap30.
static func limit_from_effects(effects:Variant)->int:
	if not effects is Dictionary:return MAXIMUM
	var war:Variant=effects.get("war_cluster")
	if not war is Dictionary:return MAXIMUM
	var remaining:Variant=war.get("remaining")
	if (remaining is int or remaining is float) and is_finite(float(remaining)) and remaining>0.0 and remaining<=60.0 and war.get("bonus")==6:return MAXIMUM+6
	return MAXIMUM
static func limit_for(host:Object)->int:
	if host==null:return MAXIMUM
	var effects=host.get("item_effects")
	return limit_from_effects(effects.state()) if is_instance_valid(effects) else MAXIMUM
