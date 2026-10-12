extends RefCounted
## Authored capsule step-up; every candidate is swept for overhead/forward clearance.
static func try_step(body: CharacterBody3D, motion: Vector3, maximum: int = 32) -> bool:
	if not body.is_on_floor() or motion.length_squared() < 0.000001: return false
	var origin := body.global_transform
	# Match move_and_slide's recovery margin. PhysicsBody3D.test_move otherwise
	# uses its smaller default, which can report the resting floor/side wall as
	# an upward obstruction at large source-world coordinates.
	var margin := body.safe_margin
	# Look past the rounded capsule edge to find the tread at low frame speeds.
	var probe := motion.normalized() * maxf(motion.length(), 9.0)
	if not body.test_move(origin,motion,null,margin): return false
	for height in range(1,maximum+1):
		var rise := Vector3.UP * float(height)
		if body.test_move(origin,rise,null,margin): break
		var candidate := origin
		candidate.origin += rise
		if body.test_move(candidate,probe,null,margin): continue
		candidate.origin += probe
		var hit := KinematicCollision3D.new()
		if not body.test_move(candidate,Vector3.DOWN*(height+0.5),hit,margin): continue
		if hit.get_normal().dot(Vector3.UP) < cos(body.floor_max_angle): continue
		var position := candidate.origin + hit.get_travel()
		var gain := position.y - origin.origin.y
		if gain < 0.2 or gain > maximum: continue
		body.global_position = position
		return true
	return false
