extends RefCounted
## Item handler dispatch skeleton (ITEM_CENSUS_AND_PLAN_20261025.md step 4; engine contract A, the 0x95840 dispatcher and the
## 107-handler table at 0xC860). Every definition's handler index routes here: a hosted handler names the port module that
## already implements it (unchanged, still called by its family module), handler 0 is the original's "no handler" (47 ordinary
## weapons / armour / keys / flutes never reach the table), and every other handler is an explicit "not hosted" refusal with a
## hint. Nothing here invents behaviour; new handlers are added only from a traced contract.
const DEFINITIONS := "res://assets/lol2/generated/items/definitions.json"
const Catalog := preload("res://scripts/lol2/item_catalog.gd")
## Family 3 (on-hit): the strike sites (hive_warriors, jungle_dino_population, scripted_creature_population) record the equipped
## item's mode-5 route here before the unchanged net_hit / prism_hit calls; the modules' own `equipped()` checks stay the gate.
static var last_hit_route: Dictionary = {}

static func record_hit(item_id: Variant) -> Dictionary:
	last_hit_route = route(Catalog.definition(item_id), 5)
	last_hit_route["item"] = str(item_id)
	return last_hit_route
## Handler index -> the port module hosting it (contract A section 3, rows marked PORT; the family modules own the calls).
const HOSTED := {
	70: {"module":"res://scripts/lol2/dead_bracers_item.gd","modes":[14,16,18],"note":"Dead bracers: request18 sets indexed local,14 clears,16 returns2; modern inventory-derived dead-speech admission, no native bank writes"},
	2: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Fire crystals: charge spent per use, burns out to Fire brnt"},
	4: {"module": "res://scripts/lol2/player_item_effects.gd", "modes": [1, 8], "note": "Champion stone: stat +20 with its timer (mode 8 maintenance)"},
	6: {"module": "res://scripts/lol2/hive_ancient_stone.gd", "modes": [1, 9], "note": "Ancients stone / Force pod: the shared player counter byte (use refused until traced)"},
	7: {"module": "res://scripts/lol2/prism_blind.gd", "modes": [5], "note": "Prism on-strike blind"},
	8: {"module": "res://scripts/lol2/museum_lightning_crystal.gd", "modes": [1], "note": "Lightning crystal (museum, partly)"},
	9: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Aloe / Cave aloe: pending heal, consume"},
	10: {"module": "res://scripts/lol2/weapon_poison.gd", "modes": [12], "note": "Poison paint: one coat on the weapon, refused at nine"},
	16: {"module": "res://scripts/lol2/hive_elevator.gd", "modes": [1], "note": "Iron flute: play_flute"},
	18: {"module": "res://scripts/lol2/hive_reaver_amber.gd", "modes": [10, 11], "note": "Reaver of GO: equip flag only"},
	20: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Vels fruit: consume, clears player status +0x1B5"},
	27: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Dampen charm: consume, player byte 0x23ABD bit 0"},
	39: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Silverleaf: Brady printed41 +5 Magic Points; modern cap/refusal, native handler timing unclaimed"},
	43: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Mana foil: +50 mana"},
	98: {"module": "res://scripts/lol2/player_item_controller.gd", "modes": [1], "note": "Ironwood sap / Amaranth: consume"},
	102: {"module": "res://scripts/lol2/player_dragon_blood.gd", "modes": [16], "note": "Dragon blood: the hand item placed on a world object (museum dragon heart)"},
	104: {"module": "res://scripts/lol2/net_exile_hold.gd", "modes": [5], "note": "Net of Exile on-hit hold"},
}
## The dispatcher mode each of the port's use kinds corresponds to (contract A section 2): a coat is dropped on the weapon circle
## (12), dragon blood is the hand item applied to a world object (16), everything else is "use on Luther" (1).
const USE_KIND_MODES := {"poison_paint": 12, "dragon_blood": 16}

static func mode_for_use_kind(kind: String) -> int:
	return int(USE_KIND_MODES.get(kind, 1))

