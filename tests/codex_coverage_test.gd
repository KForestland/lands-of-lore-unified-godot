extends SceneTree
## Every item_catalog and act2_items_catalog identity has a Codex entry.
## No scene is built. Definitions come from the staged definitions file when it is present.
const Catalog := preload("res://scripts/lol2/item_catalog.gd")
const Act2 := preload("res://scripts/lol2/act2_items_catalog.gd")
const Definitions := preload("res://scripts/lol2/item_definitions.gd")

const LICHEN: Array[int] = [518, 521, 522, 527, 528, 533, 534, 539, 540, 545, 546, 551, 552, 557]
const NAMED: Array[String] = [
	"act2:L12_CM:blue_bow", "act2:L12_CM:item5", "act2:L13_RC:dark_sword", "act2:L13_RC:enchanted_thohan",
	"act2:L13_RC:dreamstone", "act2:L13_RC:dawn_bestial_disk", "act2:L12_CM:kenneth_picture", "act2:L12_CM:kenneth_charm",
	"act2:L8_SJ:larkhon_vapors", "act2:L8_SJ:shaman_amaranth", "act2:L8_SJ:dawn_control_token", "act2:L10_DC:priest_urn",
	"act2:L10_DC:priest_ankh", "act2:L10_DC:emperor_remains"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var error := validate()
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	print("PASS codex coverage: every catalog item has a Codex entry")
	quit(0)

func validate() -> String:
	var text := FileAccess.get_file_as_string("res://data/lol2/codex.json")
	if text.is_empty():
		return "Codex file is missing."
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return "Codex JSON did not parse."
	var codex: Dictionary = parsed
	for section in ["Items", "Creatures", "Characters", "Lore"]:
		var page: Variant = codex.get(section)
		if not page is Dictionary or (page as Dictionary).is_empty():
			return "Codex section missing: " + section
	var items: Dictionary = codex["Items"]
	var missing: Array[String] = []
	for id in wanted().keys():
		var entry: Variant = items.get(str(id))
		if not entry is Dictionary:
			missing.append(str(id))
			continue
		var row: Dictionary = entry
		if str(row.get("name", "")).is_empty() or str(row.get("text", "")).is_empty():
			missing.append(str(id))
	if missing.is_empty():
		return ""
	if missing.size() > 6:
		return "Codex missing %d catalog items. First: %s" % [missing.size(), ", ".join(missing.slice(0, 6))]
	return "Codex missing catalog items: " + ", ".join(missing)

func wanted() -> Dictionary:
	var out := {}
	var scope := "world" if Definitions.ready() else "jungle"
	for id in Catalog.ids(scope):
		out[str(id)] = true
	for id in act2_candidates():
		if Act2.valid(id):
			out[id] = true
	return out

func act2_candidates() -> Array[String]:
	var ids: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_items_source.json"))
	if not parsed is Dictionary or not (parsed as Dictionary).get("areas") is Dictionary:
		return ids
	var areas: Dictionary = (parsed as Dictionary)["areas"]
	for area in areas:
		var block: Variant = areas[area]
		if not block is Dictionary:
			continue
		var rows: Variant = (block as Dictionary).get("items", [])
		if not rows is Array:
			continue
		for row in rows:
			if not row is Dictionary:
				continue
			var ident := str((row as Dictionary).get("id", ""))
			if ident.is_empty():
				continue
			ids.append(ident)
			if int((row as Dictionary).get("definition", -1)) == 98:
				ids.append(ident + ":charged:yellow")
				ids.append(ident + ":charged:white")
				ids.append(ident + ":charged:blue")
	ids.append("act2:L9_DR:tower_blank")
	ids.append("act2:L9_DR:tower_blank:charged:yellow")
	ids.append("act2:L9_DR:tower_blank:charged:white")
	ids.append("act2:L9_DR:tower_blank:charged:blue")
	ids.append("act2:L13_RC:item145")
	ids.append("act2:L13_RC:item146")
	ids.append("act2:L13_RC:item147")
	ids.append("act2:L14_HT:item65")
	ids.append("act2:L14_HT:trial_idol371")
	ids.append("act2:L14_HT:trial_idol372")
	ids.append("act2:L14_HT:trial_idol384")
	ids.append("act2:L14_HT:post_shard")
	for number in 9:
		ids.append("act2:L16_CA:pad_lichen%d" % number)
	for number in LICHEN:
		ids.append("act2:L16_CA:lichen%d" % number)
	for number in range(159, 171):
		ids.append("act2:L10_DC:silverleaf%d" % number)
	for number in [91, 92, 93, 94, 95]:
		ids.append("act2:L14_HT:hopper_corpse%d" % number)
	ids.append_array(NAMED)
	return ids
