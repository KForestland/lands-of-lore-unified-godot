extends RefCounted
## Catalog pairs only existing playable scenes and legacy validators.
const PROGRESSION_AREAS := ["L8_SJ","L9_DR","L10_DC","L12_CM","L13_RC","L14_HT","L16_CA","L17_HC","L19_BC","L20_BB"]
const ROWS := {
 "L10_DC": {
  "scene": "res://scenes/lol2/maps/L10_DC.tscn",
  "format": "lol2-restoration-map-L10_DC",
  "label": "Dracoid Cemetery",
  "kind": "act2",
  "legacy": "user://saves/map_L10_DC_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L10_DC.tscn"
  ]
 },
 "L12_CM": {
  "scene": "res://scenes/lol2/maps/L12_CM.tscn",
  "format": "lol2-restoration-map-L12_CM",
  "label": "Claw Mountains",
  "kind": "act2",
  "legacy": "user://saves/map_L12_CM_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L12_CM.tscn"
  ]
 },
 "L13_RC": {
  "scene": "res://scenes/lol2/maps/L13_RC.tscn",
  "format": "lol2-restoration-map-L13_RC",
  "label": "Citadel of the Ruloi",
  "kind": "act2",
  "legacy": "user://saves/map_L13_RC_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L13_RC.tscn"
  ]
 },
 "L14_HT": {
  "scene": "res://scenes/lol2/maps/L14_HT.tscn",
  "format": "lol2-restoration-map-L14_HT",
  "label": "Huline Temple",
  "kind": "act2",
  "legacy": "user://saves/map_L14_HT_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L14_HT.tscn"
  ]
 },
 "L16_CA": {
  "scene": "res://scenes/lol2/maps/L16_CA.tscn",
  "format": "lol2-restoration-map-L16_CA",
  "label": "City of the Ancients",
  "kind": "act2",
  "legacy": "user://saves/map_L16_CA_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L16_CA.tscn"
  ]
 },
 "L17_HC": {
  "scene": "res://scenes/lol2/maps/L17_HC.tscn",
  "format": "lol2-restoration-map-L17_HC",
  "label": "Subterranean Caverns",
  "kind": "act2",
  "legacy": "user://saves/map_L17_HC_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L17_HC.tscn"
  ]
 },
 "L19_BC": {
  "scene": "res://scenes/lol2/maps/L19_BC.tscn",
  "format": "lol2-restoration-map-L19_BC",
  "label": "Belial’s Laboratory",
  "kind": "act2",
  "legacy": "user://saves/map_L19_BC_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L19_BC.tscn"
  ]
 },
 "L1_DC": {
  "scene": "res://scenes/lol2/cave_walkthrough.tscn",
  "format": "lol2-restoration-walkthrough",
  "label": "Draracle’s Caverns",
  "kind": "cave",
  "legacy": "user://saves/cavern_quicksave.json",
  "scenes": [
   "res://scenes/lol2/cave_walkthrough.tscn"
  ]
 },
 "L20_BB": {
  "scene": "res://scenes/lol2/maps/L20_BB.tscn",
  "format": "lol2-restoration-map-L20_BB",
  "label": "Birthing Chamber",
  "kind": "act2",
  "legacy": "user://saves/map_L20_BB_quicksave.json",
  "scenes": [
   "res://scenes/lol2/maps/L20_BB.tscn"
  ]
 },
 "L3_DH": {
  "scene": "res://scenes/lol2/museum_walkthrough.tscn",
  "format": "lol2-restoration-museum",
  "label": "Draracle’s Museum",
  "kind": "museum",
  "legacy": "user://saves/museum_quicksave.json",
  "scenes": [
   "res://scenes/lol2/museum_walkthrough.tscn"
  ]
 },
 "L4_HJ": {
  "scene": "res://scenes/lol2/jungle_walkthrough.tscn",
  "format": "lol2-restoration-jungle",
  "label": "Huline Jungle",
  "kind": "jungle",
  "legacy": "user://saves/jungle_quicksave.json",
  "scenes": [
   "res://scenes/lol2/jungle_walkthrough.tscn",
   "res://scenes/lol2/act2_jungle_return.tscn"
  ]
 },
 "L5_HC": {
  "scene": "res://scenes/lol2/hive_review.tscn",
  "format": "lol2-restoration-hive",
  "label": "Hive Caves",
  "kind": "hive",
  "legacy": "user://saves/hive_quicksave.json",
  "scenes": [
   "res://scenes/lol2/hive_review.tscn"
  ]
 },
 "L7_DH": {
  "scene": "res://scenes/lol2/dark_halls.tscn",
  "format": "lol2-restoration-dark-halls",
  "label": "Dark Halls",
  "kind": "jungle",
  "legacy": "user://saves/dark_halls_quicksave.json",
  "scenes": [
   "res://scenes/lol2/dark_halls.tscn"
  ]
 },
 "L8_SJ": {
  "scene": "res://scenes/lol2/darker_jungle.tscn",
  "format": "lol2-restoration-darker-jungle",
  "label": "Savage Jungle",
  "kind": "act2",
  "legacy": "user://saves/darker_jungle_quicksave.json",
  "scenes": [
   "res://scenes/lol2/darker_jungle.tscn"
  ]
 },
 "L9_DR": {
  "scene": "res://scenes/lol2/dragon_level.tscn",
  "format": "lol2-restoration-dragon-preview",
  "label": "Dracoid Ruins",
  "kind": "act2",
  "legacy": "user://saves/dragon_preview_quicksave.json",
  "scenes": [
   "res://scenes/lol2/dragon_level.tscn"
  ]
 }
}

