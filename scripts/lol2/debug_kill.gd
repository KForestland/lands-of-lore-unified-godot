extends Node
## Debug mode only (owner decision D12, 2026-11-10): for playtesters, never for normal players.
## Ctrl+K defeats the creature under the crosshair; Ctrl+Shift+K defeats every hostile creature within REACH.
## Needs the launch flag --debug-mode (or --developer-tools). Each kill goes through the population's own damage path,
## so death callers, rewards and saves stay as consistent as a real fight; peaceful actors are refused as usual.
const REACH := 900.0
## Story actors the key never touches: Daniel (L8 actor 23) fights the initiation and must live.
const STORY_ACTORS := {"L8_SJ": ["23"]}
static var forced := false
var host: Node

static func enabled() -> bool:
	if forced: return true
	var args := OS.get_cmdline_user_args()
	return "--debug-mode" in args or "--developer-tools" in args

static func attach(map: Node) -> Node:
	if not enabled(): return null
	var node = load("res://scripts/lol2/debug_kill.gd").new()
	node.host = map
	node.name = "DebugKill"
	map.add_child(node)
	return node

func population() -> Node:
	return host.get("act2_creatures") as Node

func kill(id: String) -> bool:
	var pop := population()
	if pop == null or not pop.state.actors.has(id): return false
	var actor: Dictionary = pop.state.actors[id]
	if not bool(actor.present) or int(actor.health) <= 0 or pop.peaceful_actor(id): return false
	if id in STORY_ACTORS.get(str(pop.get("area_id")), []): return false
	return pop.receive_damage(id, int(actor.health), true)

func kill_aimed() -> int:
	var pop := population()
	if pop == null: return 0
	var id: String = pop.aimed()
	return 1 if not id.is_empty() and kill(id) else 0

func kill_near() -> int:
	var pop := population()
	if pop == null: return 0
	var count := 0
	for id in pop.bodies.keys():
		if pop.bodies[id].global_position.distance_to(host.player.global_position) <= REACH and kill(str(id)): count += 1
	return count

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K and event.ctrl_pressed): return
	var count := kill_near() if event.shift_pressed else kill_aimed()
	if host.has_method("save_feedback"): host.save_feedback("Debug: %d creature%s defeated." % [count, "" if count == 1 else "s"])
	get_viewport().set_input_as_handled()
