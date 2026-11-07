extends RefCounted
## All 170 original item definitions (GLOBAL.MIX entry 3984507021), staged by tools/prepare_item_definitions.py into
## assets/lol2/generated/items/definitions.json. Read-only data: names, identities, handler indices, defense,
## descriptors, class byte and inventory icons. Stats the port has not traced stay raw ("undecoded") and are not used.
const PATH := "res://assets/lol2/generated/items/definitions.json"
const COUNT := 170
## Original 24x24 inventory icons (LOCAL flags 0x48E), staged by tools/prepare_item_inventory_icons.py. The `icon`
## above is the GROUND sprite (0x28E, an item lying in the world); the inventory, equipment slots and HUD weapon
## ring show these instead (audit_20261028 ITEMS_AUDIT s3).
const INVENTORY_ICONS_PATH := "res://assets/lol2/generated/items/inventory_icons.json"
## Native +0x3F is a slot mask: 8FD40 tests (1 << slot) across original slots0..5.
## Cocos definition167 mask0x43 admits original slots0/1 (native entry replay, AI_COMMS Cocos contract).
## The mapping below to modern weapon/armor/offhand remains an adapter (docs/DEVIATIONS.md).
## Original slots0/1 and handler equip/unequip hooks are not hosted here; 0x43 items remain carried only.
const CLASS_SLOTS := {0x44:"weapon",0x48:"weapon",0x50:"offhand",0x53:"offhand",0x60:"armor"}

static var _rows: Array = []
static var _by_name: Dictionary = {}
static var _by_identity: Dictionary = {}
static var _inventory_icons: Array = []

static func ready() -> bool:
	_load()
	return _rows.size() == COUNT

static func _load() -> void:
	if not _rows.is_empty() or not FileAccess.file_exists(PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or not data.get("definitions") is Array or data.definitions.size() != COUNT: return
	_rows = data.definitions
	for row in _rows:
		_by_name[str(row.name).strip_edges()] = int(row.index)
		_by_identity[int(row.identity)] = int(row.index)

static func row(index: int) -> Dictionary:
	_load()
	return _rows[index] if index >= 0 and index < _rows.size() else {}

## Definition index for an original name ("5-Short swd"), or -1. Names compare without edge spaces: the original
## "136-SS3 " carries a trailing space that the Jungle world-item source strips.
static func by_name(name: String) -> int:
	_load()
	return int(_by_name.get(name.strip_edges(), -1))

static func by_identity(identity: int) -> int:
	_load()
	return int(_by_identity.get(identity, -1))

static func name(index: int) -> String: return str(row(index).get("name", ""))
static func label(index: int) -> String: return str(row(index).get("label", ""))
static func icon(index: int) -> String:
	var info = row(index).get("icon")
	return str(info.get("path", "")) if info is Dictionary else ""
## Path of the original 24x24 inventory icon of definition `index`, or "" (ghost rows, or icons not staged).
static func inventory_icon(index: int) -> String:
	if _inventory_icons.is_empty() and FileAccess.file_exists(INVENTORY_ICONS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_ICONS_PATH))
		if data is Dictionary and data.get("definitions") is Array and data.definitions.size() == COUNT: _inventory_icons = data.definitions
	if index < 0 or index >= _inventory_icons.size(): return ""
	return str(_inventory_icons[index].get("path", ""))
static func defense(index: int) -> int: return int(row(index).get("defense", 0))
static func handler(index: int) -> int: return int(row(index).get("handler", 0))
static func item_class(index: int) -> int: return int(row(index).get("item_class", 0))
## Raw record byte at `offset` (0..90) from the staged record_hex, or -1. The Thieves' Den payment test reads byte +0x43
## bit 0 (host slot 0xA8; docs/thieves-den.md).
static func raw_byte(index: int, offset: int) -> int:
	var hex := str(row(index).get("record_hex", ""))
	if offset < 0 or hex.length() < (offset + 1) * 2: return -1
	return hex.substr(offset * 2, 2).hex_to_int()
static func slot(index: int) -> String: return str(CLASS_SLOTS.get(item_class(index), ""))
## Ghost rows 152..156 have no inventory picture; they are projectile/spell placeholders, never carried.
static func carriable(index: int) -> bool: return not row(index).is_empty() and not bool(row(index).get("ghost", true))
