extends SceneTree
## Headless: the owner-rule journal hints (2026-10-27) are data beside the flags of their planners, one per village
## stuck point of VILLAGE_INTENDED_FLOW_20261026 s7 (den: 2-7, tavern: 10, weapon shop: 8, gate: 1; CHUT: the hut).
## Classic reads none of them; the Enhanced guard text is a candidate list, not behaviour.
const Den = preload("res://scripts/lol2/thieves_den_state.gd")
const Monastery = preload("res://scripts/lol2/monastery_quest_state.gd")
const Shop = preload("res://scripts/lol2/weapon_shop_state.gd")
const Gate = preload("res://scripts/lol2/jungle_village_state.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
func shaped(hints: Array, label: String) -> void:
	check(not hints.is_empty(),label+": at least one hint")
	for h in hints:
		check(h is Dictionary and h.keys().size() == 4 and h.has("when") and h.has("flag") and h.has("hint") and h.has("enhanced_guard"),label+": four keys")
		check(not str(h.when).is_empty() and str(h.hint).length() >= 20 and not str(h.enhanced_guard).is_empty(),label+": filled")
		check(str(h.hint).find("flag") == -1 and str(h.hint).find("GV_") == -1,label+": the line is in character, no flag names")
func run() -> void:
	shaped(Den.JOURNAL_HINTS,"den")
	check(Den.JOURNAL_HINTS.size() == 6 and Den.JOURNAL_HINTS.all(func(h): return str(h.flag).is_empty() or str(h.flag) in Den.FLAGS),"den hints name den flags only")
	shaped(Monastery.CHUT_JOURNAL_HINTS,"chut")
	check(Monastery.CHUT_JOURNAL_HINTS.all(func(h): return str(h.flag).is_empty() or str(h.flag) in Monastery.CHUT_FLAGS),"chut hints name hut flags only")
	shaped(Monastery.CAN_JOURNAL_HINTS,"tavern")
	check(Monastery.CAN_JOURNAL_HINTS[0].flag in Monastery.FLAGS,"the tavern hint reads the farewell flag 34")
	shaped(Shop.JOURNAL_HINTS,"weapon shop")
	check(Shop.JOURNAL_HINTS[0].flag == "GV_KNOWLEDGE_OF_POWER_ORB" and Shop.JOURNAL_HINTS[0].flag in Monastery.GLOBALS,"the shop hint reads the orb-knowledge global")
	shaped(Gate.JOURNAL_HINTS,"village gate")
	check(Gate.JOURNAL_HINTS[0].flag in Gate.initial().keys(),"the gate hint reads a saved gate field")
	var whens := []
	for hints in [Den.JOURNAL_HINTS,Monastery.CHUT_JOURNAL_HINTS,Monastery.CAN_JOURNAL_HINTS,Shop.JOURNAL_HINTS,Gate.JOURNAL_HINTS]:
		for h in hints: whens.append(str(h.when))
	check(whens.size() == 11 and whens.size() == whens.reduce(func(acc, w): return acc if w in acc else acc + [w], []).size(),"eleven distinct stuck points: %s" % [whens])
	if failures:
		push_error("FAIL: %d journal hint checks" % failures)
		quit(1)
		return
	print("PASS village journal hints: 11 data-only hints beside their planners' flags (den 6, hut 2, tavern 1, weapon shop 1, gate 1), in character, Enhanced guard candidates listed")
	quit()
