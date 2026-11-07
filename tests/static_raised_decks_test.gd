extends SceneTree
## Owner r12h F10 2026-10-26 12:27 at (-3047,-2175): "I fall through the bridge". The deck over the stream is static
## assembly 227 (source-solid, 10 high at h 85), which the MIN_SOLID_HEIGHT adapter left walk-through. Thin source-solid
## boxes with a walkable footprint (both sides >= 48) whose base is higher above the floor under their centre than the
## tallest player form are decks and stay solid. This measures that rule over every Jungle thin box, requires exactly
## RAISED_DECKS, and walks across deck 227 with ordinary grounded movement.
const Assemblies := preload("res://scripts/lol2/static_assemblies.gd")
const Form := preload("res://scripts/lol2/player_form_body.gd")
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL static_raised_decks: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	scene.set_physics_process(false)
	for i in 5: await physics_frame
	var sa = scene.static_assemblies
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L4_HJ.json"))
	var drawn := {}
	for face in sa.data.faces: drawn[int(face.assembly)] = true
	var offset: Vector3 = scene.native_translation if str(sa.data.render) == "indexed" else Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var measured: Array = []
	var thin := 0
	for key in parsed.boxes:
		var b: Dictionary = parsed.boxes[key]
		if int(b.height) >= Assemblies.MIN_SOLID_HEIGHT or bool(b.get("scripted", false)) or not drawn.has(int(key)): continue
		thin += 1
		if float(b.width) < 48 or float(b.depth) < 48: continue
		var base := Vector3(float(b.x), float(b.h), -float(b.y)) + offset
		var query := PhysicsRayQueryParameters3D.create(base + Vector3.DOWN * 0.5, base + Vector3.DOWN * 3000)
		query.collision_mask = ~Assemblies.SCENERY_LAYER & 0xFFFFFFFF
		query.exclude = [scene.player.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and base.y - hit.position.y > Form.HEIGHTS.max(): measured.append(int(key))
	measured.sort()
	var listed: Array = Assemblies.RAISED_DECKS["L4_HJ"].duplicate()
	listed.sort()
	if measured != listed: return fail("Raised decks measured %s, listed %s" % [measured, listed])
	for id in listed:
		if not sa.solid_bodies.has(id): return fail("Deck %d has no solid body" % id)
	# Ordinary grounded walking across deck 227, bank to bank along its width axis.
	var deck: StaticBody3D = sa.solid_bodies[227]
	var axis: Vector3 = deck.global_transform.basis.x.normalized()
	var player: CharacterBody3D = scene.player
	player.global_position = deck.global_position + axis * 170 + Vector3.UP * 40
	player.velocity = Vector3.ZERO
	for i in 60:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	if not player.is_on_floor(): return fail("Not grounded on the east bank: %s" % player.global_position)
	var start_y := player.global_position.y
	var low := start_y
	var resets: int = scene.resets
	for i in 600:
		await physics_frame
		scene.move_grounded(-axis, 1.0 / 60.0)
		low = minf(low, player.global_position.y)
		if (player.global_position - deck.global_position).dot(axis) < -170: break
	if (player.global_position - deck.global_position).dot(axis) >= -170: return fail("Walk across stopped at %s" % player.global_position)
	if low < start_y - 30 or scene.resets != resets: return fail("Dropped while crossing: low %.1f from %.1f" % [low, start_y])
	print("PASS static_raised_decks: %d thin Jungle boxes, raised decks %s solid; walked across deck 227 grounded (lowest %.1f, start %.1f)" % [thin, listed, low, start_y])
	quit(0)
