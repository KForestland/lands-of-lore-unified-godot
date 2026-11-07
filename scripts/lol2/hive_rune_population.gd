extends "res://scripts/lol2/hive_return_population.gd"
## Finite source-slot reuse; seconds clock and region-entry scheduling are adapters.
const RuneState=preload("res://scripts/lol2/hive_rune_population_state.gd")
var region: Dictionary={}
func _ready() -> void:
	rules=RuneState;state=RuneState.initial();target_prefix="hiverune"
	region=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/hive_rune_region.json"))
	super._ready()
func originals() -> Dictionary:
	var result: Dictionary={}
	for owner in [host.return_population,host.ambush_population]:
		for id in owner.state.actors:
			var a: Dictionary=owner.state.actors[id]
			result[id]={"dead":a.active and a.health==0,"ready":a.health==0 and a.get("death_animation",{"corpse":true}).get("corpse",false),"body":owner.bodies[id]}
	var guards=host.get_node("Warriors")
	for i in range(2):
		result[str(guards.ACTORS[i])]={"dead":guards.enemies[i]==0,"ready":guards.enemies[i]==0,"body":guards.bodies[i]}
	var executioner=host.executioner_live
	result["36"]={"dead":executioner.state.health==0,"ready":executioner.state.mode=="dead","body":executioner.body}
	return result
func observe_originals() -> Dictionary:
	var dead: Dictionary={};var ready: Dictionary={}
	var source:=originals()
	for id in source:
		var original: Dictionary=source[id]
		dead[id]=original.dead;ready[id]=original.ready
	RuneState.observe(state,dead)
	return ready
func arrive(quests: Dictionary) -> void:
	observe_originals()
	if not RuneState.arrive(state,quests).is_empty(): restore(state)
func receive_damage(id: String, damage: int, melee: bool=true, effect: int=20) -> bool:
	var hit:=super.receive_damage(id,damage,melee,effect)
	RuneState.observe(state,{})
	return hit
func present() -> void:
	super.present()
	for id in bodies:
		if state.slots[id].phase==2: bodies[id].hide()
	if not is_instance_valid(host) or not is_instance_valid(host.ambush_population): return
	var source:=originals()
	for id in source:
		var body: Node3D=source[id].body
		var retired: bool=state.slots[id].phase>=2
		body.set_meta("hive_retired",retired)
		if retired: body.hide()
	if state.slots["36"].phase>=2: host.get_node("Nest").actor.hide()
func _physics_process(delta: float) -> void:
	if not active(): return
	var ready:=observe_originals()
	RuneState.advance(state,delta,ready)
	var p: Vector3=host.player.position
	var polygon:=PackedVector2Array()
	for point in region.polygon: polygon.append(Vector2(point[0],point[1]))
	var inside: bool=p.y>=region.floor and p.y<=region.ceiling and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
	if inside and not state.inside: arrive(host.area_handoff().quests)
	state.inside=inside
	super.advance(delta)
	present()
