extends "res://tests/museum_aloe_escape_test.gd"
## Candidate niche detour from original escape region1459; requires rendered qualification.
## Inherits supplied walkway/open-lock prerequisites. No post-start teleports/grants.
const Scroll = preload("res://scripts/lol2/museum_scroll_state.gd")
var scroll_events: Array = []
func route_portals() -> Array:
	var original: Array = super.route_portals()
	var detour: Array = [{"region": 1454, "xz": [-1958.5, -1126.5], "floor": 0}, {"region": 1462, "xz": [-1953.0, -1132.0], "floor": 0}, {"region": 1461, "xz": [-1945.0, -1132.0], "floor": 0}, {"region": 1453, "xz": [-1930.0, -1132.0], "floor": 0}, {"region": 1445, "xz": [-1922.5, -1132.0], "floor": 0}, {"region": 1447, "xz": [-1906.0, -1128.0], "floor": 0}, {"region": 1439, "xz": [-1900.5, -1133.0], "floor": 0}, {"region": 1438, "xz": [-1885.0, -1134.5], "floor": 0}, {"region": 1444, "xz": [-1878.0, -1136.0], "floor": 0}]
	var result: Array = []
	for portal in original:
		result.append(portal.duplicate(true))
		if int(portal.region) == 1459:
			result.append_array(detour)
			for i in range(detour.size()-2,-1,-1): result.append(detour[i].duplicate(true))
			result.append(portal.duplicate(true))
	return result
func check_route_pickups() -> bool:
	if not super.check_route_pickups(): return false
	var owner = museum.scroll_pickups
	for i in 5:
		if owner.state.taken[i]: continue
		var target: Vector3 = owner.pickups[i].global_position
		if museum.camera.global_position.distance_to(target)>95: continue
		museum.camera.look_at(target)
		if owner.offered()!=i: continue
		press_e()
		if not check(owner.state.taken[i] and museum.carried_collected.count(Scroll.IDS[i])==1,"Route E failed for scroll "+Scroll.IDS[i]): return false
		var pos: Vector3 = museum.player.global_position
		scroll_events.append({"id":Scroll.IDS[i],"position":[pos.x,pos.y,pos.z],"form":museum.player_form})
	return true
func check_route_pickups_complete() -> bool:
	if not check(scroll_events.size()==5,"Niche route missed scrolls: %s"%[scroll_events]): return false
	for i in 5:
		if not check(museum.scroll_pickups.state.taken[i] and not museum.scroll_pickups.state.consumed[i] and not museum.scroll_pickups.pickups[i].visible and museum.carried_collected.count(Scroll.IDS[i])==1,"Reload lost scroll "+Scroll.IDS[i]): return false
	if not super.check_route_pickups_complete(): return false
	print("PASS five scrolls collected with production E on walked escape detour: ",JSON.stringify(scroll_events))
	return true
