extends SceneTree
const Quill = preload("res://scripts/lol2/l14_quill.gd")
const Burrow = preload("res://scripts/lol2/l14_spider_burrow.gd")
const Quest = preload("res://scripts/lol2/act_one_quest_state.gd")
var failures: int = 0

class Host:
	extends Node3D
	var player: Node3D
	var quest_state: Dictionary = {}
	var flying: bool = false
	var player_form: int = 0
	func save_feedback(_message: String) -> void:
		pass

class Library:
	extends Node
	var exit_open: bool = false
	var exit_parts: Dictionary = {}
	func state() -> Dictionary:
		return {"exit": exit_open}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func stop(host: Node, code: int) -> void:
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
	quit(code)

func run() -> void:
	check(not Quill.OP20_PLAYED and Quill.SOUND_ID == 975 and Quill.SOUND_NAME == "cbalopn1.aud", "quill sound 975 stays unplayed")
	check(not Burrow.OP20_PLAYED and not Burrow.FLOOR_MOVED and not Burrow.ARM6_DECODED, "burrow sound 452 stays unplayed and the floor stays")
	check(Burrow.SOUND_ID == 452 and Burrow.SOUND_NAME == "jugcrash.aud", "burrow names jugcrash")
	check(Quill.validate(Quill.initial(), {}).is_empty() and Burrow.validate(Burrow.initial(), {}).is_empty(), "initial passage state")
	var host := Host.new()
	host.player = Node3D.new()
	host.add_child(host.player)
	var library := Library.new()
	library.name = "L14Library"
	for key in ["1614:floor", "1614:ceiling", "4197:ceiling"]:
		var part := Node3D.new()
		library.exit_parts[key] = part
		library.add_child(part)
	host.add_child(library)
	root.add_child(host)
	var quill: Node = Quill.attach(host)
	var burrow: Node = Burrow.attach(host)
	host.player.position = Quill.INKWELL
	check(not quill.use(), "a dark quill stays shut")
	check(quill.spark(343) and not quill.use(), "one lamp stays short of the click")
	check(quill.spark(350), "the second lamp takes the spark")
	host.flying = true
	check(not quill.use(), "flying stays off the quill")
	host.flying = false
	host.player.position = Vector3(2251, 0, -5103)
	check(quill.use() and bool(quill.state().opened), "the owner point opens the quill")
	quill._physics_process(2.0)
	check(is_equal_approx(library.exit_parts["1614:floor"].position.y, -30.0), "region 1614 floor uses the quill word")
	check(is_equal_approx(library.exit_parts["1614:ceiling"].position.y, 20.0), "region 1614 ceiling uses the quill word")
	check(is_equal_approx(library.exit_parts["4197:ceiling"].position.y, 10.0), "region 4197 ceiling shares the ten-unit shift")
	library.exit_parts["1614:floor"].position.y = 50.0
	library.exit_open = true
	quill._physics_process(0.1)
	check(is_equal_approx(library.exit_parts["1614:floor"].position.y, 50.0), "the library exit keeps its own words")
	host.player.position = Vector3(0, 0, 0)
	check(not burrow.use(), "a far E leaves the burrow")
	host.player.position = Burrow.AT
	check(burrow.use() and bool(host.quest_state.l14_spider_burrow.struck), "the owner point records the burrow")
	check(host.player.position.is_equal_approx(Burrow.AT), "the burrow leaves the body in place")
	var quests: Dictionary = Quest.initial()
	quests.l14_quill = quill.state()
	quests.l14_spider_burrow = burrow.state()
	check(Quest.validate(quests).is_empty(), "quest validate")
	quests.l14_quill = {"version": 1, "lit": [1], "opened": false, "elapsed": 0.0}
	check(not Quest.validate(quests).is_empty(), "a stray lamp is refused")
	if failures == 0: print("PASS l14 temple passages: quill words and burrow receipt")
	await stop(host, 1 if failures else 0)
