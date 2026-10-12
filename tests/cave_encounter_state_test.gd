extends SceneTree

const State = preload("res://scripts/lol2/cave_encounter_state.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var timed := State.new()
	timed.configure_attack(12, 16, 8.0)
	check(timed.windup_time == 1.5 and timed.recovery_time == 0.5, "Recovered marker partitions provisional playback")
	timed.advance(0.01, 20, true)
	check(timed.attack_elapsed() == 0.0, "Attack begins at frame zero")
	check(timed.advance(1.375, 20, true) == 0, "Frame eleven cannot deal early damage")
	check(timed.attack_elapsed() == 1.375, "Displayed attack clock follows combat clock")
	check(timed.advance(0.125, 20, true) == 6 and timed.attack_elapsed() == 1.5, "Frame twelve deals damage on shared clock")
	check(timed.advance(0.25, 20, true) == 0, "Impact cannot repeat during recovery")
	timed.advance(0.25, 20, true)
	check(timed.phase == State.Phase.WINDUP and timed.attack_elapsed() == 0.0, "Next attack resets shared clock")
	var state := State.new()
	state.advance(0.1, 100, false)
	check(state.phase == State.Phase.IDLE, "Obstructed enemy remains idle")
	state.advance(0.1, 250, true)
	check(state.phase == State.Phase.IDLE, "Enemy ignores distant player")
	state.advance(0.1, 100, true)
	check(state.phase == State.Phase.PURSUING, "Visible nearby player starts pursuit")
	check(state.advance(0.1, 30, true) == 0 and state.phase == State.Phase.WINDUP, "Melee starts telegraph without immediate damage")
	check(state.advance(State.WINDUP_TIME / 2.0, 30, true) == 0, "Windup protects reaction time")
	check(state.advance(State.WINDUP_TIME / 2.0, 30, false) == 0, "Obstacle at impact blocks enemy damage")
	check(state.phase == State.Phase.RECOVERY, "Miss still incurs recovery")
	state.advance(State.RECOVERY_TIME, 30, true)
	check(state.phase == State.Phase.WINDUP, "Attack waits through recovery")
	check(state.advance(State.WINDUP_TIME, 80, true) == 0, "Moving out of reach dodges attack")
	state.advance(State.RECOVERY_TIME, 30, true)
	check(state.advance(State.WINDUP_TIME, 30, true) == 6 and state.player_health == 24, "In-range impact deals one damage event")
	check(state.advance(0.1, 30, true) == 0 and state.player_health == 24, "Recovery prevents repeated damage")
	check(not state.strike(false, true, true), "Out of reach strike misses")
	check(not state.strike(true, true, true), "Miss consumes strike cooldown")
	state.advance(0.45, 1000, false)
	check(not state.strike(true, false, true), "Looking away misses")
	state.advance(0.45, 1000, false)
	check(not state.strike(true, true, false), "Blocked player strike misses")
	for hit in range(3):
		state.advance(0.45, 1000, false)
		check(state.strike(true, true, true), "Valid strike lands")
		check(not state.strike(true, true, true), "Rapid repeat cannot deal damage")
	check(state.enemy_health == 0 and state.phase == State.Phase.DEFEATED, "Enemy defeat is terminal")
	check(state.advance(100, 0, true) == 0, "Defeated enemy cannot attack")
	check(not state.enter_exit(false, true), "Defeat alone cannot complete section")
	check(not state.enter_exit(true, false), "Collection without exit entry cannot complete")
	check(state.enter_exit(true, true), "Defeat plus collection plus exit completes section")
	check(not state.enter_exit(true, true) and state.completion_count == 1, "Repeated trigger is idempotent")
	state = State.new()
	check(not state.enter_exit(true, true), "Living enemy blocks progression")
	state.player_health = 3
	state.advance(0.1, 20, true)
	check(state.advance(State.WINDUP_TIME, 20, true) == 3 and state.player_health == 0, "Fatal damage clamps health at zero")
	check(not state.strike(true, true, true), "Defeated player cannot strike")
	check(state.advance(100, 20, true) == 0, "No repeated damage after player defeat")
	state.enemy_health = 0
	check(not state.enter_exit(true, true), "Defeated player cannot complete objective")
	print("Encounter state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
