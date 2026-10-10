extends RefCounted
## Atomic source wax exchange plus first-copy experience. LCG is a modern RNG adapter.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Items = preload("res://scripts/lol2/hive_rune_items.gd")
const Fighting = preload("res://scripts/lol2/hive_reward_application.gd")
const Magic = preload("res://scripts/lol2/hive_magic_reward.gd")
const Monastery = preload("res://scripts/lol2/monastery_quest_state.gd")
const WorldItems = preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const WAX := "hive:item0:Wax"
## Source RUNECL hotspot0 admits the held item by its GLOBAL definition name "71-Wax" (identity 2925189839). Hive wax and
## the Jungle wax rows carry that same definition, so any carried wax of it is accepted (same catalog semantics as
## item_catalog.gd's source-name uses).
const WAX_SOURCE_NAME := "71-Wax"
static func is_wax(id: Variant) -> bool:
	return id is String and (id == WAX or (WorldItems.valid(id) and WorldItems.source_name(id) == WAX_SOURCE_NAME) or preload("res://scripts/lol2/jungle_beehive_wax.gd").valid(id))
static func draws(seed: int, maxima: Array) -> Dictionary:
	var values: Array = []
	var seeds: Array = [seed]
	for maximum in maxima:
		seed = (1103515245*seed+12345)&0x7fffffff
		values.append(seed%(int(maximum)+1))
		seeds.append(seed)
	return {"values":values,"seeds":seeds}
## held: the exact wax on the cursor (consumed). Empty: the first carried wax, for callers without a held item.
static func copy_wax(quests: Dictionary, inventory: Dictionary, held: String = "") -> Dictionary:
	var error := Save.Quests.validate(quests)
	if error.is_empty(): error = Save.validate_inventory(inventory)
	if not error.is_empty(): return {"error":error}
	var entry: Dictionary = quests.get("hive_rune_entry",{})
	if entry.get("room","") != "RUNECL" or not entry.get("lights",false): return {"error":"The inscription is not available."}
	var wax := held
	if wax.is_empty():
		for item in inventory.collected:
			if is_wax(item): wax = item; break
	if not is_wax(wax) or wax not in inventory.collected: return {"error":"Wax is required."}
	var id := Items.next_id(inventory.collected)
	if id.is_empty(): return {"error":"No room for another rune copy."}
	var next: Dictionary = quests.duplicate(true)
	var carried: Dictionary = inventory.duplicate(true)
	if not next.has("monastery"): next.monastery = Monastery.initial()
	var first: bool = next.monastery.globals.GV_HAS_RUNES == 0
	if first:
		var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
		var maxima: Array = []
		for level in range(31): maxima.append_array([95,63,63])
		var seed := int(entry.get("reward_seed",324508639))
		var random := draws(seed,maxima)
		var fight := Fighting.award_checkpoint(next.get("player_reward_state",{"version":1,"player":initial.fighting}),200,random.values)
		if fight.has("error"): return fight
		seed = int(random.seeds[fight.draws_used])
		maxima.clear()
		for level in range(31): maxima.append(159)
		random = draws(seed,maxima)
		var magic := Magic.award_checkpoint(next.get("player_magic_reward_state",{"version":1,"player":initial.magic}),200,random.values)
		if magic.has("error"): return magic
		next.player_reward_state = fight.checkpoint
		next.player_magic_reward_state = magic.checkpoint
		next.hive_rune_entry.reward_seed = int(random.seeds[magic.draws_used])
	carried.collected.erase(wax)
	carried.collected.append(id)
	next.monastery.globals.GV_HAS_RUNES = 1
	return {"quests":next,"inventory":carried,"item":id,"first_copy":first,"consumed":wax}
