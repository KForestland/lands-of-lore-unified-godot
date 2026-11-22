extends "res://scripts/lol2/scripted_creature_population.gd"
## Environmental damage: same saved health/death state as combat, with no weapon or spell XP.
## Blast recipient flags/topology/falloff are decoded; final mitigation and sunlight are intent adapters.
const Blast = preload("res://scripts/lol2/dark_halls_blast_rules.gd")

func environment_damage(id: String, amount: int) -> int:
	if peaceful_actor(id) or not state.actors.has(id): return 0
	var loss := State.damage(state, src, id, amount)
	if loss <= 0: return 0
	if int(state.actors[id].health) == 0:
		net_holds.erase(id)
		prism_blinds.erase(id)
	sync_quests()
	present()
	return loss

func receive_blast(at: Vector3, source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var region := Blast.region_at(source, at)
	if region < 0: return result
	var candidates := Blast.candidate_regions(source, region, Vector2(at.x, at.z))
	var accepted := 0
	# Placement order stands in for the native region actor linked lists (candidate cap 50).
	for row in src.actors:
		var id := str(int(row.actor))
		if not bool(state.actors[id].present) or int(state.actors[id].health) <= 0: continue
		if not Blast.eligible(int(row.flags), 3): continue # Native creature object class.
		var point: Vector3 = bodies[id].global_position
		if not Blast.region_at(source, point) in candidates: continue
		accepted += 1
		if accepted > int(source.native_candidate_cap): break
		var loss := environment_damage(id, Blast.damage(at, point, source))
		if loss > 0: result[id] = loss
	return result

## Lead R143: rescue is a peaceful outcome, exclusive of death/staff.
func peaceful_actor(id:String)->bool:
	return id=="57" and bool(host.quest_state.get("dark_halls_rix",{}).get("rescued",false))
