extends "res://scripts/lol2/scripted_creature_audio.gd"
## Definition4 population pose adapter; shared players, PCM persistence and pause.
## Idle is the existing frozen front pose, so no invented repeating idle cue.
func pose(id: String) -> Dictionary:
	var visual: Dictionary=population.state.visuals[id]
	var live: Dictionary=population.state.live[id]
	var result: Dictionary={"definition":"4","selector":1,"time":0.0,"loop":0.0}
	if visual.action==14:
		result.selector=9 if visual.elapsed<2.5 else 10
		result.time=float(visual.elapsed) if result.selector==9 else 0.0
	elif visual.action==9:
		result.selector=7;result.time=float(visual.elapsed)
	elif live.mode==population.State.ATTACK:
		result.selector=6;result.time=float(live.elapsed)
	elif live.mode==population.State.PURSUE:
		result.selector=2;result.time=float(population.clocks[id]);result.loop=9.0/8.0
	return result
