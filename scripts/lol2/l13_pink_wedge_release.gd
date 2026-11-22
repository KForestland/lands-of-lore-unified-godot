extends Node
## Wedge release, the safety net behind the overhang trim (owner save 04-56-17 on r19o, Grok 2026-11-15 12:07Z; DEVIATIONS row 0666): a jump from one tread
## can rise into the plate above it and leave the capsule hanging on the next tread's outer edge, off the floor and
## unable to jump again (the contact is nearly vertical, so no floor). When the body is airborne on the pink stair and
## has not moved for half a second, it is stepped a few units off that edge so it falls back onto the tread below and
## the player can jump again. Nothing is drawn or said; the stair keeps its drawn treads.
const WEDGE_SECONDS := 0.5
const WEDGE_STEP := 4.0
var map: Node3D
var stair: AABB
var still := 0.0
var last := Vector3.INF
func _physics_process(delta: float) -> void:
	var player = map.get("player")
	if not player is CharacterBody3D or get_tree().paused: return
	var at: Vector3 = player.position
	if player.is_on_floor() or not stair.has_point(at) or at.distance_to(last) > 0.05:
		still = 0.0; last = at; return
	still += delta
	if still < WEDGE_SECONDS: return
	var away := Vector3.ZERO
	for i in player.get_slide_collision_count():
		var n: Vector3 = player.get_slide_collision(i).get_normal()
		away += Vector3(n.x, 0.0, n.z)
	if away.length() < 0.01: return
	player.position += away.normalized() * WEDGE_STEP
	player.velocity = Vector3(0.0, minf(player.velocity.y, 0.0), 0.0)
	still = 0.0; last = player.position
	map.set_meta("pink_wedge_releases", int(map.get_meta("pink_wedge_releases", 0)) + 1)
