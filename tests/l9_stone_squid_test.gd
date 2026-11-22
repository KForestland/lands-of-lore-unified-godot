extends SceneTree
## Owner r17 18-19-21. Approach the stone squid at its placement. It stays, and the plasma bolt hits.
const Level := preload("res://scripts/lol2/dragon_level.gd")
const Host := preload("res://scripts/lol2/act2_creatures.gd")
const PLACE := Vector3(4883.0, 2.0, -4535.0)
const START := Vector3(4682.0, 32.0, -4512.0)
const HOLD := 140.0
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL squid: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func plasma_hit(creatures: Host) -> bool:
	if creatures.plasma_bolts == null:
		return false
	var rows: Variant = creatures.plasma_bolts.get("requests")
	if not rows is Array:
		return false
	for row in rows as Array:
		if not row is Dictionary:
			continue
		var request: Dictionary = row
		if str(request.get("kind")) == "plasma" and str(request.get("to")) == "player":
			return true
	return false

func run() -> void:
	var scene: Level = load("res://scenes/lol2/dragon_level.tscn").instantiate() as Level
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not check(scene.ready_for_review, "dragon level ready"):
		quit(1)
		return
	var creatures: Host = scene.act2_creatures as Host
	if not check(creatures.anchored("58") and not creatures.anchored("61") and not creatures.anchored("68"), "only actor 58 is held"):
		quit(1)
		return
	var defs: Dictionary = creatures.src["definitions"]
	var row: Dictionary = defs["0"]
	var clips: Dictionary = row["clips"]
	var attacks: Array = clips["attacks"]
	var attack: Dictionary = attacks[0]
	var hits: Array = attack["hits"]
	var first: Array = hits[0]
	if not check(int(attack["selector"]) == 3 and int(first[0]) == 4, "selector 3 frame 4"):
		quit(1)
		return
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	creatures.set_physics_process(false)
	# Headless has no captured mouse. This is the same admission the earned walks use.
	scene.starting_magic.set("interface_request", true)
	scene.player.position = START
	var before: int = int(scene.starting_magic.health())
	if not check(flat(scene.player.position, PLACE) > 180.0, "start is out of melee"):
		quit(1)
		return
	var approached: bool = false
	for _tick in 160:
		await physics_frame
		var delta: Vector3 = PLACE - scene.player.position
		delta.y = 0.0
		if flat(scene.player.position, PLACE) <= HOLD:
			approached = true
			scene.player.velocity = Vector3.ZERO
		else:
			scene.player.velocity = delta.normalized() * 80.0
			scene.player.velocity.y = -32.0
			scene.player.move_and_slide()
		creatures.advance(1.0 / 60.0)
		if approached and creatures.plasma_bolts != null:
			break
	if not check(approached, "walked in toward the squid"):
		quit(1)
		return
	var hit: bool = false
	for _wait in 360:
		await physics_frame
		scene.player.velocity = Vector3(0.0, -32.0, 0.0)
		scene.player.move_and_slide()
		creatures.advance(1.0 / 60.0)
		if plasma_hit(creatures):
			hit = true
			break
	var squid: CharacterBody3D = creatures.bodies["58"] as CharacterBody3D
	var stayed: float = flat(squid.global_position, PLACE)
	if not check(stayed < 1.0, "actor 58 stayed at its placement"):
		quit(1)
		return
	if not check(flat(scene.player.position, PLACE) > 80.0, "the bolt was ranged"):
		quit(1)
		return
	var live: Dictionary = creatures.state.live["58"]
	var bolts: int = 0
	if creatures.plasma_bolts != null:
		var saved: Variant = creatures.plasma_bolts.get("saved")
		if saved is Dictionary:
			var packet: Dictionary = saved
			var flying: Variant = packet.get("bolts", [])
			if flying is Array:
				bolts = (flying as Array).size()
	if not hit:
		print("squid trace mode ", int(live.mode), " hitflag ", bool(live.hit), " bolts ", bolts, " health ", int(scene.starting_magic.health()), " before ", before, " stay ", stayed, " range ", flat(scene.player.position, PLACE), " player ", scene.player.position, " squid ", squid.global_position, " world ", creatures.world_active())
	if not check(hit and int(scene.starting_magic.health()) < before, "the plasma bolt hit"):
		quit(1)
		return
	print("PASS squid: approached actor 58 at (4883,-4535), it stayed, and the plasma bolt hit")
	quit(0)
