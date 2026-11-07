extends SceneTree
## Reachability probe for original world-item placements the port does not host yet (items step 2026-10-31, "reachability
## first"). Opens one host scene, places each candidate at the native (x, height, -y) and reports, per row: the floor under
## it (support_y = floor hit minus the native height, physics layer 1), ceiling clearance, whether the creature-nav graph of
## the area (assets/lol2/generated/creature_nav/AREA.json) holds the point and connects it to the scene's player start
## (nav_reachable), line of sight from a standing point one reach away, and whether a RegionBlockers wall (layer 1<<9)
## stands between that point and the item. Output: one JSON {area, scene, start, rows:[...]} on stdout between PROBE_BEGIN /
## PROBE_END. Usage: godot --headless -s res://tools/probe_world_items.gd -- --scene res://... --area L3_DH --rows FILE.json
const Nav := preload("res://scripts/lol2/creature_navigation.gd")
const REACH := 96.0
var args := {}
func _initialize() -> void:
	var list := OS.get_cmdline_user_args()
	for i in list.size():
		if list[i].begins_with("--") and i + 1 < list.size(): args[list[i].trim_prefix("--")] = list[i + 1]
	run.call_deferred()
func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	q.hit_from_inside = false
	return space.intersect_ray(q)
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load(str(args.scene)).instantiate()
	root.add_child(scene)
	for i in 8: await process_frame
	for i in 6: await physics_frame
	var player: Node3D = scene.get("player")
	if player == null: player = scene.find_child("Player", true, false)
	var start: Vector3 = player.global_position if player != null else Vector3.ZERO
	var exclude: Array = [player.get_rid()] if player is CollisionObject3D else []
	var space := root.get_world_3d().direct_space_state
	var nav := Nav.new()
	var nav_error := nav.load_graph("res://assets/lol2/generated/creature_nav/%s.json" % str(args.area))
	var blockers: Node = scene.find_child("RegionBlockers", true, false)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(str(args.rows)))
	var controls := {"L3_DH": [[-1399, -183.4, -1096], [-1585, -170, -1102], [-1937, 30, -1168]], "L8_SJ": [[7404.25, 32, 2009.75]], "L7_DH": []}
	var control_rows := []
	for c in controls.get(str(args.area), []):
		var cp := Vector3(float(c[0]), float(c[1]), float(c[2]))
		var cr := {"control": [cp.x, cp.y, cp.z]}
		if nav_error.is_empty():
			cr.nav_region = nav.region_at(cp)
			cr.nav_reachable = cr.nav_region >= 0 and nav.next_point(start, cp, 200000) != null
		control_rows.append(cr)
	var out := []
	for r in rows:
		if str(r.area) != str(args.area): continue
		var n: Array = r.native_position
		var pos := Vector3(float(n[0]), float(n[2]), -float(n[1]))
		var row := {"row": int(r.row), "name": str(r.name), "definition": int(r.definition), "flags": int(r.flags), "region": int(r.region), "position": [pos.x, pos.y, pos.z]}
		var down := ray(space, pos + Vector3(0, 4, 0), pos - Vector3(0, 512, 0), 1, exclude)
		row.support_y = (float(down.position.y) - pos.y) if not down.is_empty() else null
		row.support = str(down.collider.name) if not down.is_empty() else ""
		var up := ray(space, pos + Vector3(0, 4, 0), pos + Vector3(0, 512, 0), 1, exclude)
		row.ceiling_dy = (float(up.position.y) - pos.y) if not up.is_empty() else null
		# Vertical stack: every layer-1 surface from 1500 above down to 1500 below (top faces), relative to the item.
		var stack := []
		var from := pos + Vector3(0, 1500, 0)
		for k in 8:
			var hit := ray(space, from, pos - Vector3(0, 1500, 0), 1, exclude)
			if hit.is_empty(): break
			stack.append(snappedf(float(hit.position.y) - pos.y, 0.01))
			from = Vector3(hit.position.x, float(hit.position.y) - 0.5, hit.position.z)
		row.stack_above_below = stack
		# Inside a solid? A ray that starts at the item and leaves upward hits a backface only when it is inside a concave shape.
		var inside_q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1, 0), pos + Vector3(0, 1500, 0), 1, exclude)
		inside_q.hit_from_inside = true
		var inside := space.intersect_ray(inside_q)
		row.inside_hit_dy = (float(inside.position.y) - pos.y) if not inside.is_empty() else null
		row.nav_graph = nav_error.is_empty()
		if nav_error.is_empty():
			var floor_y: float = pos.y if row.support_y == null else pos.y + float(row.support_y)
			var here := Vector3(pos.x, floor_y, pos.z)
			row.nav_region = nav.region_at(here)
			row.nav_region_floor_ceiling = [nav.regions[row.nav_region][1], nav.regions[row.nav_region][2]] if row.nav_region >= 0 else []
			row.nav_start_region = nav.region_at(start)
			row.nav_reachable = row.nav_region >= 0 and row.nav_start_region >= 0 and nav.next_point(start, here, 200000) != null
		# Standing point one reach back toward the start, at eye height; line of sight to the item's centre.
		# Line of sight from four standing points one reach away at eye height (any clear one counts), and the blocker walls.
		var aim := pos + Vector3(0, 12, 0)
		var clear := []
		var walls := []
		for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var eye: Vector3 = pos + dir * (REACH * 0.6) + Vector3(0, 40, 0)
			var los := ray(space, eye, aim, 1, exclude)
			if los.is_empty(): clear.append([dir.x, dir.z])
			if blockers != null and not ray(space, eye, aim, 1 << 9, exclude).is_empty(): walls.append([dir.x, dir.z])
		row.line_of_sight = not clear.is_empty()
		row.los_clear_from = clear
		row.blocker_wall = not walls.is_empty()
		row.blocker_wall_from = walls
		out.append(row)
	print("PROBE_BEGIN")
	print(JSON.stringify({"area": str(args.area), "scene": str(args.scene), "start": [start.x, start.y, start.z], "nav_graph": nav_error, "start_region": nav.region_at(start) if nav_error.is_empty() else -1, "controls": control_rows, "rows": out}))
	print("PROBE_END")
	quit(0)
