extends "res://scripts/lol2/scripted_creature_audio.gd"
## The source outcome has0HP but plays selector10, not the generic death8 clip.
func pose(id: String) -> Dictionary:
	var captain=population.host.get("captain")
	if id=="56" and captain!=null and captain.state!=null and captain.state.has("source"):
		var c: Dictionary=captain.state.source.captain
		if c.present and int(c.selector) in [10,11,12]:
			return {"definition":"0","selector":int(c.selector),"time":float(captain.state.pose) if int(c.selector)==10 else 0.0,"loop":0.0}
	return super.pose(id)
