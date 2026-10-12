extends RefCounted
## Modern explicit interaction at source region1419; native event playback pending.
const APPROACH := Rect2(-4099, -1393, 82, 24)
const DESTINATION := "res://scenes/lol2/jungle_walkthrough.tscn"
static func in_approach(position: Vector3, forward: Vector3) -> bool:
	return APPROACH.has_point(Vector2(position.x,position.z)) and position.y >= -4 and position.y <= 36 and forward.dot(Vector3.FORWARD) > 0.7
