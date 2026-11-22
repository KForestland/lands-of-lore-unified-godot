extends Node3D
## Grok 2026-11-16 19:02Z (owner road, r19o8): in Belial's Laboratory, past the Horn, every heading off the ramp at
## (-217, -1378) but one left the floor and fell to H -344. The ramp is region 613 (floor -25..-12, no nav links); its south
## side is source wall 7181 (-234,-1396)->(-56,-1367), drawn only from -25 up to 0 - a riser under the walking surface - so
## the region-edge rule, which blocks a wall's own height, stops nothing; east of x -234 that side opens onto no region. The
## earned road (c10_l19a_route) runs along the ramp to its west end and turns into the corridor (region 28) at x -234..-250.
## Modern adapter (lead 2026-11-16, DEVIATIONS): a collision fence along 7181 (6 out over the void) from x -222 to -56, from below the ramp to 70
## above it (collision only, drawing unchanged), and a screen line on the ramp naming the turn.
const A := Vector2(-234, -1396)
const B := Vector2(-56, -1367)
const FROM_X := -222.0
const BOTTOM := -40.0
const TOP := 70.0
const RAMP := 613
## Set 6 out from the drawn edge, over the void: the earned walk (act3_walk_l19a) hugs the edge about 16 from it and the
## fence on the line itself stalled it; a body against the fence still stands about 10 inside the floor edge.
const OUT := 6.0
const LINE := "The corridor turns at the west end of the ramp"
var host: Node3D
var hint: Label

static func attach(map: Node3D) -> Node:
	var node = load("res://scripts/lol2/l19_lab_ledge.gd").new(); node.host = map; node.name = "L19LabLedge"; map.add_child(node); return node

static func start() -> Vector2:
	return A.lerp(B, (FROM_X - A.x) / (B.x - A.x))

func _ready() -> void:
	var along := (B - A).normalized()
	var outward := Vector2(along.y, -along.x)  # south side of the ramp
	var a := start() + outward * OUT
	var b := B + outward * OUT
	var run := a.distance_to(b)
	var body := StaticBody3D.new(); body.name = "RampFence"; body.collision_layer = 1; body.collision_mask = 0; add_child(body)
	var box := BoxShape3D.new(); box.size = Vector3(run, TOP - BOTTOM, 2.0)
	var shape := CollisionShape3D.new(); shape.shape = box
	var x_axis := Vector3(along.x, 0, along.y)
	var mid := (a + b) * 0.5
	shape.transform = Transform3D(Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)), Vector3(mid.x, (TOP + BOTTOM) * 0.5, mid.y))
	body.add_child(shape)
	hint = preload("res://scripts/lol2/interaction_hint_label.gd").attach(self, Vector2(24, 425))

func _process(_delta: float) -> void:
	hint.text = ""
	if not is_instance_valid(host.player) or host.flying or not host.starting_magic.world_active(): return
	if host.progression != null and host.progression.region_at(host.player.position) == RAMP: hint.text = LINE
