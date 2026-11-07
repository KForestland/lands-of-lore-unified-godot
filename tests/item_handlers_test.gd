extends SceneTree
## Item handler dispatch skeleton (plan step 4 / step 6 game-wide checks): every one of the 170 definitions routes, every hosted
## handler names a module that exists, every other handler refuses with a hint, handler 0 is the original's no-handler, and
## every fixed catalog identity resolves to a definition that routes.
const Handlers := preload("res://scripts/lol2/item_handlers.gd")
const Catalog := preload("res://scripts/lol2/item_catalog.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = Handlers.definitions()
	check(rows.size() == 170, "definitions.json has 170 rows (%d)" % rows.size())
	var table: Dictionary = Handlers.routing_table()
	check(table.size() == 108 and table.has(0) and table[0].definitions.size() == 47, "108 handler indexes incl. 0 (47 ordinary definitions) (%d)" % table.size())
	var hosted := 0; var refused := 0; var bad := 0
	for row in rows:
		var r: Dictionary = Handlers.route(int(row.index), 1)
		if not r.has("hosted") or (not r.hosted and str(r.refusal).is_empty()): bad += 1
		if r.hosted: hosted += 1
		else:
			refused += 1
			if str(r.hint).is_empty(): bad += 1
	check(bad == 0, "every definition routes: hosted or refused with a hint (bad %d)" % bad)
	print("definitions: hosted (incl. handler 0) %d, refused %d" % [hosted, refused])
	for handler in Handlers.HOSTED:
		var module: String = str(Handlers.HOSTED[handler].module)
		check(FileAccess.file_exists(module), "hosted handler %d names an existing module (%s)" % [handler, module])
		check(table.has(handler), "hosted handler %d is a table index" % handler)
	# Names carry the original numbering ("8-Prism"), not the table index: look the rows up by name.
	var by_name := {}
	for row in rows: by_name[str(row.name)] = int(row.index)
	var prism: Dictionary = Handlers.route(int(by_name.get("8-Prism", -1)), 5)
	check(prism.handler == 7 and prism.hosted and prism.module.ends_with("prism_blind.gd"), "Prism (%d) handler 7 routes to prism_blind for mode 5 (%s)" % [int(by_name.get("8-Prism", -1)), prism])
	var prism_use: Dictionary = Handlers.route(int(by_name.get("8-Prism", -1)), 1)
	check(not prism_use.hosted and prism_use.refusal.contains("mode 1"), "Prism handler 7 refuses mode 1 with the contract's modes")
	var net: Dictionary = Handlers.route(int(by_name.get("26-Net of Exile", -1)), 5)
	check(net.handler == 104 and net.hosted, "Net of Exile (%d) handler 104 routes for mode 5" % int(by_name.get("26-Net of Exile", -1)))
	var sword: Dictionary = Handlers.route(0, 1)
	check(sword.handler == 0 and sword.hosted and sword.note.contains("no handler"), "definition 0 (handler 0) is the no-handler route")
	var halberd: Dictionary = Handlers.route(1, 1)
	print("definition 1: handler %d hosted %s refusal '%s'" % [halberd.handler, halberd.hosted, halberd.refusal])
	check(Handlers.route(170, 1).refusal.contains("not in definitions.json"), "index 170 refuses")
	# Every fixed catalog identity has a definition that routes.
	# The one fixed identity without a definition is the Museum's unidentified "Cavern find" (item_catalog.gd documents it).
	const NO_DEFINITION := ["draracle/prop/1108/sample"]
	var unresolved := []; var total := 0
	for id in Catalog.FIXED:
		total += 1
		var index: int = Catalog.definition(id)
		if index < 0 or Handlers.route(index, 1).handler < 0: unresolved.append(id)
	check(total > 0 and unresolved == NO_DEFINITION, "every fixed catalog identity but the documented Cavern find resolves to a routed definition (%s of %d)" % [unresolved, total])
	# Family 1 (player_item_controller.use): every identity with an implemented use routes hosted for its dispatcher mode.
	var usable := 0; var not_hosted := []
	for id in Catalog.ids("jungle"):
		var kind: String = Catalog.use_kind(id)
		if kind == "": continue
		usable += 1
		var r: Dictionary = Handlers.route(Catalog.definition(id), Handlers.mode_for_use_kind(kind))
		if int(r.handler) > 0 and not r.hosted: not_hosted.append("%s (%s handler %d mode %d)" % [id, kind, r.handler, Handlers.mode_for_use_kind(kind)])
	check(usable > 0 and not_hosted.is_empty(), "every usable catalog identity (%d) routes hosted for its mode (%s)" % [usable, not_hosted])
	check(Handlers.mode_for_use_kind("poison_paint") == 12 and Handlers.mode_for_use_kind("dragon_blood") == 16 and Handlers.mode_for_use_kind("aloe") == 1, "use kinds map to the contract's modes: coat 12, dragon blood 16, else 1")
	# Family 2 (equip): every off-hand identity may be equipped (equip_allowed) and the passive bracers' slot hooks are named unhosted.
	const Equipment := preload("res://scripts/lol2/player_equipment.gd")
	var offhand := 0; var hooks := {}
	for id in Catalog.ids("jungle"):
		if not Equipment.offhand(id): continue
		offhand += 1
		var r: Dictionary = Handlers.route(Catalog.definition(id), 10)
		check(bool(r.equip_allowed), "off-hand %s may be equipped (route mode 10)" % id)
		if int(r.handler) > 0 and not r.hosted: hooks[int(r.handler)] = r.hint
	check(offhand > 0 and hooks.keys().size() == 2 and hooks.has(19) and hooks.has(23) and str(hooks[19]).contains("slot hook"), "the two passive bracer handlers (19, 23) are equippable with their slot hooks named unhosted (%s)" % [hooks])
	check(not bool(Handlers.route(int(by_name.get("8-Prism", -1)), 1).equip_allowed), "equip_allowed is false outside modes 10/11")
	# Family 3 (on-hit): the strike sites record the equipped item's mode-5 route; Prism and the Net name their modules, a plain weapon none.
	var hit: Dictionary = Handlers.record_hit("museum:item8:Prism" if Catalog.known("museum:item8:Prism") else "")
	var prism_id := ""
	for id in Catalog.ids("jungle"):
		if Catalog.definition(id) == int(by_name.get("8-Prism", -1)): prism_id = id; break
	var net_id := ""
	for id in Catalog.ids("jungle"):
		if Catalog.definition(id) == int(by_name.get("26-Net of Exile", -1)): net_id = id; break
	check(not prism_id.is_empty() and Handlers.record_hit(prism_id).module.ends_with("prism_blind.gd") and Handlers.last_hit_route.item == prism_id, "a strike with the Prism (%s) records the prism_blind route" % prism_id)
	check(not net_id.is_empty() and Handlers.record_hit(net_id).module.ends_with("net_exile_hold.gd"), "a strike with the Net of Exile (%s) records the net_exile_hold route" % net_id)
	# Grok's 42 handler groups (2026-10-31E item 4): every table index 1..107 in exactly one group, no index outside the table,
	# every row labelled LIKELY, the labels data only (nothing hosted from them: HOSTED is unchanged by GROUPS).
	var seen := {}
	var dupes := 0
	for row in Handlers.GROUPS:
		for h in row.handlers:
			if seen.has(h): dupes += 1
			seen[h] = int(row.group)
		check(not str(row.likely).is_empty() and row.has("grade") and row.has("callee"), "group %d carries a LIKELY label, Grok's grade and callee" % int(row.group))
	check(Handlers.GROUPS.size() == 42 and seen.size() == 107 and dupes == 0, "42 groups cover handlers 1..107 once each (%d handlers, %d duplicates)" % [seen.size(), dupes])
	var outside := 0
	for h in seen: if h < 1 or h > 107 or not table.has(h): outside += 1
	check(outside == 0, "no grouped handler lies outside the 0xC860 table (%d)" % outside)
	var shift: Dictionary = Handlers.route(int(by_name.get("31-Shift", -1)), 1)
	check(shift.group == 4 and not shift.hosted and shift.hint.contains("LIKELY (group 4") and shift.likely.contains("missile"), "an unhosted route carries its group's LIKELY label in the hint (%s)" % shift.hint.left(80))
	check(Handlers.group_of(0).is_empty() and Handlers.route(int(by_name.get("5-Short swd", -1)), 1).group == 0, "handler 0 has no group")
	var plain_hit: Dictionary = Handlers.record_hit("cave:guard52:Short_Sword")
	check(plain_hit.handler == 0 and plain_hit.hosted and plain_hit.module.is_empty(), "a strike with a plain weapon records handler 0 (no hook)")
	print("Item handlers: %d failures" % failures)
	if failures == 0: print("PASS item handlers: 170 definitions routed, 108 handler indexes, %d hosted modules, the rest refused with a hint; catalog identities resolve" % Handlers.HOSTED.size())
	quit(0 if failures == 0 else 1)