## Grok's 42 handler groups (backlog 2026-10-31E item 4, handlers_pass2: the handlers of the 0xC860 table joined by their
## narrowest shared direct callee; `grade` is Grok's grade of the shared CALLEE fact, copied). `likely` is this lane's LIKELY
## reading of what the group does, from the join of the member items' names and classes (definitions.json) with the Prima
## "Unauthorized Game Secrets" hintbook item chapter (AI_COMMS/REFERENCES.md) and the already hosted members; it is a
## label for hints and handoffs, never a contract: nothing is hosted from it. Request bytes are the dispatcher modes of
## contract A (1 use, 5 on-strike, 6/0x0D swing, 0x0A/0x0B slot in/out, 0x0F, 0x10 query). "class 0xNNNN" = the encoded
## dword the callee stores at object +0x28 (one per effect kind), unnamed natively.
const GROUPS := [
	{"group": 1, "handlers": [3, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82], "callee": 0xCF3C0, "grade": "UNKNOWN",
		"likely": "Speaking Stones SS1-SS12: pick the stone's recording from the 0xCA0E.. table into 0x96914 and start the playback (requests 1 and 0x0F)"},
	{"group": 2, "handlers": [12, 27, 28, 29, 30, 31, 32, 33, 34], "callee": 0x8619C, "grade": "UNKNOWN",
		"likely": "spell scrolls (Heal/Spark/Prism/MoD/Summon) and the curse-control items (Dampen charm, Control token, Lizard seal, Bestial disk): learn or cast a spell group through 0x8619C; the curse items set bits 0/1/2/3 of player byte 0x23ABD (Dampen = bit 0 is hosted)"},
	{"group": 3, "handlers": [21, 24, 25, 44, 49, 65, 88, 97, 101], "callee": 0x91868, "grade": "UNKNOWN",
		"likely": "worn rings and amulets (Kelen's, Beozar, G Beozar, cobra, cat, Drakfire, J'kar idol, Colim's amulet, Ruby of truth): 0x91868 checks the two ring slots [+0x2E4]/[+0x2E8] through 0x626B4 and the handler sets or clears one worn-effect bit"},
	{"group": 4, "handlers": [50, 54, 55, 56, 58, 71, 100], "callee": 0xF7030, "grade": "UNKNOWN",
		"likely": "missile weapons (Shift, Light crossbow, Defender, Myriad, Darkbow, Snare, Throwing dagger): 0xF7030 builds the projectile object (class 0x980C) and jumps per weapon kind"},
	{"group": 5, "handlers": [5, 85], "callee": 0xF7B94, "grade": "LIKELY",
		"likely": "throwable hand weapons with a ghost twin (Axe of the Long Arm / Axe Ghost, War blade / Hand ghost): 0xF7B94 builds the in-flight object (class 0x9710); the Long Arm returns after a throw (hintbook)"},
	{"group": 6, "handlers": [2, 26], "callee": 0x101F74, "grade": "LIKELY",
		"likely": "fireball projectile (class 0x8734): Fire crystal on use (hosted, charge spent) and the Valkyrie crossbow on swing (6/0x0D) after the 0x136594 range check"},
	{"group": 7, "handlers": [60, 83], "callee": 0x1028A4, "grade": "LIKELY",
		"likely": "area spell effect (class 0x8440, shared with the acid sac, group 42): Storm crystal snowstorm (hintbook) and Thohan's enchanted weapon"},
	{"group": 8, "handlers": [63, 93], "callee": 0x10BB28, "grade": "LIKELY",
		"likely": "lightning effect object (class 0x6184): the Stroke dagger's bolt (hintbook) and the yellow glass globe"},
	{"group": 9, "handlers": [39, 43, 90], "callee": 0xD6A88, "grade": "LIKELY",
		"likely": "consumable or offered item that writes player dword +0x145 (Mana foil's mana restore is hosted as +50; Silverleaf and the Ivory chip share the write); the offset stays unnamed"},
	{"group": 10, "handlers": [38, 40], "callee": 0xD6B20, "grade": "UNKNOWN",
		"likely": "raw recipe reagents eaten (Gorgonite nodule, Rainbow sulfite): the shared consume path 0xD6B20"},
	{"group": 11, "handlers": [67, 95], "callee": 0xDAEA0, "grade": "LIKELY",
		"likely": "eaten reagents with a status effect (Mandrake root, Larkhon vapour): bit 1 of status byte 0x23AB6, then the consume path 0xD6B20"},
	{"group": 12, "handlers": [4, 87], "callee": 0x8A364, "grade": "UNKNOWN",
		"likely": "temporary stat change through the 0x8A364 jump table: Champion's stone might +20 with its timer (hosted), Pod of change (arm unknown)"},
	{"group": 13, "handlers": [10, 11, 42, 48], "callee": 0xD03B8, "grade": "UNKNOWN",
		"likely": "weapon poison: 0xD03B8 is the weapon-circle apply path; coat counters +0x42A (Poison paint, hosted: refused at nine) and +0x42B (Death sac, hintbook: poisons weapons); Venom sac and the Axe Traitor share it"},
	{"group": 14, "handlers": [9, 41, 94], "callee": 0x7C528, "grade": "UNKNOWN",
		"likely": "eaten herbs: Aloe / Cave aloe (hosted pending heal) and Black lichen write 0x2271A (the pending heal), Arrant practice only consumes through 0x7C528"},
	{"group": 15, "handlers": [16, 69, 96, 98, 102], "callee": 0xE3924, "grade": "UNKNOWN",
		"likely": "uses that set a world flag then call the item-used notifier 0xE3924: Iron flute writes local [0x26E58 + 0x2333E] = 1 (hosted: Hive elevator), Dragon blood arms 0x2260B (hosted), Lamplight eggs = see in the dark (hintbook), Ironwood sap / Amaranth consume, recipes R-* read"},
	{"group": 16, "handlers": [13, 14, 17, 18, 19, 23, 47, 51, 52, 53, 61, 70, 99, 103, 107], "callee": 0, "grade": "PROVEN",
		"likely": "worn-equipment passive flags, no callee: slot in (0x0A) sets and slot out (0x0B) clears one bit of the worn-effect bytes 0x2270E..0x22711 (Ring of regen, Bastion, Deathstroke shield, Reaver of GO, Gargoyle / Stone / DF bracers, Br valor, Dr armour, Dr gauntlets, Reflective plate, Gauntlets of Might, Coco's cap); request 0x10 answers 2 or 3; Br dead writes local [0x26E58 + 0x2333F] (cemetery quests); Gaunt strike answers 0x10 only"},
	{"group": 17, "handlers": [1], "callee": 0x102EA4, "grade": "UNKNOWN", "likely": "Great Sword Firestorm: on-strike (5) fire effect object"},
	{"group": 18, "handlers": [6], "callee": 0x7C5DC, "grade": "UNKNOWN", "likely": "Ancients' stone / Force pod: one level-5 ancient-magic charge (hintbook; the port's shared counter byte), after 0xE3924"},
	{"group": 19, "handlers": [7], "callee": 0x107498, "grade": "UNKNOWN", "likely": "Prism on-strike (5): when the striker is the player object 0x22574 build the blind effect (hosted as prism_blind)"},
	{"group": 20, "handlers": [8], "callee": 0x10A4BC, "grade": "UNKNOWN", "likely": "Lightning crystal: bolt object + bit 0 of status byte 0x22712 (hosted in the Museum)"},
	{"group": 21, "handlers": [15], "callee": 0xF8324, "grade": "UNKNOWN", "likely": "Guardian orb: summon the phantasmal defending sword (hintbook)"},
	{"group": 22, "handlers": [20], "callee": 0x7C7DC, "grade": "UNKNOWN", "likely": "Vel's fruit: cure poison (hosted: clears +0x1B5); 0x7C7DC is a status-cure dispatcher the Heal scroll (31) also reaches"},
	{"group": 23, "handlers": [22], "callee": 0xF8EA8, "grade": "UNKNOWN", "likely": "Ice seed: ground spike effect object (class 0xA3DC; hintbook: raises icy spikes, freezes fountains)"},
	{"group": 24, "handlers": [35], "callee": 0x10275C, "grade": "UNKNOWN", "likely": "N valk crossbow: fireball missile (class 0x853C over the group-6 fireball) after the 0x800000 range check"},
	{"group": 25, "handlers": [36], "callee": 0x1050AC, "grade": "UNKNOWN", "likely": "Plasma staff / Plas ghost: plasma bolt on swing (6/0x0D, class 0x795C) when the weapon byte +0x52 is 3"},
	{"group": 26, "handlers": [37], "callee": 0xD69E4, "grade": "LIKELY", "likely": "Power orb: reads player dword +0x149 (a trade item: sword purchase or repair per the hintbook); the effect of the use stays open"},
	{"group": 27, "handlers": [45], "callee": 0xF9920, "grade": "UNKNOWN", "likely": "Stone cube: three stalagmite growth objects (class 0xA2E0) at random offsets (hintbook: throw it to make stalagmites grow)"},
	{"group": 28, "handlers": [46], "callee": 0xDA7BC, "grade": "UNKNOWN", "likely": "War cluster: damage-resistance timer word +0x1AE = 0x3C (hintbook: raises resistance to damage)"},
	{"group": 29, "handlers": [57], "callee": 0x1000C4, "grade": "UNKNOWN", "likely": "Darkstorm sword: strike effect object (class 0x8C20) + bit 6 of status byte 0x22712"},
	{"group": 30, "handlers": [59], "callee": 0x101214, "grade": "UNKNOWN", "likely": "Draconic dagger: randomised (0xA1864) strike effect through 0x100EB8"},
	{"group": 31, "handlers": [62], "callee": 0x102874, "grade": "LIKELY", "likely": "Long bow Shard: shattering area projectile (fireball base, class 0x8638, kind byte +0x5A = 0x51; hintbook: shatters on impact)"},
	{"group": 32, "handlers": [64], "callee": 0x81820, "grade": "UNKNOWN", "likely": "Pyrapod: swaps the spark spell for fire (hintbook) through the spell-table dispatcher 0x81820 (the scroll group's push-5 callee)"},
	{"group": 33, "handlers": [66], "callee": 0xDB4B0, "grade": "LIKELY", "likely": "Coward's buckler: worn sets bit 3 of player +0x19C (invisibility per the hintbook), slot out clears it (0xDB4EC)"},
	{"group": 34, "handlers": [68], "callee": 0xFC0D8, "grade": "UNKNOWN", "likely": "Dagger of Light / Dag ghost: thrown ghost projectile on swing (6/0x0D, class 0x9610)"},
	{"group": 35, "handlers": [84], "callee": 0xFF964, "grade": "UNKNOWN", "likely": "Great Axe Blizzard: cold on-strike effect (5, class 0x8D1C; hintbook: cold damage, freezes fountains)"},
	{"group": 36, "handlers": [86], "callee": 0xDB818, "grade": "PROVEN", "likely": "Brook flower: timed status (bit 4 of 0x23AB6, counter 0x22798, duration word +0x1F8 += 0xE10 ticks) when +0x1F6 is 0; which status it is stays open"},
	{"group": 37, "handlers": [89], "callee": 0x145B00, "grade": "UNKNOWN", "likely": "Mind cluster: reveal the level's automap (hintbook)"},
	{"group": 38, "handlers": [91], "callee": 0x104C4C, "grade": "UNKNOWN", "likely": "White glass globe: two effect objects (class 0x7B54, +0x58 = 3): the charged-globe door / charger use"},
	{"group": 39, "handlers": [92], "callee": 0x107C44, "grade": "UNKNOWN", "likely": "Blue glass globe: effect object (class 0x717C) + bit 1 of status byte 0x22712"},
	{"group": 40, "handlers": [104], "callee": 0x10E2F8, "grade": "UNKNOWN", "likely": "Net of Exile: on-strike net object (class 0x9B00) that sends the creature away (hosted as net_exile_hold)"},
	{"group": 41, "handlers": [105], "callee": 0xABC08, "grade": "UNKNOWN", "likely": "Stone of the gorgon: the target's petrify word +0x84 = 0x258 ticks (hintbook: turns a monster to stone for a while)"},
	{"group": 42, "handlers": [106], "callee": 0x102D00, "grade": "UNKNOWN", "likely": "Acid sac thrown at a foe: area effect object (class 0x8440, shared with group 7)"},
]