static func id_for(host: Node) -> String:
 var scene := host.scene_file_path
 for area in ROWS:
  if scene in ROWS[area].scenes: return area
 return ""
static func cave_checkpoints() -> int:
 # Cave inherits default_full_map=true from textured_cave_review; its normal route adds two chain checkpoints.
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/original_floors/full_walk.json"))
 return data[0].checkpoints.size() + 2 if data is Array and not data.is_empty() else 0
static func validate_area(area: String, value: Variant) -> String:
 if not ROWS.has(area): return "Unknown saved area."
 match ROWS[area].kind:
  "cave": return load("res://scripts/lol2/walkthrough_save.gd").validate(value, cave_checkpoints())
  "museum": return load("res://scripts/lol2/museum_save.gd").validate(value)
  "hive": return load("res://scripts/lol2/hive_save.gd").validate(value)
  "jungle": return load("res://scripts/lol2/jungle_save.gd").validate(value, ROWS[area].format)
  _: return load("res://scripts/lol2/act2_save.gd").validate(value, ROWS[area].format)
static func prepare_area(area: String, value: Dictionary) -> Dictionary:
 var result := value.duplicate(true)
 if area == "L1_DC": result = load("res://scripts/lol2/walkthrough_save.gd").migrate_loaded(result)
 return result

## Match the opening gate's per-area checks before touching the live session.
## Native script bundles are optional for map preview, as on the existing gate.
static func assets_error(area: String) -> String:
 if not ROWS.has(area): return "Unknown saved area."
 var ready := true
 match area:
  "L3_DH": ready = load("res://scripts/lol2/museum_walkthrough.gd").assets_ready()
  "L4_HJ": ready = load("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()
  "L5_HC": ready = load("res://scripts/lol2/hive_review.gd").assets_ready()
  "L7_DH": ready = load("res://scripts/lol2/dark_halls.gd").arrival_assets_ready()
  "L8_SJ": ready = load("res://scripts/lol2/darker_jungle.gd").arrival_assets_ready()
  "L9_DR": ready = load("res://scripts/lol2/dragon_level.gd").arrival_assets_ready()
  _:
   if area in PROGRESSION_AREAS: ready = load("res://scripts/lol2/act2_map.gd").map_assets_ready(area)
 return "" if ready else "%s assets are missing from this build." % ROWS[area].label
