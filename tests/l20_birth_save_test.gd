extends SceneTree
## BK16. A host may clear a creature the source placed and leave its combat state.
## A creature the source never placed must still be quiet, or the save is refused.
const State = preload("res://scripts/lol2/scripted_creature_state.gd")
const Live = preload("res://scripts/lol2/creature_live_rules.gd")
const L20 := "res://scripts/lol2/act2_populations/L20_BB.json"
const GUARDS := "res://scripts/lol2/cave_guard_population_source.json"
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func _initialize() -> void:
	run.call_deferred()

func rise_full(src: Dictionary, id: String) -> float:
	var row: Dictionary = State.actor_row(src, id)
	return State.clip_seconds(int(src.definitions[str(int(row.definition))].clips.rise.frames))

func run() -> void:
	var src: Dictionary = State.source(L20)
	var state: Dictionary = State.initial(src)
	check(State.validate(state, src).is_empty(), "L20 initial population")
	var placed: Dictionary = state.duplicate(true)
	placed.actors["35"].present = false
	placed.actors["35"].woken = true
	placed.actors["35"].rise = rise_full(src, "35")
	placed.actors["35"].death = 0.0
	placed.live["35"].mode = Live.PURSUE
	placed.live["35"].elapsed = 0.0
	placed.live["35"].hit = false
	var pursued: String = State.validate(placed, src)
	check(pursued.is_empty(), "a cleared placed creature may still be pursuing (%s)" % pursued)
	var wounded: Dictionary = placed.duplicate(true)
	wounded.actors["35"].health = int(State.actor_row(src, "35").health) - 1
	wounded.live["35"].mode = Live.IDLE
	var wounded_error: String = State.validate(wounded, src)
	check(wounded_error.is_empty(), "a cleared placed creature may keep a lower health (%s)" % wounded_error)
	var corpse: Dictionary = placed.duplicate(true)
	corpse.actors["35"].health = 0
	corpse.live["35"].mode = Live.PURSUE
	var corpse_error: String = State.validate(corpse, src)
	check(corpse_error.is_empty(), "a cleared corpse may still be in pursue (%s)" % corpse_error)
	var never: Dictionary = State.initial(src)
	never.actors["14"].health = int(State.actor_row(src, "14").health) - 1
	var never_error: String = State.validate(never, src)
	check(never_error == "Absent creature has live state.", "an unplaced creature stays quiet (%s)" % never_error)
	var guards: Dictionary = State.source(GUARDS)
	var guard_state: Dictionary = State.initial(guards)
	guard_state.actors["54"].health = 10
	check(not State.validate(guard_state, guards).is_empty(), "cave guard 54 still cannot carry a quiet wound while unplaced")
	if failures == 0:
		print("PASS L20 birth save accepts a cleared placed creature and still refuses an unplaced one")
	quit(0 if failures == 0 else 1)
