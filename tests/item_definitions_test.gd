extends SceneTree
## Items chunk 1: all 170 original definitions (tools/prepare_item_definitions.py) behind one catalog.
## Checks the staged data, that every Act 1 carried identity resolves to its original definition, that the class-byte
## slot adapter agrees with every slot the port already assigns, that generic per-definition ids are admitted only in
## the later "world" scope (Act 1 saves unchanged), and the refusal hint for items without a traced use. Headless.
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Defenses = preload("res://scripts/lol2/item_defense_data.gd")
## Act 1 identities before chunk 1 (ids("jungle") size at r12h 902b273) + 17 original world-item rows hosted 2026-10-31
## (area_world_items_state.gd: Museum 1, Dark Halls 3, Savage Jungle 13).
const ACT1_IDS := 307 # 197 + four Act 2 story equipment ids in the jungle scope (L12 Blue Bow def35, L12 Obsidian Chain Mail def54, L13 Dark Sword def21, L13 Enchanted Thohan def71; astra) + Belial's Horn def22 as a held hand item (lead 2026-11-07, finale save) + the L8 shaman Dracoid Sigil (definition102, l8_journey_state.gd, astra 9c2e0e3) + six L8 herbalist first-visit items (two sap, two amber, two aloe; l8_herbalist.gd, astra 650578e) + the two Thieves' Den grants + the six chief's-hut stones (docs/thieves-den.md, docs/jungle-chut-room.md) + 61 Jungle world rows (docs/jungle-missing-pickups.md) + five Museum scrolls and two Museum Aloes (docs/museum-scrolls.md) + five Hive original rows 5-9 (hive_world_items_state.gd)
## The only Act 1 identity without a source definition (an unidentified cavern sample).
const NO_DEFINITION := ["draracle/prop/1108/sample"]
## Port slot differs from the class byte: Net of Exile (class 0x40) is used as a held weapon by its on-hit handler104
## module (hive_net_exile.gd); kept as before.
const SLOT_EXCEPTIONS := ["hive:prop214:Net_of_Exile"]
## L8 herbalist first-visit items (astra 650578e) are Act 1-scope ids that resolve through generic_index by design.
const Herbalist = preload("res://scripts/lol2/l8_herbalist.gd")

func _init() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	print("FAIL item_definitions: ", message)
	quit(1)

