extends RefCounted
## Playtest start points (docs/playtest-starts.md; owner request: start at a story checkpoint instead of replaying hours).
## scripts/lol2/playtest_starts.json lists REAL earned saves written by the automated campaign/route tests, in story
## order, each pinned by sha256. tools/prepare_playtest_starts.py stages the files into SAVE_DIR (generated media,
## git-ignored, exported through the assets/*.json include filter). The original-game gate shows the list and starts an
## entry through its existing "Resume <area>" branch with the staged res:// file as the save path: the same reader,
## validator, resume meta and scene as a normal resume. Nothing is injected and the player's own quicksaves are not touched.
const MANIFEST := "res://scripts/lol2/playtest_starts.json"
const SAVE_DIR := "res://assets/lol2/generated/playtest_starts/"
const MuseumSave = preload("res://scripts/lol2/museum_save.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
const HiveSave = preload("res://scripts/lol2/hive_save.gd")
## Resume kinds = the gate's existing resume branches. A manifest entry with any other kind is refused (Act 2 map saves
## need a production map-save resume branch first; docs/playtest-starts.md).
const KINDS := {
	"museum": {"format": "lol2-restoration-museum", "scene": "res://scenes/lol2/museum_walkthrough.tscn", "area": "Museum"},
	"jungle": {"format": "lol2-restoration-jungle", "scene": "res://scenes/lol2/jungle_walkthrough.tscn", "area": "Jungle"},
	"hive": {"format": "lol2-restoration-hive", "scene": "res://scenes/lol2/hive_review.tscn", "area": "Hive"},
	"darker": {"format": "lol2-restoration-darker-jungle", "scene": "res://scenes/lol2/darker_jungle.tscn", "area": "Darker Jungle"},
	"dark_halls": {"format": "lol2-restoration-dark-halls", "scene": "res://scenes/lol2/dark_halls.tscn", "area": "Dark Halls"},
}
const FIELDS := ["id", "title", "act", "area", "resume", "save", "sha256", "source", "identities"]
## Provenance every entry pins (lead addendum 2026-11-03): producing test, the commit it ran on, and the input save's sha256
## (null only for a leg that starts a new game; Act 2 *_qualified_save.json files already record theirs).
const SOURCE_FIELDS := ["test", "commit", "input_sha256"]

## The manifest's entries, in order. {"error": String, "entries": Array}; any malformed entry makes the whole list an error.
static func manifest(path: String = MANIFEST) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "Playtest start list missing.", "entries": []}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("schema", 0)) != 1 or not data.get("entries") is Array:
		return {"error": "Playtest start list is damaged.", "entries": []}
	var ids := {}
	var saves := {}
	for entry in data.entries:
		var error := entry_error(entry)
		if error.is_empty() and (ids.has(entry.id) or saves.has(entry.save)): error = "duplicate id or save"
		if not error.is_empty():
			return {"error": "Playtest start list entry invalid: %s (%s)" % [str(entry.get("id", "?")) if entry is Dictionary else "?", error], "entries": []}
		ids[entry.id] = true
		saves[entry.save] = true
	return {"error": "", "entries": data.entries}

static func entry_error(entry: Variant) -> String:
	if not entry is Dictionary: return "not an object"
	for field in FIELDS:
		if not entry.has(field): return "missing " + field
	if not KINDS.has(str(entry.resume)): return "unknown resume kind " + str(entry.resume)
	var save := str(entry.save)
	if not save.is_valid_filename() or not save.ends_with(".json"): return "unsafe save name"
	var sha := str(entry.sha256)
	if sha.length() != 64 or not sha.is_valid_hex_number(): return "bad sha256"
	if str(entry.title).strip_edges().is_empty(): return "empty title"
	if not entry.source is Dictionary: return "source not an object"
	for field in SOURCE_FIELDS:
		if not entry.source.has(field): return "source missing " + field
	var commit := str(entry.source.commit)
	if commit.length() != 40 or not commit.is_valid_hex_number(): return "source.commit is not a full commit id"
	var input: Variant = entry.source.input_sha256
	if input != null and (str(input).length() != 64 or not str(input).is_valid_hex_number()): return "bad source.input_sha256"
	var ids: Variant = entry.identities
	if not ids is Dictionary or not ids.get("contains") is Dictionary or not ids.get("excludes") is Dictionary or not ids.get("values") is Dictionary: return "identities needs contains/excludes/values objects"
	if ids.contains.is_empty() and ids.values.is_empty(): return "identities pin nothing"
	return ""

static func at_path(state: Variant, path: String) -> Variant:
	var value: Variant = state
	for key in path.split("."):
		if not value is Dictionary or not value.has(key): return null
		value = value[key]
	return value

static func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b

## The persistent identities the save must carry at this story point ("" = all present). contains/excludes: an Array at a
## dotted path must hold / must not hold each listed value; values: dotted path -> exact value (numbers numerically).
static func identity_error(entry: Dictionary, state: Dictionary) -> String:
	var ids: Dictionary = entry.identities
	for path in ids.contains:
		var list: Variant = at_path(state, str(path))
		if not list is Array: return "%s is not a list" % path
		for item in ids.contains[path]:
			if item not in list: return "%s lacks %s" % [path, item]
	for path in ids.excludes:
		var list: Variant = at_path(state, str(path))
		if list is Array:
			for item in ids.excludes[path]:
				if item in list: return "%s unexpectedly holds %s" % [path, item]
	for path in ids.values:
		if not same(at_path(state, str(path)), ids.values[path]): return "%s = %s, expected %s" % [path, at_path(state, str(path)), ids.values[path]]
	return ""

static func save_path(entry: Dictionary) -> String: return SAVE_DIR + str(entry.save)

## Staged file present and byte-identical to the manifest pin ("" = ok).
static func file_error(entry: Dictionary) -> String:
	var path := save_path(entry)
	if not FileAccess.file_exists(path): return "This start's save is missing from this build."
	if FileAccess.get_sha256(path) != str(entry.sha256): return "This start's save does not match the list (sha256)."
	return ""

## The game's own reader + validator for the entry's resume kind (the same calls the gate's resume branches make).
static func read(entry: Dictionary, path: String = "") -> Dictionary:
	if path.is_empty(): path = save_path(entry)
	match str(entry.resume):
		"museum": return MuseumSave.read_save(path)
		"jungle": return JungleSave.read_save(path)
		"hive": return HiveSave.read_save(path)
		"darker": return JungleSave.read_save(path, KINDS.darker.format)
		"dark_halls": return JungleSave.read_save(path, KINDS.dark_halls.format)
	return {"error": "Unknown resume kind.", "state": {}}
