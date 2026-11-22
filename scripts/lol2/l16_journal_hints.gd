extends Node
## My Journal notes for the Ancient City hourglass and the one open tower (grok M01, Kimi K18). The other three
## towers are not fields in l16_greenhouse.gd and are not invented here. Text only. Quest state is never changed.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Greenhouse = preload("res://scripts/lol2/l16_greenhouse.gd")
const JOURNAL_HINTS := [
	{"when":"l16_hourglass_leaf","flag":"l16_greenhouse","hint":"If the hourglass only chimes, the glass pyramid still wants a silver leaf.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l16_one_tower","flag":"l16_greenhouse","hint":"The tower doors are open. Turn away from them: return to the south avenue and follow the canal to the oil stair.","enhanced_guard":"same note in both editions (grok K09)"}] + ROAD + EXTRA
# Lead's 2026-11-16 main-road presentation adapter. Only Journal discovery is written.
const ROAD := [
	{"when":"l16_road_arrival","hint":"Follow the south avenue to the dry fountain. Strike the ball over it; then seek the glass pyramid and hourglass."},
	{"when":"l16_road_pyramid","hint":"Next, the glass pyramid and hourglass in the northeast. Put a Silverleaf in the pyramid."},
	{"when":"l16_road_hourglass","hint":"The Silverleaf is planted. Turn the hourglass beside the glass pyramid."},
	{"when":"l16_road_canal","hint":"Turn away from the opened tower doors. Return to the south avenue; follow the canal toward the oil stair."},
	{"when":"l16_road_stair","hint":"Follow the canal to the oil stair. Leave the west door pairs open for the return."},
	{"when":"l16_road_oil","hint":"At the oil court, leave the west doors open. Ignite the oil under the head statue, then retreat east."},
	{"when":"l16_road_bow","hint":"The oil is burning. Take the Dark Bow from the oil court, then retreat east toward the dragon room."},
	{"when":"l16_road_dragon","hint":"Next, the dragon room: return east, then north. Chop the dragon itself, not the statue by the fountain."},
	{"when":"l16_road_pad","hint":"The dragon's blood opens the way. Step onto the telepad beside it to enter the Hidden Caverns."}]
const WEST := "l16_road_west_bank"
const STARRY := "l16_road_starry"
const EXTRA := [
	{"when":WEST,"hint":"From this west bank, follow the canal east to its stair. Climb out there for the oil court; leave the west doors open."},
	{"when":STARRY,"hint":"The starry-floor route is not finished. The way on is back via the lift, south avenue, canal and oil stair."}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_journal_hints.gd").new(); n.host = map; n.name = "L16JournalHints"; map.add_child(n); return n

## "hourglass" and "plate" need an empty silverleaf. "tower" is the frame opened becomes true. No walk radius was read
## for the other towers, so the open-tower note is the saved flag on this map.
static func stuck_id(quests: Dictionary, place: String, _facts: Dictionary = {}) -> String:
	var green: Dictionary = quests.get("l16_greenhouse", {})
	if place in ["hourglass", "plate"] and str(green.get("silverleaf", "")) == "": return "l16_hourglass_leaf"
	if place == "tower" and bool(green.get("opened", false)): return "l16_one_tower"
	return ""

func places() -> Array:
	if not is_instance_valid(host): return []
	var out: Array = []
	var green = host.get_node_or_null("L16Greenhouse")
	if green != null and green.has_method("aimed"):
		if green.aimed(Greenhouse.HOURGLASS, 130.0): out.append("hourglass")
		if green.aimed(Greenhouse.PLATE, 150.0): out.append("plate")
	var state: Dictionary = host.quest_state.get("l16_greenhouse", {}) if host.get("quest_state") is Dictionary else {}
	if bool(state.get("opened", false)): out.append("tower")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, {})
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
	check_road()

## No flags are invented for completed puzzles: use the owners' actual saved fields.
static func road_stage(quests: Dictionary, notes: Array) -> int:
	if bool(quests.get("l16_dragon_room",{}).get("chopped",false)): return 8
	if "act2:L16_CA:item24" in quests.get("act2_items",{}).get("collected",[]): return 7
	if bool(quests.get("l16_se_oil",{}).get("burned",false)): return 6
	if bool(quests.get("l16_greenhouse",{}).get("opened",false)):
		if "l16_road_oil" in notes: return 5
		if "l16_road_stair" in notes: return 4
		return 3
	if not str(quests.get("l16_greenhouse",{}).get("silverleaf","")).is_empty(): return 2
	if bool(quests.get("l16_dry_fountain",{}).get("broken",false)): return 1
	return 0

func record_line(id: String) -> bool:
	if not MyJournal.discover(host,id): return false
	host.save_feedback(MyJournal.hints()[id])
	return true

func check_road() -> void:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return
	var body: Variant = host.get("player")
	if not is_instance_valid(body): return
	var magic: Variant = host.get("starting_magic")
	if is_instance_valid(magic) and not magic.world_active(): return
	var pos: Vector3 = body.global_position
	var stage := road_stage(host.quest_state,MyJournal.notes(host))
	if stage in [3,4] and absf(pos.y-32.0)<180.0:
		if Vector2(pos.x+1273.0,pos.z-13725.0).length()<300.0: stage=5
		elif pos.z>11500.0: stage=4
	record_line(ROAD[stage].when)
	if Vector2(pos.x+3754.9,pos.z-13400.4).length()<200.0 and absf(pos.y-32.0)<180.0:
		record_line(WEST)
	if Vector2(pos.x-15556.0,pos.z-4123.0).length()<700.0 and absf(pos.y-32.0)<220.0:
		record_line(STARRY)