func run() -> void:
	if not Definitions.ready(): return fail("Item definitions not staged (run tools/prepare_item_definitions.py)")
	var names := {}
	var identities := {}
	var carriable := 0
	for index in Definitions.COUNT:
		var row := Definitions.row(index)
		if int(row.index) != index: return fail("Row order %d" % index)
		names[str(row.name)] = true
		identities[int(row.identity)] = true
		if Definitions.carriable(index):
			carriable += 1
			if not FileAccess.file_exists(Definitions.icon(index)): return fail("Missing icon for %d %s" % [index, row.name])
		elif index < 152 or index > 156: return fail("Unexpected ghost row %d" % index)
	if names.size() != 170 or identities.size() != 170 or carriable != 165: return fail("Definition counts %d/%d/%d" % [names.size(), identities.size(), carriable])
	if Definitions.name(4) != "5-Short swd" or Definitions.slot(4) != "weapon" or Definitions.defense(19) != 50: return fail("Pinned rows changed")

	var act1: Array = Catalog.ids("jungle")
	if act1.size() != ACT1_IDS: return fail("Act 1 identities changed: %d" % act1.size())
	var resolved := 0
	var slot_checks := 0
	for id in act1:
		var index := Catalog.definition(id)
		if index < 0:
			if id in NO_DEFINITION: continue
			return fail("No definition for " + id + " (" + Catalog.definition_name(id) + ")")
		resolved += 1
		if Catalog.generic_index(id) >= 0 and not Herbalist.valid(id) and not Catalog.FIXED.has(id): return fail("Act 1 id parsed as generic: " + id)
		var port_slot := Catalog.slot(id)
		if port_slot != "" and id not in SLOT_EXCEPTIONS:
			slot_checks += 1
			if Definitions.slot(index) != port_slot: return fail("Class slot %s != port slot %s for %s" % [Definitions.slot(index), port_slot, id])
		if Defenses.ITEMS.has(id) and int(Defenses.ITEMS[id].defense) != Definitions.defense(index): return fail("Defense differs for " + id)
	# 37 slot checks: 34 + the Jungle row15 Guard shield offhand (definition37) + the Dark Halls rows 5 Gaunt strike (weapon,
	# definition12) and 28 Orc shield (offhand, definition38) hosted 2026-10-31 (area_world_items_state.gd).
	# 42 since 2026-11-07: + Belial's Horn (definition 22, original class slot weapon), held to start the finale.
	if resolved != ACT1_IDS - NO_DEFINITION.size() or slot_checks != 42: return fail("Resolved %d, slot checks %d" % [resolved, slot_checks])
	for chunk_start in range(0, act1.size(), Catalog.MAX_CARRIED):
		if Catalog.validate_carried(act1.slice(chunk_start, chunk_start + Catalog.MAX_CARRIED), "jungle") != "": return fail("Act 1 carried set rejected")

	var world: Array = Catalog.ids("world")
	var generic := world.filter(func(id): return Catalog.generic_index(id) >= 0 and not Herbalist.valid(id) and not Catalog.FIXED.has(id))
	if generic.size() != 165 or world.size() != ACT1_IDS + 165: return fail("World ids %d/%d" % [generic.size(), world.size()])
	for id in generic:
		var index := Catalog.generic_index(id)
		if Catalog.label(id) != Definitions.label(index) or Catalog.icon(id) != Definitions.icon(index) or Catalog.slot(id) != Definitions.slot(index): return fail("Generic entry differs: " + id)
		if Catalog.definition(id) != index or Catalog.defense(id) != Definitions.defense(index): return fail("Generic definition differs: " + id)
		if not Catalog.admitted(id, "world") or Catalog.admitted(id, "jungle"): return fail("Generic scope wrong: " + id)
		# Silverleaf (definition117) is the one generic definition with a hosted use: Brady printed41 +5 Magic Points (astra ITEM-117 5ba83e5).
		# Amaranth serum (definition119): Brady printed42, consumed by handler98 (astra ITEM-119).
		if Catalog.use_kind(id) != "" and index not in [117, 119]: return fail("Generic id has an untraced use: " + id)
		if index == 117 and Catalog.use_kind(id) != "silverleaf": return fail("Silverleaf use missing")
	if Catalog.validate_carried([Catalog.generic_id(43)], "jungle") == "": return fail("Act 1 save admitted a later-act item")
	if Catalog.validate_carried([Catalog.generic_id(43)], "world") != "": return fail("World scope rejected a definition")
	for bad in ["item:def152", "item:def12", "item:def999", "item:defabc", Catalog.generic_id(170)]:
		if Catalog.known(bad): return fail("Malformed or ghost id accepted: " + bad)
	if Catalog.slot(Catalog.generic_id(43)) != "armor" or Catalog.defense(Catalog.generic_id(43)) != 30: return fail("Platemail")
	if Catalog.slot(Catalog.generic_id(48)) != "" or Catalog.use_hint(Catalog.generic_id(48)) != "No inventory use is known for this item yet.": return fail("Ring hint")
	if Catalog.use_hint("jungle:item54:Vels_fruit") != "" or Catalog.use_hint("museum:item25:Dragon_Gem") != "No inventory use is known for this item yet.": return fail("Act 1 hints")
	if Catalog.use_hint("draracle/prop/1108/sample") != "This item has not been identified.": return fail("Unknown sample hint")
	print("PASS item_definitions: 170 definitions, 165 icons, %d Act 1 ids resolved, %d slot checks, 165 generic world ids" % [resolved, slot_checks])
	quit(0)
