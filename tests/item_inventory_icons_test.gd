extends SceneTree
## Original 24x24 inventory icons (tools/prepare_item_inventory_icons.py, LOCAL flags 0x48E) behind the catalog.
## Checks the staged mapping (165 carriable definitions, ghost rows none, pinned tag links), that every carried
## identity in every scope shows its definition's inventory icon and not its ground sprite (which stays the world
## billboard picture), the one identity without a definition, the HUD weapon ring path, and the inventory panel list,
## slots and details. Headless.
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Equipment = preload("res://scripts/lol2/player_equipment.gd")
const NO_DEFINITION := ["draracle/prop/1108/sample"]
## Definition name -> inventory icon resource, from the audit (ITEMS_AUDIT_20261028 s3: tag "2", "38", "41"; the
## Stalagmite's adjacent resource 23).
const PINNED := {"2-Br Mace":272,"38-Guard shield":295,"41-Mail shirt":302,"1-Stalagmite":23}

func _init() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	print("FAIL item_inventory_icons: ", message)
	quit(1)

func icon_size(path: String) -> Vector2i:
	if path.is_empty() or not FileAccess.file_exists(path): return Vector2i.ZERO
	var image := Image.load_from_file(path)
	return image.get_size() if image != null else Vector2i.ZERO

func run() -> void:
	if not Definitions.ready() or not FileAccess.file_exists(Definitions.INVENTORY_ICONS_PATH):
		return fail("Inventory icons not staged (run tools/prepare_item_inventory_icons.py)")
	var data = JSON.parse_string(FileAccess.get_file_as_string(Definitions.INVENTORY_ICONS_PATH))
	if int(data.staged) != 165 or int(data.icon_resources) != 170: return fail("Staged counts %s/%s" % [data.staged, data.icon_resources])
	for index in Definitions.COUNT:
		var path := Definitions.inventory_icon(index)
		if Definitions.carriable(index) != not path.is_empty(): return fail("Carriable/icon disagree for %d" % index)
		if not path.is_empty():
			if icon_size(path) != Vector2i(24, 24): return fail("Icon %d is not 24x24" % index)
			if path == Definitions.icon(index): return fail("Icon %d is the ground sprite" % index)
	for name in PINNED:
		var index := Definitions.by_name(name)
		if index < 0 or int(data.definitions[index].resource) != int(PINNED[name]): return fail("Pinned link changed: " + name)
	var checked := 0
	for scope in Catalog.SCOPES:
		for id in Catalog.ids(scope):
			if id in NO_DEFINITION: continue
			var path := Catalog.inventory_icon(id)
			if path != Definitions.inventory_icon(Catalog.definition(id)): return fail("Not the definition icon: " + id)
			if icon_size(path) != Vector2i(24, 24): return fail("No 24x24 inventory icon: " + id)
			if path == Catalog.icon(id): return fail("Inventory shows the ground sprite: " + id)
			if Catalog.slot(id) == "weapon" and Equipment.inventory_icon(id) != path: return fail("HUD ring icon differs: " + id)
			checked += 1
	if checked < 205: return fail("Only %d identities checked" % checked)
	# The 11 identities that showed no picture before: Cave Aloe x9 and the Iron Flute now have one; the
	# unidentified cavern sample has no definition and still has none.
	for id in Catalog.ids("cave") + Catalog.ids("jungle"):
		if Catalog.icon(id).is_empty() and id not in NO_DEFINITION and icon_size(Catalog.inventory_icon(id)) != Vector2i(24, 24):
			return fail("Former no-picture identity still empty: " + id)
	for id in NO_DEFINITION:
		if Catalog.inventory_icon(id) != Catalog.icon(id): return fail("Fallback changed: " + id)
	# Inventory panel: list, equipment slot and details use the inventory icon.
	var inv = preload("res://scripts/lol2/museum_inventory.gd").new()
	inv.item_ids = ["museum:item11:Fine_Longsword", "museum:item10:Mail_Shirt", "cave:prop791:harvest1:Cave_Aloe"]
	inv.change_equipment = func(_id): return true
	inv.change_armor = func(_id): return true
	root.add_child(inv)
	await process_frame
	await process_frame
	for index in inv.item_list.item_count:
		var id := str(inv.item_list.get_item_metadata(index))
		var texture: Texture2D = inv.item_list.get_item_icon(index)
		if texture == null or texture.get_size() != Vector2(24, 24): return fail("Inventory list picture for " + id)
		var expected := Image.load_from_file(Catalog.inventory_icon(id))
		if texture.get_image().get_data() != expected.get_data(): return fail("Inventory list shows another picture for " + id)
	inv.activate_item(0)
	var worn: Texture2D = inv.equipment_slots[2].get_node("Worn").texture
	if worn == null or worn.get_size() != Vector2(24, 24): return fail("Weapon slot does not show the inventory icon")
	inv.select_item(1)
	if inv.detail_icon.texture == null or inv.detail_icon.texture.get_size() != Vector2(24, 24): return fail("Detail picture")
	inv.queue_free()
	print("PASS item_inventory_icons: 165 icons, %d carried identities" % checked)
	quit(0)
