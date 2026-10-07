extends SceneTree
const Store=preload("res://scripts/lol2/dawn_projectile_store.gd")
const Damage=preload("res://scripts/lol2/dawn_player_damage.gd")
class Magic extends Node:
	var value:=200
	var callback:=Callable()
	func health() -> int:return value
	func set_health(n: int) -> void:
		value=n
		if callback.is_valid():callback.call()
func _initialize() -> void:
	var magic:=Magic.new();root.add_child(magic)
	var store:=Store.new()
	var context: Dictionary={"attacker_heading":0,"player_heading":32768,"guard":0,"mode":1,"scalar":0,"descriptors":[],"player_magic_level":10,"global223d4":0,"flags228":0}
	var birth:=store.spawn(63,[0,65536,0],[0,655360,0],[0,0,0],0)
	var before:=store.checkpoint()
	var bad:=context.duplicate(true);bad.player_magic_level=0
	assert(Damage.direct(magic,store,birth.id,0,bad).has("error") and store.checkpoint()==before and magic.health()==200)
	bad=context.duplicate(true);bad.current=199
	assert(Damage.direct(magic,store,birth.id,0,bad).has("error") and store.checkpoint()==before)
	# Setter reentrancy sees the committed repeat-contact suppression.
	var nested: Array=[]
	magic.callback=func():nested.append(Damage.direct(magic,store,birth.id,0,context))
	var result:=Damage.direct(magic,store,birth.id,0,context)
	assert(result.loss==10 and magic.health()==190 and nested.size()==1 and not nested[0].requested)
	magic.callback=Callable()
	var resumed:=Store.new();assert(resumed.restore(JSON.parse_string(JSON.stringify(store.checkpoint()))).is_empty())
	assert(not Damage.direct(magic,resumed,birth.id,0,context).requested and magic.health()==190)
	birth=store.spawn(63,[0,65536,0],[0,655360,0],[0,0,0],0)
	context.global223d4=1;context.flags228=8
	assert(Damage.direct(magic,store,birth.id,0,context).blocked and magic.health()==190)
	context.global223d4=0;context.flags228=0
	assert(not Damage.direct(magic,store,birth.id,0,context).requested)
	birth=store.spawn(63,[0,65536,0],[0,655360,0],[0,0,0],0)
	# Caster heading, not projectile heading, controls the directional bonus.
	context.attacker_heading=32768
	var directional:=Damage.direct(magic,store,birth.id,0,context)
	assert(directional.loss==11)
	context.attacker_heading=0
	var child: int=store.update(birth.id).child
	assert(child>0)
	var neighbors: Array=[{"id":Damage.PLAYER,"kind":1,"flags":0x4000,"distance":999999999,"direct":false}]
	var before_explosion:=store.checkpoint();var health_before:=magic.health()
	var unbound:=neighbors.duplicate(true);unbound.append({"id":99,"kind":1,"flags":0x4000,"distance":0,"direct":false})
	assert(Damage.explosion(magic,store,child,unbound,context).has("error") and store.checkpoint()==before_explosion and magic.health()==health_before)
	var explosion_hit:=Damage.explosion(magic,store,child,neighbors,context)
	assert(explosion_hit.loss==19 and magic.health()==health_before-19)
	assert(not Damage.explosion(magic,store,child,neighbors,context).requested)
	var loaded:=Store.new();assert(loaded.restore(JSON.parse_string(JSON.stringify(store.checkpoint()))).is_empty())
	assert(not Damage.explosion(magic,loaded,child,neighbors,context).requested)
	birth=store.spawn(63,[0,65536,0],[0,655360,0],[0,0,0],0)
	magic.value=5
	result=Damage.direct(magic,store,birth.id,0,context)
	assert(result.lethal and result.loss==5 and magic.health()==0)
	print("PASS: spell32 actual health setter, no double scaling, atomic invalid/stale snapshot rejection, setter reentrancy, reload suppression, entry gate caster heading, explosion health/reload suppression, atomic unbound-target batch rejection and modern host lethal health0.")
	quit()
