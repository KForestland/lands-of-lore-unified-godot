extends SceneTree
## Museum / Dark Halls / Savage Jungle original world-item rows (area_world_items_state.gd): identities pinned to the
## definitions pack, catalog binding (label, icon, slot from the class byte, defense rows for the equippable ones), scope
## admission (museum row in the Museum scope, the others Jungle), unique enumeration, history validation in both save
## validators and the old-save default (absent key = every row present). Headless, data only.
const S = preload("res://scripts/lol2/area_world_items_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
const D = preload("res://scripts/lol2/item_definitions.gd")
const Q = preload("res://scripts/lol2/act_one_quest_state.gd")
const N = preload("res://scripts/lol2/act_one_item_names.gd")
const MuseumSave = preload("res://scripts/lol2/museum_save.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(D.ready(), "definitions staged")
	check(S.areas() == ["museum", "darkhalls", "darkerjungle"] and S.all_ids().size() == 17, "three areas, 17 rows (%d)" % S.all_ids().size())
	var seen := {}
	for area in S.areas():
		var data: Dictionary = S.AREAS[area]
		check(data.rows.size() == data.definitions.size() and data.rows.size() == data.identities.size() and data.rows.size() == data.positions.size() and data.rows.size() == data.regions.size() and data.rows.size() == data.names.size(), "%s: parallel columns" % area)
		for i in data.rows.size():
			var id: String = S.id_of(area, data.rows[i])
			check(not seen.has(id), "unique id %s" % id); seen[id] = true
			check(D.by_identity(data.identities[i]) == data.definitions[i] and D.name(data.definitions[i]).strip_edges() == data.names[i], "%s row %d: identity %d -> definition %d %s" % [area, data.rows[i], data.identities[i], data.definitions[i], data.names[i]])
			check(S.valid(id) and S.area_of(id) == area and S.row_of(id) == data.rows[i] and S.definition(id) == data.definitions[i] and S.source_name(id) == data.names[i], "%s resolves through the state" % id)
			check(C.definition(id) == data.definitions[i] and C.definition_name(id) == data.names[i] and N.source_name(id) == data.names[i], "%s resolves through the catalog and the Act 1 names" % id)
			check(C.label(id) == D.label(data.definitions[i]) and FileAccess.file_exists(C.icon(id)) and FileAccess.file_exists(C.inventory_icon(id)), "%s label + icons" % id)
			check(C.slot(id) == D.slot(data.definitions[i]) and C.use_kind(id) == "", "%s slot from the class byte (%s), no use" % [id, C.slot(id)])
			check(C.ids("jungle").count(id) == 1, "%s enumerated once" % id)
			var origin: String = str(data.origin)
			check(C.admitted(id, origin) and C.admitted(id, "jungle") and not C.admitted(id, "cave") and (origin == "museum") == C.admitted(id, "museum"), "%s admitted in %s and Jungle only" % [id, origin])
	# The equippable rows carry the pinned source defense (prepare_act_one_item_defenses.py).
	check(C.slot("darkhalls:item28:Orc_shield") == "offhand" and C.defense("darkhalls:item28:Orc_shield") == 4, "Orc shield: offhand, defense 4 (%s %d)" % [C.slot("darkhalls:item28:Orc_shield"), C.defense("darkhalls:item28:Orc_shield")])
	check(C.slot("darkhalls:item5:Gaunt_strike") == "weapon" and C.defense("darkhalls:item5:Gaunt_strike") == 10, "Gaunt strike: weapon, defense byte 10 (%s %d)" % [C.slot("darkhalls:item5:Gaunt_strike"), C.defense("darkhalls:item5:Gaunt_strike")])
	check(C.slot("museum:item0:Cocos_Cap") == "" and C.slot("darkerjungle:item10:Lamplt_eggs") == "" and C.slot("darkerjungle:item28:Manafoil") == "", "cap, eggs and recipe carry no slot")
	check(C.validate_carried(S.all_ids(), "jungle").is_empty() and not C.validate_carried(S.ids("darkhalls"), "museum").is_empty() and C.validate_carried(S.ids("museum"), "museum").is_empty(), "scope validation")
	# Histories: absent (older saves) valid; shapes checked per area in both validators.
	var quests: Dictionary = Q.initial()
	check(not quests.has(S.key("darkhalls")) and not quests.has(S.key("darkerjungle")) and Q.validate(quests).is_empty(), "quest state without the keys is valid")
	check(S.rows_of(null, "darkhalls") == [] and S.rows_of({"version": 1, "collected": [28.0, 4.0]}, "darkhalls") == [28, 4], "rows_of")
	for good in [{"version": 1, "collected": []}, {"version": 1, "collected": [4, 28]}, {"version": 1, "collected": [5.0]}]:
		quests[S.key("darkhalls")] = good
		check(Q.validate(quests).is_empty(), "dark halls history %s valid" % [good])
	for bad in [[], {"version": 2, "collected": []}, {"version": 1, "collected": [10]}, {"version": 1, "collected": [4, 4]}, {"version": 1, "collected": [4.5]}, {"version": 1, "collected": ["4"]}, {"version": 1, "collected": [], "x": 1}]:
		quests[S.key("darkhalls")] = bad
		check(not Q.validate(quests).is_empty(), "dark halls history %s rejected" % [bad])
	quests.erase(S.key("darkhalls"))
	quests[S.key("darkerjungle")] = {"version": 1, "collected": [10, 21, 28]}
	check(Q.validate(quests).is_empty(), "savage jungle history valid")
	quests[S.key("darkerjungle")] = {"version": 1, "collected": [25]}
	check(not Q.validate(quests).is_empty(), "savage jungle row 25 (unreachable, not hosted) rejected")
	check(S.validate({"version": 1, "collected": [0]}, "museum").is_empty() and not S.validate({"version": 1, "collected": [1]}, "museum").is_empty(), "museum history rows")
	print("Area world items state: %d failures" % failures)
	if failures == 0: print("PASS area world items state: 17 rows (Museum 1, Dark Halls 3, Savage Jungle 13) pinned to the definitions, catalog/scope bindings, defense rows, history validation, old-save default")
	quit(0 if failures == 0 else 1)
