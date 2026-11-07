extends SceneTree
## Continuity observation is read-only on the real Hive (docs/player-continuity.md). For the fresh Hive and each Hive
## save in LOL2_EARNED_SAVES (R16 earned saves, loaded through the production quickload from a copy in user://), with
## the tree PAUSED so no clock can move:
## - consistent: Continuity.from_host() leaves the Hive owners byte-identical (the negative result);
## - stale curse.enabled, made two ways (supplied): (a) the owner's own command 24/25 setter flips curse admission while
##   the curse loop is not ticking, (b) the Hive curse checkpoint itself holds the opposite value. Observation must leave
##   the owners byte-identical, including the stale hive_curse.checkpoint.enabled;
## - field agreement: from_host() equals Continuity.from_packet() of the travel packet area_handoff() (called AFTER the
##   observation, since it refreshes curse.enabled) and the diagnostics player fields.
## - supplied branch coverage: with the live magic/fighting checkpoints emptied, the carried quest values are used, as
##   area_handoff() does (only where the save carries them).
## LOL2_CONTINUITY_PROBE=1 records the outcome without failing (reproduction on unpatched sources).
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const HIVE := "res://scenes/lol2/hive_review.tscn"
const SAVES := ["act1_broken_hive_entry.json", "act1_broken_flute_hive_return.json", "act1_broken_wax_upper_return.json", "act1_broken_earned_runes.json"]
const DIR := "user://tests/continuity_readonly/"
var failed := false
var probe := OS.get_environment("LOL2_CONTINUITY_PROBE") == "1"
var result := {"probe": probe, "states": {}}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; push_error(message); print("FAIL ", message, " ", JSON.stringify(result)); quit(1)
	return ok

## Every Hive owner the observation could touch, read directly (no packer: area_handoff() itself writes curse.enabled).
func owners(h) -> String:
	return JSON.stringify({"hive_curse": h.hive_curse.checkpoint, "curse": h.curse.state, "carried_inventory": h.carried_inventory,
		"carried_quests": h.carried_quest_checkpoint, "player_magic": h.player_magic_checkpoint, "player_reward": h.player_reward_checkpoint,
		"player_form": h.player_form, "warriors_health": h.get_node("Warriors").health, "elevator": h.elevator.checkpoint,
		"runes": h.runes.checkpoint, "wax": h.wax.collected, "monastery": h.monastery_checkpoint}, "", true)

func observe(h, label: String, state: Dictionary) -> Dictionary:
	var before := owners(h)
	var enabled_before = h.hive_curse.checkpoint.enabled
	var stale_before: bool = enabled_before != h.curse.requests_enabled()
	var observed := Continuity.from_host(h)
	var after := owners(h)
	var entry := {"stale_before": stale_before, "enabled_before": enabled_before, "enabled_after": h.hive_curse.checkpoint.enabled,
		"requests_enabled": h.curse.requests_enabled(), "owners_byte_equal": before == after, "owners_sha256_before": before.sha256_text(), "owners_sha256_after": after.sha256_text()}
	# Field agreement: the travel packet's projection (after observing) and the diagnostics fields.
	var diagnostics := Diagnostics.player_fields(h, "Hive")
	var handoff: Dictionary = h.area_handoff()
	var travel := Continuity.from_packet(handoff.inventory, handoff.quests)
	entry.travel_errors = Continuity.compare(travel, observed)
	entry.diagnostics_errors = Continuity.compare(diagnostics, observed)
	entry.fields = observed.size()
	state[label] = entry
	return entry

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var saves_dir := OS.get_environment("LOL2_EARNED_SAVES")
	var sources: Array = ["fresh"]
	if not saves_dir.is_empty(): sources += SAVES
	for source in sources:
		var h = load(HIVE).instantiate()
		root.add_child(h); current_scene = h
		for i in 30: await process_frame
		if not check(h.has_node("Warriors"), "Hive not ready"): return
		if source != "fresh":
			var copy: String = DIR + source
			var out := FileAccess.open(copy, FileAccess.WRITE); out.store_buffer(FileAccess.get_file_as_bytes(saves_dir.path_join(source))); out.close()
			var error: String = h.quickload(copy)
			if not check(error.is_empty(), "%s quickload: %s" % [source, error]): return
			for i in 6: await process_frame
		paused = true
		var state := {}
		observe(h, "consistent", state)
		# (a) Native command 24/25 route: admission flips through the owner's setter; the paused curse loop has not
		# copied it into hive_curse.checkpoint.enabled yet.
		h.curse.set_requests_enabled(not h.curse.requests_enabled())
		observe(h, "stale_admission_setter", state)
		# (b) The Hive checkpoint itself holds the opposite of the live admission.
		h.hive_curse.checkpoint.enabled = not h.curse.requests_enabled()
		observe(h, "stale_hive_checkpoint", state)
		# (c) Supplied, branch coverage: with the live Hive checkpoints empty, the projection falls back to the carried
		# quest values exactly as area_handoff() does. Restored afterwards.
		if h.carried_quest_checkpoint.has("player_reward_state") or h.carried_quest_checkpoint.has("player_magic_reward_state"):
			var kept := [h.player_magic_checkpoint, h.player_reward_checkpoint]
			h.player_magic_checkpoint = {}; h.player_reward_checkpoint = {}
			observe(h, "carried_quest_fallback", state)
			h.player_magic_checkpoint = kept[0]; h.player_reward_checkpoint = kept[1]
		result.states[source] = state
		paused = false
		h.queue_free()
		for i in 3: await process_frame
	var summary := {}
	for source in result.states:
		for label in result.states[source]:
			var e: Dictionary = result.states[source][label]
			summary["%s/%s" % [source, label]] = "stale=%s owners_equal=%s enabled %s->%s travel_errors=%d diagnostics_errors=%d" % [e.stale_before, e.owners_byte_equal, e.enabled_before, e.enabled_after, e.travel_errors.size(), e.diagnostics_errors.size()]
	for key in summary: print("STATE ", key, ": ", summary[key])
	var out := FileAccess.open(DIR + ("probe.json" if probe else "result.json"), FileAccess.WRITE); out.store_string(JSON.stringify(result, "  ", true)); out.close()
	if probe:
		print("PROBE player_continuity_readonly: ", ProjectSettings.globalize_path(DIR + "probe.json"))
		quit(); return
	for source in result.states:
		for label in result.states[source]:
			var e: Dictionary = result.states[source][label]
			if not check(e.stale_before == label.begins_with("stale"), "%s/%s: staleness setup wrong" % [source, label]): return
			if not check(e.owners_byte_equal and e.enabled_after == e.enabled_before, "%s/%s: observation changed Hive owners (enabled %s -> %s)" % [source, label, e.enabled_before, e.enabled_after]): return
			if not check(e.travel_errors.is_empty() and e.diagnostics_errors.is_empty(), "%s/%s: field disagreement travel=%s diagnostics=%s" % [source, label, e.travel_errors, e.diagnostics_errors]): return
	var cases := 0
	for source in result.states: cases += result.states[source].size()
	print("PASS player_continuity_readonly: %d Hive states, %d cases (consistent, stale via admission setter, stale Hive checkpoint, carried-quest fallback), tree paused — Continuity.from_host left every owner byte-identical incl. stale curse.enabled; fields equal the travel packet projection and diagnostics" % [result.states.size(), cases])
	quit()
