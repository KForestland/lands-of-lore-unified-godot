extends RefCounted
## Shining Path at source region1419 (the corridor mouth before the mirror). Native: region1419 event4 (entry, no
## predicate) runs g1724 (control82 animation, state1); its pass end runs g7218 (op18 move to the mirror, state3) and the
## next g7306 the L4 entry1 transition. Walking into the region therefore travels; E there also still does.
## The mirror animation and op18 move are not replayed (the scene changes at once).
const APPROACH := Rect2(-4099, -1393, 82, 24)
const DESTINATION := "res://scenes/lol2/jungle_walkthrough.tscn"
static func in_approach(position: Vector3, forward: Vector3) -> bool:
	return APPROACH.has_point(Vector2(position.x,position.z)) and position.y >= -4 and position.y <= 36 and forward.dot(Vector3.FORWARD) > 0.7
## Region entry: any facing, also mid-jump over the 24-unit strip (body height gate keeps other levels out).
static func in_region(position: Vector3) -> bool:
	return APPROACH.has_point(Vector2(position.x,position.z)) and position.y >= -4 and position.y <= 100
