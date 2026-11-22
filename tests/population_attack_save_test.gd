extends SceneTree
## Source-state save regression: no player scene, teleports or combat-rule substitutions.
const State = preload("res://scripts/lol2/scripted_creature_state.gd")

func check(ok: bool, message: String) -> bool:
	if not ok:
		print("FAIL population attack save: ", message)
		quit(1)
	return ok

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for pair in [["L14_HT", "68"], ["L17_HC", "24"]]:
		var area: String = pair[0]
		var id: String = pair[1]
		var src := State.source("res://scripts/lol2/act2_populations/" + area + ".json")
		var row := State.actor_row(src, id)
		var count: int = src.definitions[str(int(row.definition))].clips.attacks.size()
		if not check(count == 4, area + " source has four clips"): return
		var state := State.initial(src)
		State.wake(state, id)
		State.advance_clocks(state, src, 10.0)
		if not check(State.ready_to_fight(state, src, id), area + " actual source actor ready"): return
		var seen: Array = []
		for tick in 1800:
			# Protection avoids changing a player's health; the existing clock still completes and rotates clips.
			State.advance_live(state, src, id, 1.0 / 60.0, 20.0, true, true, 30)
			var variant: int = int(state.live[id].attack)
			if variant in seen: continue
			seen.append(variant)
			var saved: Dictionary = JSON.parse_string(JSON.stringify(state, "", true, true))
			var error := State.validate(saved, src)
			if not check(error.is_empty(), area + " source variant " + str(variant) + " must save: " + error): return
			if not check(State.canonical(saved, src) == State.canonical(state, src), area + " exact JSON restore"): return
			if seen.size() == count: break
		if not check(seen.size() == count, area + " existing clock reached every clip"): return
		for invalid in [count, -1, 0.5]:
			var bad := state.duplicate(true)
			bad.live[id].attack = invalid
			if not check(not State.validate(bad, src).is_empty(), area + " invalid variant rejected: " + str(invalid)): return
	# Older validators accepted 0..2 even for shorter tables; retain those serialized aliases unchanged.
	var legacy_src := State.source("res://scripts/lol2/cave_guard_population_source.json")
	var legacy := State.initial(legacy_src)
	var alias_id := ""
	for row in legacy_src.actors:
		var count: int = legacy_src.definitions[str(int(row.definition))].clips.attacks.size()
		if count > 0 and count < 3:
			alias_id = str(int(row.actor))
			break
	if not check(not alias_id.is_empty(), "real shorter source table for legacy alias"): return
	legacy.live[alias_id].attack = 2
	if not check(State.validate(legacy, legacy_src).is_empty(), "old index-2 alias remains readable"): return
	if not check(State.canonical(legacy, legacy_src).live[alias_id].attack == 2, "legacy alias is not rewritten"): return
	print("PASS generated four-clip L14/L17 attack states save/restore exactly; invalid indices refused; legacy 0..2 aliases preserved")
	quit()
