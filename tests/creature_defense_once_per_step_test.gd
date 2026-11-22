extends SceneTree
## The creature step reads the player's defense once per physics step (e5ab2012), not once per creature. Damage must be
## IDENTICAL to before. From the owner's L8 save (local only: tmp/l8_perf_inputs, OWNER_DERIVED.md) one real creature hit
## is played through the population's own step for three setups: his gear as saved (Human), no gear (Human), and his gear
## in Beast form. The damage of the first hit in each setup must equal the numbers recorded on r19p3 17ec1001, before the
## change (EXPECTED). The defense value is printed so the two gear setups are seen to differ.
const GameSave = preload("res://scripts/lol2/game_save.gd")
const Defense = preload("res://scripts/lol2/player_defense.gd")
const SAVE := "res://tmp/l8_perf_inputs/owner_144731.json"
const SAVE_SHA := "8d7f48ea36d5b44d0b56ddc539b9ed16f69c034f41057a2bd496f91655075e0b"
const EXPECTED := {"gear": 1, "bare": 2, "beast": 2} # r19p3 17ec1001, 2026-11-18: defense 40 with his gear, 0 bare and in Beast form
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	push_error("FAIL creature defense once per step: " + m); quit(1)
func load_l8() -> Node:
	var err: String = GameSave.load_file(self, ProjectSettings.globalize_path(SAVE))
	if not err.is_empty(): fail("load: " + err); return null
	var session: Node = root.get_node("GameSession")
	for i in 3000:
		await process_frame
		var s: Node = current_scene
		if s != null and s.scene_file_path.ends_with("darker_jungle.tscn") and is_instance_valid(s.get("player")) and session.pending_resume.is_empty() and not session.changing_scene and s.is_node_ready():
			for k in 60: await physics_frame
			return s
	fail("the save did not resume L8"); return null
func one_hit(scene: Node, setup: String) -> Array:
	var c: Node = scene.get_node("Act2Creatures")
	c.set_physics_process(false)
	if setup == "bare":
		scene.equipped_armor = ""; scene.equipped_item = ""
		var st: Dictionary = scene.item_effects.state(); st["offhand"] = ""; st["accessories"] = []
	elif setup == "beast":
		scene.player_form = 1
	var p: Vector3 = scene.player.global_position
	var best := ""; var best_d := INF
	for id in c.bodies:
		var a: Dictionary = c.state.actors[id]
		if a.health <= 0 or not a.present or not a.woken or c.peaceful_actor(id) or c.anchored(id): continue
		var d: float = (c.bodies[id].global_position - p).length()
		if d < best_d: best_d = d; best = id
	if best == "": return [-1, -1, ""]
	var forward: Vector3 = -scene.camera.global_basis.z; forward.y = 0
	c.bodies[best].global_position = p + forward.normalized() * 24.0 + Vector3.UP * 2.0
	c.bodies[best].velocity = Vector3.ZERO
	scene.starting_magic.set_health(30)
	var defense: int = Defense.scalar(scene)
	for i in 600:
		var before: int = scene.starting_magic.health()
		c.advance(1.0 / 60.0)
		await physics_frame
		var lost: int = before - scene.starting_magic.health()
		if lost > 0: return [lost, defense, best]
	return [0, defense, best]
func run() -> void:
	if not FileAccess.file_exists(SAVE) or FileAccess.get_sha256(SAVE) != SAVE_SHA: return fail("owner L8 save missing or changed (local input " + SAVE + ")")
	var got := {}
	for setup in ["gear", "bare", "beast"]:
		var scene: Node = await load_l8()
		if scene == null: return
		var r: Array = await one_hit(scene, setup)
		print("CREATURE HIT setup %s creature %s defense %d damage %d" % [setup, r[2], r[1], r[0]])
		if r[0] <= 0: return fail("no hit in setup " + setup)
		got[setup] = r[0]
	if EXPECTED.is_empty(): return fail("EXPECTED not recorded yet: " + str(got))
	for setup in EXPECTED:
		if int(got.get(setup, -1)) != int(EXPECTED[setup]): return fail("setup %s damage %d, before the change %d" % [setup, got.get(setup, -1), EXPECTED[setup]])
	print("PASS creature defense once per step: one hit each with gear %d, bare %d, Beast %d, identical to r19p3" % [got.gear, got.bare, got.beast])
	quit(0)
