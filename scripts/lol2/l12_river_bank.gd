extends Node3D
## Owner F10 2026-11-16T16-27-05 (r19o8, lead pick B): beside the glacier bank he jumped short off the ice floe and stood
## in the river bed (-1190). The snow bank (regions 998-1003) rises 100 to the bank floor (-1090) at 55-67 degrees, past
## the body's floor angle, and the river bed has no other way up; the only exit was the next floe, which nothing said.
## Modern adapter (DEVIATIONS): invisible steps of packed snow in front of the six bank faces (rises of 25 under the
## 32 step-up, treads of 20, the top tread flush with the bank over the slope), so held W walks from the river bed up onto the bank; a screen line in the river bed (here:
## walk up the bank; elsewhere: step back onto the next floe) and on a floe passing the bank (step off and walk: the
## floe passes 311 or more from the bank, out of a plain jump's reach). Source faces unchanged.
const SLOPES := [ # region: bottom edge (-1190) a, b; top edge (-1090) c, d - native x, z (from L12_CM area.json)
	[998, Vector2(3322, -12339), Vector2(3418, -12433), Vector2(3484, -12407), Vector2(3391, -12299)],
	[999, Vector2(3228, -12284), Vector2(3322, -12339), Vector2(3391, -12299), Vector2(3272, -12262)],
	[1000, Vector2(3144, -12218), Vector2(3228, -12284), Vector2(3272, -12262), Vector2(3182, -12200)],
	[1001, Vector2(3076, -12076), Vector2(3144, -12218), Vector2(3182, -12200), Vector2(3101, -12023)],
	[1002, Vector2(2978, -12004), Vector2(3076, -12076), Vector2(3101, -12023), Vector2(3019, -11947)],
	[1003, Vector2(2880, -11926), Vector2(2978, -12004), Vector2(3019, -11947), Vector2(2924, -11895)],
]
const BED := -1190.0
const BANK := -1090.0
const RISE := 25.0
const TREAD := 20.0
const BANK_FOOT := Vector2(3110, -12150)
const JUMP_FROM := Vector2(3144, -12218) # l12_river_rafts.jump_speed: the bank jump is aimed from within 400 of here
const BANK_LINE := "Walk up the snow bank to the ice bridge"
const BED_LINE := "No way up here: step back onto the next ice floe on the river"
const FLOE_LINE := "Step off the floe here and walk up the snow bank"
var host: Node3D
var steps: StaticBody3D
var hint: Label

static func attach(map: Node3D) -> Node:
	var node = load("res://scripts/lol2/l12_river_bank.gd").new(); node.host = map; node.name = "L12RiverBank"; map.add_child(node); return node

func _ready() -> void:
	steps = StaticBody3D.new(); steps.name = "SnowBankSteps"; steps.collision_mask = 0; add_child(steps)
	for row in SLOPES:
		var a: Vector2 = row[1]; var b: Vector2 = row[2]; var c: Vector2 = row[3]; var d: Vector2 = row[4]
		var top_mid := (c + d) * 0.5
		var out := ((a + b) * 0.5 - top_mid)
		var run := out.length(); out = out.normalized()
		var width := maxf(c.distance_to(d), a.distance_to(b)) + 8.0
		for k: int in [1, 2, 3, 4]:
			var top: float = BED + RISE * k
			var reach: float = run + TREAD * (4 - k)
			var box := BoxShape3D.new(); box.size = Vector3(width, top - BED + 20.0, reach)
			var shape := CollisionShape3D.new(); shape.shape = box
			var centre: Vector2 = top_mid + out * (reach * 0.5)
			var z_axis := Vector3(out.x, 0, out.y)
			shape.transform = Transform3D(Basis(Vector3.UP.cross(z_axis), Vector3.UP, z_axis), Vector3(centre.x, top - box.size.y * 0.5, centre.y))
			steps.add_child(shape)
	hint = preload("res://scripts/lol2/interaction_hint_label.gd").attach(self, Vector2(24, 425))

func rafts() -> Node:
	return host.get_node_or_null("L12RiverRafts")

func feet() -> float:
	return host.player.position.y - 32.0

## The line for where the player is; "" when none.
func line() -> String:
	if not is_instance_valid(host.player) or host.player_form != 0 or not host.starting_magic.world_active(): return ""
	var at := Vector2(host.player.position.x, host.player.position.z)
	var floes := rafts()
	if floes != null and floes.riding() >= 0:
		return FLOE_LINE if jump_window(at) else ""
	if not host.player.is_on_floor() or absf(feet() - BED) > 6.0: return ""
	if floes == null or path_distance(at) > 700.0: return ""
	return BANK_LINE if at.distance_to(BANK_FOOT) < 600.0 else BED_LINE

## On the floe leg past the bank (POINTS 2 -> 3): from 160 before its nearest point to the jump point (the ice bridge
## spans the river about 217 before it, so a jump under the bridge hits its underside) until the bank jump stops
## (400 from the jump point, l12_river_rafts.jump_speed).
static func jump_window(p: Vector2) -> bool:
	var points: Array = preload("res://scripts/lol2/l12_river_rafts.gd").POINTS
	var a: Vector2 = points[2]; var dir: Vector2 = (points[3] - a).normalized()
	var nearest: Vector2 = a + dir * (JUMP_FROM - a).dot(dir)
	var along: float = (p - nearest).dot(dir)
	return along > -160.0 and p.distance_to(JUMP_FROM) < 395.0 and absf((p - a).dot(Vector2(-dir.y, dir.x))) < 150.0

static func path_distance(p: Vector2) -> float:
	var points: Array = preload("res://scripts/lol2/l12_river_rafts.gd").POINTS
	var best := INF
	for i in points.size():
		var a: Vector2 = points[i]; var b: Vector2 = points[(i + 1) % points.size()]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best

func _process(_delta: float) -> void:
	hint.text = line()