## Grok's group row of a handler index, or {} (handler 0 and indexes outside the table have none).
static func group_of(handler: int) -> Dictionary:
	for row in GROUPS:
		if handler in row.handlers: return row
	return {}
static var _definitions: Array = []
static var _loaded := false

static func definitions() -> Array:
	if _loaded: return _definitions
	_loaded = true
	if FileAccess.file_exists(DEFINITIONS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS))
		if parsed is Dictionary and parsed.get("definitions") is Array: _definitions = parsed.definitions
	return _definitions

static func definition(index: int) -> Dictionary:
	var rows := definitions()
	if index < 0 or index >= rows.size(): return {}
	return rows[index]

## The route of one definition for one dispatcher mode (contract A: 1 use on Luther, 5 on-strike, 6/13 swing, 8 timer, 9, 10/11
## slot in/out, 12 weapon circle, 14/17 hand slot, 15, 16 applied to a world object, 18 periodic tick). Returns
## {definition, name, handler, handler_va, hosted, module, modes, note, refusal, hint, equip_allowed}; `hosted` is true for
## handler 0 (nothing to run) and for the PORT handlers; a mode a hosted handler does not list is refused with the contract's
## modes. `equip_allowed` (modes 10 / 11, slot in / out): true for every definition, because equipping runs no handler the port
## lacks: the slot hook of a passive handler (19 Gargoyle bracers, 23 Stone bracers, ...) is the unhosted part and the
## definition's defense byte (+0x41, item_defense_data.gd) is what the port applies; `hosted` still says whether the hook runs.
static func route(index: int, mode: int = 1) -> Dictionary:
	var row := definition(index)
	if row.is_empty():
		return {"definition": index, "name": "", "handler": -1, "handler_va": 0, "hosted": false, "module": "", "modes": [], "note": "",
			"refusal": "definition %d is not in definitions.json (170 rows)" % index, "hint": "stage tools/prepare_item_definitions.py"}
	var handler := int(row.get("handler", 0))
	var out := {"definition": index, "name": str(row.get("name", "")), "handler": handler, "handler_va": int(row.get("handler_va", 0)),
		"hosted": false, "module": "", "modes": [], "note": "", "refusal": "", "hint": "", "equip_allowed": mode == 10 or mode == 11,
		"group": int(group_of(handler).get("group", 0)), "likely": str(group_of(handler).get("likely", ""))}
	if handler == 0:
		out.hosted = true
		out.note = "no handler: the dispatcher 0x95840 is never reached for this definition (ordinary item)"
		return out
	if HOSTED.has(handler):
		var entry: Dictionary = HOSTED[handler]
		out.module = str(entry.module)
		out.modes = entry.modes
		out.note = str(entry.note)
		if mode in entry.modes or mode == 0:
			out.hosted = true
		else:
			out.refusal = "handler %d (%s) is hosted for modes %s, not mode %d" % [handler, out.name, str(entry.modes), mode]
			out.hint = "contract A: a mode the handler's head compares do not list returns 0 natively"
		return out
	out.refusal = "handler %d (%s, 0x%X) is not hosted" % [handler, out.name, out.handler_va]
	out.hint = "no handler class closed natively (Grok backlog 6 item 4 / E item 4); host it from a traced contract, never a guess"
	if not out.likely.is_empty(): out.hint += "; LIKELY (group %d, not a contract): %s" % [out.group, out.likely]
	if out.equip_allowed:
		out.hint = "slot hook (mode %d) not hosted: the port applies the definition's defense byte only" % mode
	return out

## Every distinct handler index of the table with its route state (for the census test and the handoff).
static func routing_table() -> Dictionary:
	var table := {}
	for row in definitions():
		var handler := int(row.get("handler", 0))
		if not table.has(handler):
			table[handler] = {"hosted": handler == 0 or HOSTED.has(handler), "definitions": [], "module": str(HOSTED.get(handler, {}).get("module", ""))}
		table[handler].definitions.append(int(row.index))
	return table
