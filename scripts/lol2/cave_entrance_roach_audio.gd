extends "res://scripts/lol2/scripted_creature_audio.gd"
## Entrance definition5 uses the encounter's existing animation clock.
func pose(_id: String) -> Dictionary:
	var animation=population.animation
	var result: Dictionary={"definition":"5","selector":1,"time":0.0,"loop":0.0}
	if population.model.enemy_health<=0:
		result.selector=10 if animation.action_finished() else 9
		result.time=float(animation.elapsed) if result.selector==9 else 0.0
	elif animation.action_key==5:
		result.selector=6;result.time=float(animation.elapsed)
	elif animation.action_key==9:
		result.selector=7;result.time=float(animation.elapsed)
	elif population.model.phase==population.Model.Phase.PURSUING:
		result.selector=2;result.time=float(animation.elapsed);result.loop=9.0/8.0
	return result
