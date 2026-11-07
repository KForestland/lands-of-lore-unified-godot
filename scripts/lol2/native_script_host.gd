extends RefCounted
## Shared native script host: runs the original command groups of a level archive as data.
##
## Input: one area file written by tools/prepare_native_scripts.py
## (res://scripts/lol2/native_scripts/<AREA>.json, generated and gitignored).
## Pure data and logic. No scene nodes. The world side listens to the signals below.
##
## Sources: G95 HOST_CONTRACT (opcodes) and G97 steps 1-2 (record matchers, predicate table), in
## AI_COMMS/grok_backlog_20261028/G95_r12q_progression/mechanism and .../G97_opcode_table.
##
## fire_event(object_ref, event_kind, input) works in two phases, like the native walk that enqueues:
##  1. Every record of the object is matched with the PROVEN matcher of its kind, against the state
##     as it is when the event fires. A kind-0x13 record right after it is the predicate trailer
##     (word +2 = table index); the PROVEN predicate paths are evaluated next. Each record is then
##     "rejected" (the original test is false), "unhosted" (a path that is not PROVEN, or an input
##     the caller did not supply), or accepted.
##  2. Accepted groups run in record order. A group runs only as a whole: every opcode needs a
##     handler, handlers stage writes on a copy, and one refusal drops the copy. Nothing is
##     committed and no signal is sent. The group goes to `unhosted` with every reason found.
##
## `input` keys are the report's own names; gameplay meanings stay UNKNOWN:
##   caller_byte, caller_byte_2 (kinds 5/6), arg (kind 8 u16), arg_c (kind 4: the walker's argument
##   dword at +0xC), word0, word2, dword_1e, dword_26 (kind 9 input), global_23331 (the signed byte
##   at 0x23331, kind 9 mode 4), context (raw ref of the object whose pointer is in 0xB7D80, read by
##   predicate left type 5; which object that is natively stays UNKNOWN, so the caller names it).
##
## Command targets: the kind byte's object class is PROVEN (G97 step_opcode5: 0x10 control, 0x20
## movable, 3 prop/spatial, 2 actor, 4 a fifth class); which record index N is stays LIKELY (G97
## step4_kind20), so binding "0xKK:N" to "control:N" / "movable:N" / "prop:N" / "actor:N" is the
## adapter "slot_index_binding". With adapters off, state stays keyed by the raw address.
## Commands of one group apply in file order; queue order and timing between opcode < 0xC3 and
## >= 0xC3 are not proven, the per-object queue (0x26E6C, epilogue 0x663B8) is not modelled, and no
## motion over time is modelled.
##
## Adapters (owner rule 2026-10-30: workaround or modernize when it plays as intended): a handler or
## matcher path that rests on a G97 LIKELY reading calls use_adapter(name). With the adapter enabled
## the group still runs as a whole and its result lists "adapters"; adapter_log keeps every such
## run. With adapters disabled (set_adapters_enabled(false)) only PROVEN paths run. ADAPTERS names
## each one; docs/DEVIATIONS.md has a row for each. No adapter is PROVEN.

signal object_state_changed(ref: String, field: String, value: int)
signal local_changed(index: int, value: int)
signal sound_request(request: int)
signal record_state_changed(record_file_offset: int, field: String, value: int)
signal global_changed(address: int, value: int)
## Opcode 21 (adapter opcode21_movie): the table name the command would play, "%s.vqa", and its byte 5.
signal movie_request(index: int, name: String, byte5: int)
## Opcode 9 arm 0x15 (adapter opcode9_enqueue): the object's kind-6 event with caller byte 0x14 was enqueued (and fired).
signal event_enqueued(ref: String, event_kind: int, caller_byte: int)
## Opcode 3 kind 1 (adapter opcode3_item_grant): the item definition identity and the command's byte 8.
signal item_request(ref: String, identity: int, arg: int)
## Opcode 12 (adapter opcode12_room): the room-archive stem slot (scripts/lol2/room_stems.json).
signal room_request(index: int, stem: String, archive: String)
## Opcode 15 (adapter opcode15_effect_request): form = byte 4, ref = the command's object, lookup = the (byte 5, word +6) object.
signal effect_request(form: int, ref: String, lookup: String)
## Opcode 19 (adapter opcode19_effect_record): the record 0x66130 builds for the object's vtable slot +0x80.
signal effect_record_request(ref: String, word0: int, word2: int, value: int, byte9: int)

const FORMAT := "lol2-native-scripts-2"
const FIELD_TRAVEL := "travel_0x50"      ## low word at object +0x50 (opcode 1 on mode 6)
const FIELD_BYTE25 := "byte_0x25"        ## object byte +0x25 (opcode 16; predicate left type 5)
const FIELD_SELECTOR := "selector_0x3d"  ## object byte +0x3D (opcode 5 with byte5 == 0)
const FIELD_BYTE26 := "byte_0x26"        ## object byte +0x26 (constructor copy of placement byte +0x1E)
const FIELD_BYTE30 := "byte_0x30"        ## spatial byte +0x30 (opcode 5, kind 3 / 2 adapter)
const FIELD_WORD7C := "word_0x7c"        ## actor word +0x7C (opcode 7; opcode 5 adapter)
const FIELD_BYTE22 := "byte_0x22"        ## byte +0x22 of a [0x22D0C] 44-byte record (opcode 204)
const FIELD_WORD00 := "word_0x00"        ## word +0 of a [0x22D08] 8-byte record (opcode 204)
const KIND_CELL := 0x20                  ## kind byte of cell 0x2B500 (movable constructor 0x62FD4)
## Kind byte -> class whose constructor fills that resolver cell (G97 step_opcode5 / step4_vtables).
const CLASS_BY_KIND := {0x10: "control", 0x20: "movable", 0x03: "prop", 0x02: "actor", 0x04: "kind4"}
## Kind byte -> exported placement table for the LIKELY index binding (adapter "slot_index_binding").
const TABLE_BY_KIND := {0x10: "control", 0x20: "movable", 0x03: "prop", 0x02: "actor"}
## Kind bytes for which 0x5FBC8 returns an object (all others return 0).
const OBJECT_KINDS: Array[int] = [0x01, 0x02, 0x03, 0x04, 0x10, 0x20, 0x80, 0x90, 0xA0, 0xB0, 0xC0]
## The built-in adapters. Each has a docs/DEVIATIONS.md row (2026-10-30).
const ADAPTERS := {
	"slot_index_binding": "kind-byte target N is placement record N of that kind's table (G95/G97 step4_kind20 LIKELY)",
	"b71a0_bit_clear": "object byte +0x15 bit 0x10 taken as clear when not known, so 0xB71A0 stores the object and returns its event list",
	"b5000_bit_clear": "object byte +0x15 bit 0x80 taken as clear when not known, so 0xB5000 runs the kind-4 walk",
	"opcode5_followups": "opcode 5 on movable/control stores +0x3D; the following +0x3B (0x5A8AC) and vtable+0xF8 loop are not modelled (G97 step_opcode5 LIKELY)",
	"opcode5_spatial": "opcode 5 on prop/actor stores +0x30 (actor also +0x7C = 0); the +0x32 frame and 0xF2814 restart are not modelled (G97 step_opcode5 LIKELY)",
	"opcode6_gates": "opcode 6 runs only with bit 0x200 of the object dword +0x14 set and bit 0x10 of byte +0x15 clear (0xB3EC8); the host takes both as such when not known (backlog3 item3)",
	"opcode6_record": "opcode 6 arms 0/1/2 act on the object's 42-byte record P ([0xB7D74] + word +0x18) through 0x9F584/0x9F5BC/0xB4130 whose paths depend on record flags the host does not hold; the host stages the start (arm 0), the list move (arm 1) and the restart bit (arm 2) as fields of ref record:<object> (backlog3 item3: 0 PROVEN logic on unknown state, 1/2 LIKELY)",
	"opcode14_timer": "opcode 14 arms 3/4 on the selected kind-2 record: arm 3 clears bit 0 of byte +5, sets bit 0x80 and lists the record (a nonzero command byte 5 stores the word +8 from byte +6 when bit 0x20 of byte +4 is set, else a draw the host cannot make); arm 4 clears bit 0x80, unlists and sets bit 0 (backlog3 item4 LIKELY)",
	"opcode9_release": "opcode 9 arm 2 (0xB49EC with 0) releases the player record 0x22CD8 through 0x9EFA8 and clears the 0x23C68 fields (backlog3 item4 LIKELY)",
	"opcode9_enqueue": "opcode 9 arm 0x15 stores the object as the context and enqueues its kind-6 record with byte +4 = 0x14 through 0xADDE0; the host fires that event with caller_byte 0x14 after the group commits (backlog3 item4 LIKELY)",
	"rix_fanfix_208_207": "load-time record patch L7_DH.MIX file 4882703 208 -> 207 (the landsoflore.de 0.2.0 Rix fanfix, owner 2026-10-30: ON in both editions): the trailer of actor 57's kind-9 record for group 14234 selects predicate 207 (+0x25 == 1) instead of 208 (+0x25 == 2, which nothing stores), so the exorcism group becomes reachable (ORIGINAL_BUGS_TO_FIX row 1; backlog3 item6 LIKELY writer)",
	"opcode8_player": "opcode 8 arms 0/1/2/3/10 act on the global player record at 0x22CD8 (select, release, set value, copy +0x4E to +0x3C, set value with flag); the host stages those as fields of ref 0x22cd8 (backlog3 item2 LIKELY)",
	"opcode8_gates": "opcode 8 arms 1-8 and 10 run only when bit 0x80000 of the object dword +0x14 is set, and arms 4-7 only on the 0x22CE0 gate (+0x3E sar 24 nonzero, argument -1 or equal to 0x22CE8); the host takes both gates as passing when not known (backlog3 item2)",
	"opcode21_movie": "opcode 21 byte 4 indexes the 85-name table at 0xE568 (PROVEN) and the world side plays that .vqa through the port's player for the name, or logs it when none exists (backlog3 item1 LIKELY: 0xCF3C0 opens the named container)",
	"opcode197_region_record": "opcode 197 arms 6/7 clear/set bit 2 of byte +0x19 of the 42-byte record [0x22D10] + (word +0x18 of region record N) * 42; the host does not load that word, so it keys the record by the region (0x22d10:region:N) and two regions sharing one record do not alias (backlog2 item2 PROVEN code on unloaded data)",
	"opcode197_list_mark": "opcode 197 arm 10 walks the 12-byte table [0x2B53C] (count [0x2B538]) for the entry whose word +6 is the command word and stores 1 at its byte +9, nothing when none matches; the host does not hold that table and takes the entry as present (0x2b53c:N byte_0x09 = 1) (backlog2 item2 PROVEN code on unheld data)",
	"opcode2_lock_flags": "opcode 2 arms 0x26/0x27 flag the object at encoded 0x22574 (ref 0x22574): 0x26 sets bit 0x80 and clears bit 0x10 of byte +0x228, runs the 0xD0138 reset and zeroes +0x9F/+0x21E/+0x9B and bit 3 of +0x19F; 0x27 clears bit 0x80 of +0x228, sets bit 0x80 of +0x229 and bit 0x10 of +0x228; the 0x151DAE/0x151B86 paths were not entered (backlog4 item0 LIKELY)",
	"opcode2_object_ad": "opcode 2 arm 5 stores the command's kind/word object (0x5FBC8) at dword +0xAD of the 0x22574 object (fields object_0xad_kind/_index) and, on a nonzero byte 5, sets bit 0 of +0x228 and runs the 0xD0138 reset, else clears that bit; 0x136594 was not entered (backlog4 item0 LIKELY)",
	"opcode2_counters": "opcode 2 arms 0x0C/0x0B add byte 5 * 100 into dword +0x15D / +0x159 of the 0x22574 object when the host global byte 0x223D4 is 0 (clamp 0x7FFFFFF0 and the 0xE810 threshold table through 0x12415C not modelled: the host keeps the hosted sum in dword_0x15d_added / dword_0x159_added) (backlog4 item0 LIKELY)",
	"opcode2_arm6_object": "opcode 2 arm 6 (0xB5B05) looks the command's kind/word object up through 0x5FBC8 and may call 0x79310 on it (not entered; byte 5 unread; the epilogue 0x663B8 not entered): the host records the call on the object (field opcode2_arm6_calls) and stores nothing else (backlog4 arm6 LIKELY)",
	"opcode1_other_modes": "opcode 1 on a movable whose mode (sar 24 of +0x50) is not 6 takes the not-equal path 0x63FCB: the same (byte 4 * word +0x4E) / 100 store into word +0x50 (PROVEN), then a compare of +0x4E with +0x48 that stores byte +0x55 or calls 0xE3924/0xB3B04/0xB3AC4, none entered: the host stages the travel word and nothing of that continuation (backlog5 item9 op1 mode1 LIKELY)",
	"kind2_timer_expiry": "kind-2 records are the object's timers: opcode 14 arm 3 clears bit 0 of byte +5 and lists them (arm 4 the reverse); the load scan 0xAEC74 keeps records with bits 0 and 0x80 of byte +5 clear; the expiry walk that fires a listed record's group (count word +8) was not entered: the host matches a kind-2 event on records whose byte +5 bit 0 is clear and leaves the clock to the world side (backlog5 item9 kind2 LIKELY)",
	"opcode2_arm18_clear": "opcode 2 arm 0x18 (0xD7890 fall-through, PROVEN): 0x91C0C loads the dword at 0x23348+0x90B and stores 0 there; a nonzero old pointer then goes to 0x95C24 and callees that were not entered: the host stages the clear only (backlog6 item1c LIKELY)",
	"opcode3_item_grant": "opcode 3 with kind byte 1 (0xD7890, PROVEN arm when the host global byte 0x223D4 is 0): 0x95B68(object, dword +4, byte 8, 1) looks the dword up in the player record's 0x5B-stride list (0x22CD8 +0x1C, count +0x20, dword +0x18) and hands the hit to vtable slot +0x6C (0xD259C -> 0x8FD40, 0x77ACC, not entered); the port's hosted sources read the dword as the item definition identity (give item): the host emits item_request(ref, identity, arg) and stores nothing (backlog6 item1c LIKELY)",
	"opcode12_room": "opcode 12 (0xED6D0 -> 0xED470, PROVEN path with two unread gates): byte 4 indexes the 46-slot stem table at 0xEA6C (scripts/lol2/room_stems.json: pool_, cave_, ..., settle1_ = 39, magic_ = 15, wpnext_ = 43), the archive name is the stem cut at '_' plus .mix, and an index below 46 ORs 2 into the byte at 0x269C4; the host emits room_request(index, stem, archive) and stages bit 1 of 0x269c4 (backlog6 item1c LIKELY: the gates bit 25 of 0x2279A and byte 0xB860 were not read)",
	"opcode210_arm9": "opcode 210 arm 9 (0x65B37, entered): stores ((byte 5 << 15) - byte 5) >> 8 into the word at 0x26D1E, and into 0x26D1C too when the dword at 0x26D2C differs from 0x26D1A (not read); byte 4 above 0xB is a PROVEN no-op; the host stages 0x26d1e and, as the LIKELY other path, 0x26d1c (backlog6 item1c LIKELY)",
	"opcode2_arm3c": "opcode 2 arm 0x3C (0xD7F5D, PROVEN: every branch returns 1, so the group goes on): with bit 0x10 of the 0x22574 object's +0x228 clear it calls 0x80064(0x23819, 1) (not entered, no store known); with it set and byte +0x1AB nonzero, byte 5 == 0 calls 0xD6B20(object, 0, 0), whose entered stores are dword +0x1A2 = 0 (unless bit 2 of +0x229) and, when the host global byte 0x223D4 is 0, byte +0x199 = 0 (the 0x223D0-gated +0x195 store not staged); byte 5 != 0 calls 0xD6D2C (not entered). The host stages those two zeros when the bit is set or not known and takes +0x1AB as nonzero (backlog6 item1d LIKELY); off = the PROVEN return without stores",
	"opcode2_arm57": "opcode 2 arm 57 sets bit 0 of byte +0x16 of the 0x22574 object when the host global byte 0x223D4 is 0, then calls 0xB3B04 (0xB7D70), 0xB3AC4 (0xB7D6C) and 0xD8D48, which were not entered; the host stages the bit only (backlog4 item0 LIKELY)",
	"opcode7_control_records": "opcode 7 on a control (slot 0x5D5F8): nothing when the control's word +0x36 is 0xFFFF, else every record of the [0x273E4] + word list whose dword +0x3A >> 24 matches gets byte 4 == 0: bit 1 / byte 4 == 7: bit 2 ORed into its byte +3; the host does not hold that list and stages the bits on ref <control>:records (backlog4 item9 LIKELY)",
	"opcode15_effect_request": "opcode 15 byte 4 <= 0x70 (0xB5C82 -> the 0xB56D8 slot table): the slot looks up the (byte 5, word +6) object through 0x5FBC8/0xA1864 and calls one of 0x101F74/0xFA640/0x10519C/0x1071D4/0xF9920/0xF7030/0x1012C4 (0xDD104 on the player object for 0x6C), whose effects (0xFB838/0xF8AAC/0xE3924) were not entered; the host emits effect_request(form, ref, lookup) and stores nothing (backlog4 item4 LIKELY)",
	"opcode18_pending_slot": "opcode 18 (0xB59CE, no byte-4 read): when the dword at 0xB7D5E is 0 the command pointer is stored there (host ref 0xb7d5e, field command_file_offset), a nonzero dword leaves it; the cell's start value and its reader (0xB2A54 via 0x65BB0) were not entered, so the host takes the cell as empty at start (backlog4 item4 LIKELY)",
	"opcode19_effect_record": "opcode 19 (0xB6B5F -> 0x66130): a cleared 0x36-byte record gets the object at +4, 0 at +8, 4 at +0x14, 0xFF at +0x15, command word +4 at +0, word +6 at +2 and at +0x16 byte 8 (byte 9 == 0) or the dispatcher object (byte 9 not 0/1/2), then goes to the object's vtable slot +0x80, which was not entered; the host emits effect_record_request and stores nothing; byte 9 == 1/2 (a vtable percentage) is refused (backlog4 item4 PROVEN record, LIKELY call)",
	"opcode208_cells": "opcode 208 byte 4 == 0 (0x65535): a nonzero byte 5 raises the dword at 0x26B4E to byte 6 * 60 << 16 and the byte at 0x26B52 to byte 5 when the stored values are lower; byte 5 == 0 clears both; the cells' start values and readers were not entered, so the host takes them as 0 at start (refs 0x26b4e / 0x26b52) (backlog4 item4 PROVEN arm, LIKELY cells)",
	"opcode13_actor_a8": "opcode 13 actor slots 0, 6, 7, 10 and 0x0D (and byte 4 above 0x16) are PROVEN stores skipped when actor byte +0xA8 is 0x0F; slot 0 writes command byte 5 at +0xA8 and +0xA9 and ORs 1 into +0xB8; the host takes +0xA8 as not 0x0F when not known (backlog4 item0, backlog6 item12)",
}
## The opcode-21 operand table (tools/prepare_movie_table.py); index -> name. Empty when the file is absent.
const MOVIE_TABLE := "res://scripts/lol2/movie_table.json"
## The opcode-12 operand table (tools/prepare_room_stems.py); index -> {stem, archive}. Empty when the file is absent.
const ROOM_STEMS := "res://scripts/lol2/room_stems.json"
## Load-time record patches (original-bug fixes applied to the loaded data, never to the archives): area -> rows
## {adapter, file_offset of the record, byte index, from, to}. Applied by load_area_data when the adapter is enabled at
## load time; applied_patches lists what was done. The archive file offset of the byte is file_offset + byte.
const RECORD_PATCHES := {
	"L7_DH": [{"adapter": "rix_fanfix_208_207", "file_offset": 4882701, "byte": 2, "from": 208, "to": 207}],
}
var applied_patches: Array[Dictionary] = []
const MODE_ROTARY := 6                   ## the only movable mode whose opcode-1 write is PROVEN
const TRAILER_KIND := 0x13
const UNKNOWN := -1                      ## a record byte whose written value is not stated

var area: String = ""
var source: Dictionary = {}
## "s<stream>:<group>" -> Array[Dictionary] of commands {opcode, kind, target, file_offset, bytes, raw_hex}
var groups: Dictionary = {}
## "s<stream>:<group>" -> group file offset
var group_files: Dictionary = {}
## object ref ("movable:57", "region:83", ...) -> Array[Dictionary] of records
## {kind, stream, group, file_offset, bytes, predicate (index or -1)}
var objects: Dictionary = {}
## predicate table entries (5 bytes each), header +0xBC / +0xB8
var predicates: Array[PackedByteArray] = []
## raw target address -> {field: int}
var state: Dictionary = {}
## opcode-198 array at [0x26E54]: index -> value (also predicate left type 3)
var locals: Dictionary = {}
## record file offset -> {"byte8": int, "byte9": int}: kind-9 record bytes the matcher rewrote
var record_state: Dictionary = {}
## second byte array at [0x26E58]: index -> value (predicate left type 2); only seeded values
var locals_e58: Dictionary = {}
## ref -> {"mode": int, "angle_word": int}; derived from movable placements, or set_target_attributes
var attributes: Dictionary = {}
## object ref -> placement bytes (from the export)
var placements: Dictionary = {}
## raw command address -> object ref (bind_target; also the adapter "slot_index_binding")
var bindings: Dictionary = {}
## object ref -> every record of its event list, in order: {file_offset, bytes} (opcode 14 walk)
var object_lists: Dictionary = {}
## host globals by native address (0x223D6 input; 0x223C8 / 0x223CC written by opcode 2)
var globals: Dictionary = {}
## adapter name -> enabled
var adapters_enabled: Dictionary = {}
## every group that ran on at least one adapter: {area, stream, group, adapters}
var adapter_log: Array[Dictionary] = []
## Every matched record whose group was not run: {area, object, event_kind, stream, group,
## group_file_offset, record_file_offset, reasons}
var unhosted: Array[Dictionary] = []

var _handlers: Dictionary = {}
var movie_table: Array = []
var room_stems: Array = []
## Results of events the opcode-9 arm 0x15 adapter enqueued and fired (bounded nesting).
var enqueued_results: Array[Dictionary] = []
var _enqueue_depth: int = 0
const ENQUEUE_DEPTH_LIMIT := 8
var _stage_state: Dictionary = {}
var _stage_locals: Dictionary = {}
var _stage_effects: Array[Dictionary] = []
var _stage_records: Dictionary = {}
var _stage_globals: Dictionary = {}
var _stage_adapters: Array[String] = []


func _init(with_builtins: bool = true) -> void:
	for name: String in ADAPTERS:
		adapters_enabled[name] = true
	load_movie_table()
	load_room_stems()
	if with_builtins:
		register_builtins()


## Loads the opcode-21 name table; returns the number of names (0 when the file is absent or invalid).
func load_movie_table(path: String = MOVIE_TABLE) -> int:
	movie_table = []
	if not FileAccess.file_exists(path):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not (data as Dictionary).get("entries") is Array:
		return 0
	for entry: Variant in (data as Dictionary)["entries"] as Array:
		movie_table.append(str((entry as Dictionary).get("name", "")))
	return movie_table.size()


func load_room_stems(path: String = ROOM_STEMS) -> int:
	room_stems = []
	if not FileAccess.file_exists(path):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not (data as Dictionary).get("entries") is Array:
		return 0
	for entry: Variant in (data as Dictionary)["entries"] as Array:
		room_stems.append({"stem": str((entry as Dictionary).get("stem", "")), "archive": str((entry as Dictionary).get("archive", ""))})
	return room_stems.size()


# --- loading -------------------------------------------------------------------------------------

## Loads an area file. Returns "" on success, otherwise the reason.
func load_area(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing " + path
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return "not a JSON object: " + path
	return load_area_data(parsed as Dictionary)


## Loads already-parsed area data (also used for synthetic test data). Clears all state.
func load_area_data(data: Dictionary) -> String:
	if str(data.get("format", "")) != FORMAT:
		return "unsupported format " + str(data.get("format", ""))
	area = str(data.get("area", ""))
	source = data.get("source", {}) as Dictionary
	groups.clear()
	group_files.clear()
	objects.clear()
	object_lists.clear()
	placements.clear()
	predicates.clear()
	state.clear()
	locals.clear()
	record_state.clear()
	unhosted.clear()
	adapter_log.clear()
	var table: Dictionary = data.get("predicate_table", {}) as Dictionary
	for raw_entry: Variant in table.get("entries", []) as Array:
		var entry: PackedByteArray = str(raw_entry).hex_decode()
		if entry.size() != 5:
			return "predicate entry is not 5 bytes"
		predicates.append(entry)
	for raw_group: Variant in data.get("groups", []) as Array:
		var g: Dictionary = raw_group as Dictionary
		var key: String = group_key(int(g["stream"]), int(g["group"]))
		var commands: Array[Dictionary] = []
		for raw_command: Variant in g["commands"] as Array:
			var c: Dictionary = raw_command as Dictionary
			var hex: String = str(c["raw_hex"])
			var bytes: PackedByteArray = hex.hex_decode()
			if bytes.size() < 4 or bytes[0] != int(c["opcode"]):
				return "command bytes do not match opcode at file %d" % int(c["file_offset"])
			commands.append({"opcode": int(c["opcode"]), "kind": int(c["kind"]), "target": int(c["target"]),
				"file_offset": int(c["file_offset"]), "bytes": bytes, "raw_hex": hex})
		groups[key] = commands
		group_files[key] = int(g["file_offset"])
	for raw_object: Variant in data.get("objects", []) as Array:
		var o: Dictionary = raw_object as Dictionary
		var records: Array[Dictionary] = []
		var listed: Array[Dictionary] = []
		for raw_event: Variant in o["events"] as Array:
			var e: Dictionary = raw_event as Dictionary
			listed.append({"file_offset": int(e.get("file_offset", -1)), "bytes": str(e["raw_hex"]).hex_decode()})
			if not e.has("group"):
				continue
			var key: String = group_key(int(e["stream"]), int(e["group"]))
			if not groups.has(key):
				return "%s names missing group %s" % [str(o["ref"]), key]
			var bytes: PackedByteArray = _patched_bytes(str(e["raw_hex"]).hex_decode(), int(e["file_offset"]), str(o["ref"]))
			if bytes.size() < 4 or bytes[1] != int(e["kind"]):
				return "record bytes do not match kind at file %d" % int(e["file_offset"])
			var predicate_index: int = -1
			var predicate: Variant = e.get("predicate", null)
			if predicate is Dictionary:
				var trailer: PackedByteArray = _patched_bytes(str((predicate as Dictionary)["trailer_hex"]).hex_decode(), int((predicate as Dictionary).get("trailer_file_offset", -1)), str(o["ref"]))
				if trailer.size() != 4 or trailer[1] != TRAILER_KIND:
					return "predicate trailer is not a kind-0x13 record at file %d" % int(e["file_offset"])
				predicate_index = trailer.decode_u16(2)
			records.append({"kind": int(e["kind"]), "stream": int(e["stream"]), "group": int(e["group"]),
				"file_offset": int(e["file_offset"]), "bytes": bytes, "predicate": predicate_index})
		objects[str(o["ref"])] = records
		object_lists[str(o["ref"])] = listed
		if o.has("placement_hex"):
			placements[str(o["ref"])] = str(o["placement_hex"]).hex_decode()
	bindings.clear()
	attributes.clear()
	reset_state()
	return ""


## Clears state, locals, the second array and rewritten record bytes, then seeds the PROVEN
## constructor values (G97 step 2b) for every movable and control placement:
## - 0xAE990 (from 0x5B634) stores 0 at +0x25 and copies placement byte +0x1E to +0x26;
##   0x5B634 stores 0 at +0x3D.
## - Movables (0x62FD4): placement byte +0x22 is the mode (object +0x53). On mode 6 the word at
##   +0x4E is 0x605F0(byte +0x24 * 2): remainder of idiv by 360, shifted left 16, idiv by 360.
##   Byte 60 gives 21845, the G95 percent-100 value, so the host uses it as the opcode-1 angle word. On other modes the word is the
##   zero-extended byte, kept but not used (opcode 1 is proven only on mode 6).
## Applies the area's enabled RECORD_PATCHES to one loaded record (by its archive file offset); logs what was done.
func _patched_bytes(bytes: PackedByteArray, file_offset: int, object_ref: String) -> PackedByteArray:
	for patch: Dictionary in RECORD_PATCHES.get(area, []) as Array:
		if int(patch["file_offset"]) != file_offset or not bool(adapters_enabled.get(str(patch["adapter"]), false)):
			continue
		var index: int = int(patch["byte"])
		if index >= bytes.size() or int(bytes[index]) != int(patch["from"]):
			continue
		bytes[index] = int(patch["to"])
		var row: Dictionary = {"area": area, "adapter": str(patch["adapter"]), "file_offset": file_offset + index, "from": int(patch["from"]), "to": int(patch["to"]), "object": object_ref}
		if not applied_patches.has(row):
			applied_patches.append(row)
	return bytes


func reset_state() -> void:
	state.clear()
	locals.clear()
	locals_e58.clear()
	record_state.clear()
	globals.clear()
	for ref: String in placements:
		var p: PackedByteArray = placements[ref] as PackedByteArray
		var is_movable: bool = ref.begins_with("movable:") and p.size() >= 41
		var is_control: bool = ref.begins_with("control:") and p.size() >= 33
		if ref.begins_with("actor:"):
			# The actor constructor's 0xAE990 stores 0 at +0x25 (backlog 4 item 3 PROVEN, c6432500).
			state[ref] = {FIELD_BYTE25: 0}
			continue
		if not (is_movable or is_control):
			continue
		state[ref] = {FIELD_BYTE25: 0, FIELD_SELECTOR: 0, FIELD_BYTE26: int(p[0x1E])}
		if is_movable:
			var mode: int = int(p[0x22])
			var word: int = int(p[0x24])
			if mode == MODE_ROTARY:
				word = ((int(p[0x24]) * 2 % 360) << 16) / 360
			if not attributes.has(ref):
				attributes[ref] = {"mode": mode, "angle_word": word & 0xFFFF}


static func group_key(stream: int, group: int) -> String:
	return "s%d:%d" % [stream, group]


## Raw command target address, for example "0x20:57".
static func target_ref(kind: int, target: int) -> String:
	return "0x%02x:%d" % [kind, target]


# --- registry and world-side inputs --------------------------------------------------------------

## handler: func(host: Object, command: Dictionary) -> String. Return "" when the command was staged,
## otherwise the reason it cannot be hosted. Handlers must write only through stage_* below.
func register_opcode(opcode: int, handler: Callable) -> void:
	_handlers[opcode] = handler


func unregister_opcode(opcode: int) -> void:
	_handlers.erase(opcode)


func has_handler(opcode: int) -> bool:
	return _handlers.has(opcode)


func register_builtins() -> void:
	for opcode: int in [1, 3, 13]:
		register_opcode(opcode, _op_slot_ac)
	register_opcode(2, _op_two)
	register_opcode(5, _op_selector)
	register_opcode(6, _op_six)
	register_opcode(7, _op_seven)
	register_opcode(8, _op_eight)
	register_opcode(9, _op_nine)
	register_opcode(14, _op_fourteen)
	register_opcode(12, _op_twelve)
	register_opcode(15, _op_fifteen)
	register_opcode(210, _op_two_one_zero)
	register_opcode(18, _op_eighteen)
	register_opcode(19, _op_nineteen)
	register_opcode(208, _op_two_oh_eight)
	register_opcode(16, _op_byte25)
	register_opcode(20, _op_sound)
	register_opcode(21, _op_movie)
	register_opcode(197, _op_one_nine_seven)
	register_opcode(198, _op_local)
	register_opcode(204, _op_two_oh_four)


## Adapters: a named workaround that rests on a LIKELY reading (never PROVEN). register_adapter adds
## a caller-defined one; handlers ask use_adapter(name) during staging.
func register_adapter(name: String, enabled: bool = true) -> void:
	adapters_enabled[name] = enabled


func set_adapter_enabled(name: String, enabled: bool) -> void:
	adapters_enabled[name] = enabled


func set_adapters_enabled(enabled: bool) -> void:
	for name: String in adapters_enabled:
		adapters_enabled[name] = enabled


## True when the adapter is enabled; the running group (or matched record) then records its use.
func use_adapter(name: String) -> bool:
	if not bool(adapters_enabled.get(name, false)):
		return false
	if not _stage_adapters.has(name):
		_stage_adapters.append(name)
	return true


## Override of the mode and angle word of a ref (movables get theirs from the placement at load;
## this is for synthetic data and for refs without a placement).
func set_target_attributes(ref: String, mode: int, angle_word: int) -> void:
	attributes[ref] = {"mode": mode, "angle_word": angle_word}


## World side: treat the raw command address (for example "0x20:57") as the object ref (for example
## "movable:57"). This is the adapter "slot_index_binding" (slot N as placement record N is LIKELY);
## the host applies it by itself for kinds 0x10/0x20/3/2 when that placement exists and the adapter
## is enabled, so explicit binds are only needed for other refs.
func bind_target(raw_ref: String, object_ref: String) -> void:
	bindings[raw_ref] = object_ref


## The state key of a ref, without recording adapter use (for callers outside a group run).
func resolve(ref: String) -> String:
	var bound: String = _binding(ref)
	return ref if bound == "" or not bool(adapters_enabled.get("slot_index_binding", false)) else bound


func _binding(ref: String) -> String:
	if bindings.has(ref):
		return str(bindings[ref])
	if not ref.begins_with("0x"):
		return ""
	var kind: int = ref.get_slice(":", 0).hex_to_int()
	if not TABLE_BY_KIND.has(kind):
		return ""
	var candidate: String = "%s:%s" % [str(TABLE_BY_KIND[kind]), ref.get_slice(":", 1)]
	return candidate if placements.has(candidate) else ""


## Inside a group run: resolves through the binding adapter and records its use.
func _resolve_staged(ref: String) -> String:
	var bound: String = _binding(ref)
	if bound != "" and use_adapter("slot_index_binding"):
		return bound
	return ref


## World side: a known value of a host global (for example 0x223D6 for opcode 2).
func set_global(address: int, value: int) -> void:
	globals[address] = value


## World side: a known value of the second byte array at [0x26E58] (predicate left type 2). Nothing
## PROVEN writes it, so it is unknown unless seeded.
func set_local_e58(index: int, value: int) -> void:
	locals_e58[index] = value


## World side: a known starting value of an object field (initial values are not in the export).
func set_field(ref: String, name: String, value: int) -> void:
	if not state.has(ref):
		state[ref] = {}
	(state[ref] as Dictionary)[name] = value


## World side: a known starting value of the opcode-198 array.
func set_local(index: int, value: int) -> void:
	locals[index] = value


func field(ref: String, name: String, fallback: int = -1) -> int:
	var fields: Dictionary = state.get(ref, {}) as Dictionary
	return int(fields.get(name, fallback))


## Current record byte (8 or 9 may have been rewritten by the kind-9 matcher; UNKNOWN is -1).
func record_byte(record: Dictionary, offset: int) -> int:
	var rewritten: Dictionary = record_state.get(int(record["file_offset"]), {}) as Dictionary
	var key: String = "byte%d" % offset
	if rewritten.has(key):
		return int(rewritten[key])
	return int((record["bytes"] as PackedByteArray)[offset])


# --- staging API for handlers --------------------------------------------------------------------

func stage_read(ref: String, name: String, fallback: int = -1) -> int:
	var fields: Dictionary = _stage_state.get(ref, {}) as Dictionary
	return int(fields.get(name, fallback))


func stage_write(ref: String, name: String, value: int) -> void:
	if not _stage_state.has(ref):
		_stage_state[ref] = {}
	(_stage_state[ref] as Dictionary)[name] = value
	_stage_effects.append({"type": "field", "ref": ref, "field": name, "value": value})


func stage_local(index: int, value: int) -> void:
	_stage_locals[index] = value
	_stage_effects.append({"type": "local", "index": index, "value": value})


func stage_sound(request: int) -> void:
	_stage_effects.append({"type": "sound", "request": request})


# --- events --------------------------------------------------------------------------------------

## Fires an event on an object ("movable:57", "control:1015", "region:83").
## Objects: every record whose kind byte == event_kind is matched. Regions: every kind-12 record of
## that region whose byte +6 == event_kind. Returns one result per such record:
## {stream, group, group_file_offset, record_file_offset, status "ran"|"rejected"|"unhosted", reasons}.
func fire_event(object_ref: String, event_kind: int, input: Dictionary = {}) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var accepted: Array[Dictionary] = []
	var is_region: bool = object_ref.begins_with("region:")
	var region_index: int = int(object_ref.get_slice(":", 1)) if is_region else -1
	for raw_record: Variant in objects.get(object_ref, []) as Array:
		var record: Dictionary = raw_record as Dictionary
		var bytes: PackedByteArray = record["bytes"] as PackedByteArray
		if is_region:
			if int(record["kind"]) != 12 or bytes.size() < 8 or bytes.decode_u16(4) != region_index or int(bytes[6]) != event_kind:
				continue
		elif int(record["kind"]) != event_kind:
			continue
		var result: Dictionary = {"stream": int(record["stream"]), "group": int(record["group"]),
			"group_file_offset": int(group_files.get(group_key(int(record["stream"]), int(record["group"])), -1)),
			"record_file_offset": int(record["file_offset"])}
		# 0xAE2C8 (kind 9; backlog 4 item 3 PROVEN, 837c2404000f85f8010000): a nonzero success count leaves before the next
		# record is tested, so one hit enqueues at most one kind-9 record; the later records are reported as not_reached.
		if event_kind == 9 and not accepted.is_empty():
			var later: Dictionary = result.duplicate()
			later["status"] = "not_reached"
			later["reasons"] = ["0xAE2C8 leaves after an earlier kind-9 record was enqueued (success count nonzero)"] as Array[String]
			results.append(later)
			continue
		var effective: Dictionary = input
		var gate_adapters: Array[String] = []
		# G97 step 2b / step4_vtables: for movables and controls 0xB5000 returns before the kind-4 walk
		# when object byte +0x15 bit 0x80 is set, then calls vtable+0xB8 = 0xB71A0 on the same object,
		# which stores it in 0xB7D80 when byte +0x15 bit 0x10 is clear. Known bits decide; unknown bits
		# use the adapters "b5000_bit_clear" / "b71a0_bit_clear". An explicit input "context" overrides.
		if int(record["kind"]) == 4 and (object_ref.begins_with("movable:") or object_ref.begins_with("control:")):
			var b80: int = field(object_ref, _bit_name(0x15, 0x80), UNKNOWN)
			if b80 == 1:
				var skipped: Dictionary = result.duplicate()
				skipped["status"] = "rejected"
				skipped["reasons"] = ["0xB5000 skips the walk (+0x15 bit 0x80 set)"] as Array[String]
				results.append(skipped)
				continue
			if b80 == UNKNOWN:
				if not bool(adapters_enabled.get("b5000_bit_clear", false)):
					var blocked: Dictionary = result.duplicate()
					blocked["status"] = "unhosted"
					blocked["reasons"] = ["+0x15 bit 0x80 is not known (0xB5000 walk)"] as Array[String]
					_log_unhosted(object_ref, event_kind, blocked)
					results.append(blocked)
					continue
				gate_adapters.append("b5000_bit_clear")
			if not input.has("context"):
				var b10: int = field(object_ref, _bit_name(0x15, 0x10), UNKNOWN)
				if b10 == 0 or (b10 == UNKNOWN and bool(adapters_enabled.get("b71a0_bit_clear", false))):
					effective = input.duplicate()
					effective["context"] = object_ref
					if b10 == UNKNOWN:
						gate_adapters.append("b71a0_bit_clear")
		# Kind 2 (timers): the expiry walk was not entered; the matcher below reads byte +5 bit 0 on the adapter kind2_timer_expiry.
		if int(record["kind"]) == 2:
			if not bool(adapters_enabled.get("kind2_timer_expiry", false)):
				var blocked2: Dictionary = result.duplicate()
				blocked2["status"] = "unhosted"
				blocked2["reasons"] = ["kind 2 expiry walk not entered (adapter kind2_timer_expiry off)"] as Array[String]
				_log_unhosted(object_ref, event_kind, blocked2)
				results.append(blocked2)
				continue
			gate_adapters.append("kind2_timer_expiry")
		var verdict: Dictionary = _match_region(record, event_kind) if is_region else _match_object(record, effective)
		if str(verdict["status"]) == "match" and int(record["predicate"]) >= 0:
			verdict = _evaluate_predicate(int(record["predicate"]), effective, verdict)
		for write: Variant in verdict.get("now", []) as Array:
			_record_write(record, write as Dictionary)
		result["status"] = "accepted" if str(verdict["status"]) == "match" else str(verdict["status"])
		var reasons: Array[String] = []
		if str(verdict.get("reason", "")) != "":
			reasons.append(str(verdict["reason"]))
		result["reasons"] = reasons
		if str(result["status"]) == "unhosted":
			_log_unhosted(object_ref, event_kind, result)
		elif str(result["status"]) == "accepted":
			accepted.append({"record": record, "result": result, "after": verdict.get("after", []), "adapters": gate_adapters})
		results.append(result)
	for row: Dictionary in accepted:
		var result: Dictionary = row["result"] as Dictionary
		var empty: Array[String] = []
		var gates: Array[String] = []
		for name: Variant in row["adapters"] as Array:
			gates.append(str(name))
		var ran: Dictionary = _run(int(result["stream"]), int(result["group"]), empty, gates)
		result["status"] = ran["status"]
		result["reasons"] = ran["reasons"]
		if ran.has("effects"):
			result["effects"] = ran["effects"]
		result["adapters"] = ran.get("adapters", [])
		if str(ran["status"]) == "ran":
			for write: Variant in row["after"] as Array:
				_record_write(row["record"] as Dictionary, write as Dictionary)
		else:
			_log_unhosted(object_ref, event_kind, result)
	return results


## Runs one group with no owner record (for a group reached another way). No matcher applies.
func execute_group(stream: int, group: int) -> Dictionary:
	var empty: Array[String] = []
	var result: Dictionary = _run(stream, group, empty)
	result["record_file_offset"] = -1
	if str(result["status"]) == "unhosted":
		_log_unhosted("", -1, result)
	return result


func object_records(object_ref: String) -> Array:
	return objects.get(object_ref, []) as Array


func group_opcodes(stream: int, group: int) -> Array[int]:
	var out: Array[int] = []
	for raw_command: Variant in groups.get(group_key(stream, group), []) as Array:
		out.append(int((raw_command as Dictionary)["opcode"]))
	return out


# --- matchers (G97 step 2, PROVEN paths only) ----------------------------------------------------

static func _verdict(status: String, reason: String = "") -> Dictionary:
	return {"status": status, "reason": reason}


## Returns "" and stores the value in out["v"], or the reason the input is missing.
static func _need(input: Dictionary, key: String, low: int, high: int, out: Dictionary) -> String:
	if not input.has(key):
		return "input %s not supplied" % key
	var value: Variant = input[key]
	if not (value is int) or int(value) < low or int(value) > high:
		return "input %s must be an int in %d..%d" % [key, low, high]
	out["v"] = int(value)
	return ""


func _match_object(record: Dictionary, input: Dictionary) -> Dictionary:
	var bytes: PackedByteArray = record["bytes"] as PackedByteArray
	var kind: int = int(record["kind"])
	var got: Dictionary = {}
	var missing: String = ""
	match kind:
		2:
			# Timer record (backlog 5 item 9, adapter kind2_timer_expiry): byte +5 bit 0 set = stopped (opcode 14 arm 4 / the data);
			# clear = started by arm 3 or auto-kept by the load scan 0xAEC74. The count word +8 is the world side's clock.
			var byte5: int = record_byte(record, 5)
			if byte5 == UNKNOWN:
				return _verdict("unhosted", "kind 2 byte +5 was written back with a value that is not stated")
			if (byte5 & 0x01) != 0:
				return _verdict("rejected", "kind 2 record stopped (byte +5 bit 0 set)")
			return _verdict("match")
		5:
			# 0xE4910/0xE4915: byte +4 == caller byte; 0xE4923..0xE493A: byte +5 == second caller byte
			# unless either is 0xFF.
			missing = _need(input, "caller_byte", 0, 255, got)
			if missing != "":
				return _verdict("unhosted", missing)
			if int(bytes[4]) != int(got["v"]):
				return _verdict("rejected", "kind 5 byte +4 %d != caller_byte" % int(bytes[4]))
			if int(bytes[5]) == 0xFF:
				return _verdict("match")
			missing = _need(input, "caller_byte_2", 0, 255, got)
			if missing != "":
				return _verdict("unhosted", missing)
			if int(got["v"]) != 0xFF and int(bytes[5]) != int(got["v"]):
				return _verdict("rejected", "kind 5 byte +5 %d != caller_byte_2" % int(bytes[5]))
			return _verdict("match")
		6:
			# 0xE4E06/0xE4E0F: byte +4 == caller byte.
			missing = _need(input, "caller_byte", 0, 255, got)
			if missing != "":
				return _verdict("unhosted", missing)
			if int(bytes[4]) != int(got["v"]):
				return _verdict("rejected", "kind 6 byte +4 %d != caller_byte" % int(bytes[4]))
			return _verdict("match")
		8:
			# 0xE553B..0xE554B: u16 at +4 == arg, or the record word is 0xFFFF.
			var word: int = bytes.decode_u16(4)
			if word == 0xFFFF:
				return _verdict("match")
			missing = _need(input, "arg", 0, 0xFFFF, got)
			if missing != "":
				return _verdict("unhosted", missing)
			if word != int(got["v"]):
				return _verdict("rejected", "kind 8 word +4 %d != arg" % word)
			return _verdict("match")
		4:
			# Byte +4 is a mode index 0..7. Mode 0 (fixup VA 0xADC41): accept exactly when the walker's
			# argument dword at +0xC (arg_c) is 0; byte +5 == 0 means no inversion (0xE4C47).
			if int(bytes[4]) == 3:
				# Mode 3 (0xADC84..0xADC8F, backlog 6 item 1d PROVEN): the walker's second argument +0xC points to an object; a 0
				# pointer rejects, else the dword at that object +0x18 must equal the record dword +6 (the item identity the
				# opcode-3 give-item commands carry); byte +5 nonzero inverts (0xE4C47). Input arg_object_identity = that dword
				# +0x18, or 0 for a null pointer. What the second argument is natively stays UNKNOWN (the hosts supply it).
				if bytes.size() < 10:
					return _verdict("unhosted", "kind 4 mode 3 record shorter than 10 bytes")
				missing = _need(input, "arg_object_identity", 0, 4294967295, got)
				if missing != "":
					return _verdict("unhosted", missing)
				var equal: bool = int(got["v"]) != 0 and int(got["v"]) == bytes.decode_u32(6)
				if int(bytes[5]) != 0:
					equal = not equal
				if not equal:
					return _verdict("rejected", "kind 4 mode 3: the argument object's +0x18 %d is not the record's %d" % [int(got["v"]), bytes.decode_u32(6)])
				return _verdict("match")
			if int(bytes[4]) == 1:
				# Mode 1 (0xADC76, re-sliced): mov al, [esp]; jmp 0xADC47. [esp] is the setne of the
				# walker's EAX at 0xADC08, which is 1 when the second-argument dword at +0xC is not 0.
				# Byte +5 inverts at 0xADC47, the same test mode 0 uses. The dword stays unnamed.
				missing = _need(input, "arg_c", -2147483648, 4294967295, got)
				if missing != "":
					return _verdict("unhosted", missing)
				var accept: bool = int(got["v"]) != 0
				if int(bytes[5]) != 0:
					accept = not accept
				if not accept:
					if int(bytes[5]) != 0:
						return _verdict("rejected", "kind 4 mode 1 with byte +5 set needs arg_c 0")
					return _verdict("rejected", "kind 4 mode 1 needs a nonzero arg_c")
				return _verdict("match")
			if int(bytes[4]) != 0:
				return _verdict("unhosted", "kind 4 mode %d is not decoded" % int(bytes[4]))
			if int(bytes[5]) != 0:
				return _verdict("unhosted", "kind 4 byte +5 %d (inversion) is not decoded" % int(bytes[5]))
			missing = _need(input, "arg_c", -2147483648, 4294967295, got)
			if missing != "":
				return _verdict("unhosted", missing)
			if int(got["v"]) != 0:
				return _verdict("rejected", "kind 4 mode 0 needs arg_c 0")
			return _verdict("match")
		9:
			return _match_kind9(record, input)
	return _verdict("unhosted", "matcher for record kind %d was not entered" % kind)


## Kind 9 (0xAE2C8): masks, then mode = byte +9 & 7.
func _match_kind9(record: Dictionary, input: Dictionary) -> Dictionary:
	var bytes: PackedByteArray = record["bytes"] as PackedByteArray
	if bytes.size() < 10:
		return _verdict("unhosted", "kind 9 record shorter than 10 bytes")
	var got: Dictionary = {}
	var missing: String = ""
	var mask0: int = bytes.decode_u16(4)
	var mask2: int = bytes.decode_u16(6)
	if mask0 != 0:
		missing = _need(input, "word0", 0, 0xFFFF, got)
		if missing != "":
			return _verdict("unhosted", missing)
		if (mask0 & int(got["v"])) == 0:
			return _verdict("rejected", "kind 9 mask +4 0x%04x shares no bit with word0" % mask0)
	if mask2 != 0:
		missing = _need(input, "word2", 0, 0xFFFF, got)
		if missing != "":
			return _verdict("unhosted", missing)
		if (mask2 & int(got["v"])) == 0:
			return _verdict("rejected", "kind 9 mask +6 0x%04x shares no bit with word2" % mask2)
	var byte9: int = record_byte(record, 9)
	var byte8: int = record_byte(record, 8)
	var mode: int = byte9 & 7
	if mode == 0:
		# Slot 0 of the mode table does not set the admit flag (backlog 4 item 3): a record whose byte +9 was cleared after
		# its enqueue (bit 7) admits nothing again.
		return _verdict("rejected", "kind 9 mode 0 (byte +9 cleared after an enqueue) admits nothing")
	if mode > 4:
		return _verdict("rejected", "kind 9 mode %d > 4" % mode)
	var verdict: Dictionary
	if mode == 4:
		# 0xE53BD/0xE53C0: reject when zero-extended byte +8 < input dword +0x26 (signed).
		if byte8 == UNKNOWN:
			return _verdict("unhosted", "kind 9 byte +8 was written back with a value that is not stated")
		missing = _need(input, "dword_26", -2147483648, 2147483647, got)
		if missing != "":
			return _verdict("unhosted", missing)
		if byte8 < int(got["v"]):
			return _verdict("rejected", "kind 9 mode 4 byte +8 %d < dword_26" % byte8)
		# 0xE542A: when the signed byte at 0x23331 is 5, byte +9 becomes 0 and nothing is enqueued.
		missing = _need(input, "global_23331", -128, 255, got)
		if missing != "":
			return _verdict("unhosted", missing)
		var global_byte: int = int(got["v"]) - 256 if int(got["v"]) > 127 else int(got["v"])
		if global_byte == 5:
			verdict = _verdict("rejected", "kind 9 mode 4 with global 0x23331 == 5")
			verdict["now"] = [{"field": "byte9", "value": 0}]
			return verdict
	elif mode == 1:
		# Reject when byte +8 > input dword +0x1E (signed). The extension of byte +8 is not stated,
		# so only 0..0x7F (where both agree) is taken.
		if byte8 == UNKNOWN or byte8 > 0x7F:
			return _verdict("unhosted", "kind 9 mode 1 byte +8 %d: extension not stated" % byte8)
		missing = _need(input, "dword_1e", -2147483648, 2147483647, got)
		if missing != "":
			return _verdict("unhosted", missing)
		if byte8 > int(got["v"]):
			return _verdict("rejected", "kind 9 mode 1 byte +8 %d > dword_1e" % byte8)
	else:
		return _verdict("unhosted", "kind 9 mode %d is not decoded" % mode)
	verdict = _verdict("match")
	# 0xE54D3/0xE54D7: after an enqueue, bit 7 of byte +9 clears byte +9 and byte +8 is written back
	# from a local whose value is not stated.
	if (byte9 & 0x80) != 0:
		verdict["after"] = [{"field": "byte9", "value": 0}, {"field": "byte8", "value": UNKNOWN}]
	return verdict


## Region kind 12 (0x129D94..0x129DA8): u16 +4 == region index and byte +6 == event are the
## selection above. Event 2 (fixup VA 0xF2DFD) accepts when byte +7 == 0; other events are not entered.
func _match_region(record: Dictionary, event_kind: int) -> Dictionary:
	var bytes: PackedByteArray = record["bytes"] as PackedByteArray
	if event_kind != 2:
		return _verdict("unhosted", "region event slot %d was not entered" % event_kind)
	if int(bytes[7]) != 0:
		return _verdict("rejected", "region event 2 byte +7 %d != 0" % int(bytes[7]))
	return _verdict("match")


# --- predicate evaluator (G97 step 1, 0x66AB0, PROVEN paths only) --------------------------------

## Entry bytes: byte0 operator, byte1 left type, byte2 operand, byte3 right type, byte4 literal.
## Operators: 0 = equality (VA 0x66C43); 5 = signed EBX < ESI (VA 0x66CA3, setl); 6 = 1 when EBX and
## ESI are both nonzero (VA 0x66C10). Right type 0 = literal byte 4 (VA 0x66B77). Left types: 5 =
## byte +0x25 of the object in 0xB7D80 (VA 0x66B3B; input "context"); 3 = byte at [0x26E54 + operand]
## (VA 0x66B15; the opcode-198 array); 2 = byte at [0x26E58 + operand] (VA 0x66B2A; locals_e58).
## Left and right type 4 and every other path stay unhosted.
func _evaluate_predicate(index: int, input: Dictionary, matched: Dictionary) -> Dictionary:
	if index >= predicates.size():
		return _verdict("unhosted", "predicate %d is outside the %d-entry table" % [index, predicates.size()])
	var entry: PackedByteArray = predicates[index]
	var label: String = "predicate %d (%s)" % [index, entry.hex_encode()]
	var op: int = int(entry[0])
	if op != 0 and op != 5 and op != 6:
		return _verdict("unhosted", "%s operator %d is not decoded" % [label, op])
	if int(entry[3]) != 0:
		return _verdict("unhosted", "%s right type %d is not decoded" % [label, int(entry[3])])
	var right: int = int(entry[4])
	var left: int = -1
	match int(entry[1]):
		5:
			if not input.has("context") or not (input["context"] is String):
				return _verdict("unhosted", "%s reads the 0xB7D80 object; input context not supplied" % label)
			var ref: String = resolve(str(input["context"]))
			var fields: Dictionary = state.get(ref, {}) as Dictionary
			if not fields.has(FIELD_BYTE25):
				return _verdict("unhosted", "%s reads %s +0x25, which is not known" % [label, ref])
			left = int(fields[FIELD_BYTE25])
		3:
			if not locals.has(int(entry[2])):
				return _verdict("unhosted", "%s reads local %d, which is not known" % [label, int(entry[2])])
			left = int(locals[int(entry[2])])
		2:
			if not locals_e58.has(int(entry[2])):
				return _verdict("unhosted", "%s reads [0x26E58 + %d], which is not known" % [label, int(entry[2])])
			left = int(locals_e58[int(entry[2])])
		_:
			return _verdict("unhosted", "%s left type %d is not decoded" % [label, int(entry[1])])
	var truth: bool = false
	match op:
		0:
			truth = left == right
		5:
			truth = left < right
		6:
			truth = left != 0 and right != 0
	if not truth:
		return _verdict("rejected", "%s is false (left %d, operator %d, right %d)" % [label, left, op, right])
	return matched


func _record_write(record: Dictionary, write: Dictionary) -> void:
	var offset: int = int(record["file_offset"])
	if not record_state.has(offset):
		record_state[offset] = {}
	(record_state[offset] as Dictionary)[str(write["field"])] = int(write["value"])
	record_state_changed.emit(offset, str(write["field"]), int(write["value"]))


# --- running -------------------------------------------------------------------------------------

func _run(stream: int, group: int, gate_reasons: Array[String], gate_adapters: Array[String] = []) -> Dictionary:
	var key: String = group_key(stream, group)
	var reasons: Array[String] = []
	reasons.append_array(gate_reasons)
	var result: Dictionary = {"stream": stream, "group": group, "group_file_offset": int(group_files.get(key, -1))}
	if not groups.has(key):
		reasons.append("group %s is not in area %s" % [key, area])
		result["status"] = "unhosted"
		result["reasons"] = reasons
		return result
	var commands: Array = groups[key] as Array
	for raw_command: Variant in commands:
		var opcode: int = int((raw_command as Dictionary)["opcode"])
		if not _handlers.has(opcode):
			var missing: String = "opcode %d has no handler" % opcode
			if not reasons.has(missing):
				reasons.append(missing)
	if reasons.is_empty():
		_stage_state = state.duplicate(true)
		_stage_locals = locals.duplicate()
		_stage_records = record_state.duplicate(true)
		_stage_globals = globals.duplicate()
		_stage_effects = []
		_stage_adapters = []
		for name: String in gate_adapters:
			if not _stage_adapters.has(name):
				_stage_adapters.append(name)
		for raw_command: Variant in commands:
			var command: Dictionary = raw_command as Dictionary
			var handler: Callable = _handlers[int(command["opcode"])] as Callable
			var refusal: String = str(handler.call(self, command))
			if refusal != "":
				reasons.append("opcode %d at file %d: %s" % [int(command["opcode"]), int(command["file_offset"]), refusal])
				break
	if not reasons.is_empty():
		_clear_stage()
		result["status"] = "unhosted"
		result["reasons"] = reasons
		return result
	state = _stage_state
	locals = _stage_locals
	record_state = _stage_records
	globals = _stage_globals
	var effects: Array[Dictionary] = _stage_effects
	var used: Array[String] = _stage_adapters
	_clear_stage()
	for effect: Dictionary in effects:
		match str(effect["type"]):
			"field":
				object_state_changed.emit(str(effect["ref"]), str(effect["field"]), int(effect["value"]))
			"local":
				local_changed.emit(int(effect["index"]), int(effect["value"]))
			"sound":
				sound_request.emit(int(effect["request"]))
			"record":
				record_state_changed.emit(int(effect["record"]), str(effect["field"]), int(effect["value"]))
			"global":
				global_changed.emit(int(effect["address"]), int(effect["value"]))
			"movie":
				movie_request.emit(int(effect["index"]), str(effect["name"]), int(effect["byte5"]))
			"effect":
				effect_request.emit(int(effect["form"]), str(effect["ref"]), str(effect["lookup"]))
			"effect_record":
				effect_record_request.emit(str(effect["ref"]), int(effect["word0"]), int(effect["word2"]), int(effect["value"]), int(effect["byte9"]))
			"item":
				item_request.emit(str(effect["ref"]), int(effect["identity"]), int(effect["arg"]))
			"room":
				room_request.emit(int(effect["index"]), str(effect["stem"]), str(effect["archive"]))
			"enqueue":
				event_enqueued.emit(str(effect["ref"]), int(effect["event_kind"]), int(effect["caller_byte"]))
				if _enqueue_depth < ENQUEUE_DEPTH_LIMIT:
					_enqueue_depth += 1
					for nested: Dictionary in fire_event(str(effect["ref"]), int(effect["event_kind"]), {"caller_byte": int(effect["caller_byte"]), "context": str(effect["ref"])}):
						enqueued_results.append(nested)
					_enqueue_depth -= 1
	result["status"] = "ran"
	result["reasons"] = reasons
	result["effects"] = effects
	result["adapters"] = used
	if not used.is_empty():
		adapter_log.append({"area": area, "stream": stream, "group": group, "adapters": used.duplicate()})
	return result


func _clear_stage() -> void:
	_stage_state = {}
	_stage_locals = {}
	_stage_records = {}
	_stage_globals = {}
	_stage_effects = []
	_stage_adapters = []


func _log_unhosted(object_ref: String, event_kind: int, result: Dictionary) -> void:
	unhosted.append({"area": area, "object": object_ref, "event_kind": event_kind,
		"stream": int(result["stream"]), "group": int(result["group"]),
		"group_file_offset": int(result["group_file_offset"]),
		"record_file_offset": int(result["record_file_offset"]), "reasons": result["reasons"]})


# --- handler helpers ------------------------------------------------------------------------------

## The object class behind a command kind byte (G97 step_opcode5: the resolver cell of each byte is
## filled by one constructor, which installs one vtable). "" for a byte whose class is not PROVEN.
static func class_of_kind(kind: int) -> String:
	return str(CLASS_BY_KIND.get(kind, ""))


## Resolves the command's target to the state key, "" with out["reason"] when the kind byte selects
## no object (0x5FBC8 returns 0 for those bytes).
func _target(command: Dictionary, out: Dictionary) -> String:
	var kind: int = int(command["kind"])
	if not OBJECT_KINDS.has(kind):
		out["reason"] = "kind byte 0x%02x selects no object (0x5FBC8 returns 0)" % kind
		return ""
	return _resolve_staged(target_ref(kind, int(command["target"])))


static func _bit_name(offset: int, bit: int) -> String:
	return "bit_0x%02x_0x%02x" % [offset, bit]


## 1, 0, or UNKNOWN for one bit of an object byte, from the staged state.
func _stage_bit(ref: String, offset: int, bit: int) -> int:
	return stage_read(ref, _bit_name(offset, bit), UNKNOWN)


## 1 or 0 when placement word +8 has `mask` set. UNKNOWN when this object has no placement.
## 0xAE990 copies that word into the low half of object dword +0x14 (668b4208 894314).
func _placement_word_bit(ref: String, mask: int) -> int:
	if not placements.has(ref):
		return UNKNOWN
	var placed: PackedByteArray = placements[ref] as PackedByteArray
	if placed.size() < 10:
		return UNKNOWN
	return 1 if (placed.decode_u16(8) & mask) != 0 else 0


## ORs (value 1) or clears (value 0) every bit of mask in an object byte; each bit is its own field.
func _stage_bits(ref: String, offset: int, mask: int, value: int) -> void:
	for i in 8:
		var bit: int = 1 << i
		if (mask & bit) != 0:
			stage_write(ref, _bit_name(offset, bit), value)


func stage_record_byte(record_offset: int, byte_offset: int, value: int) -> void:
	if not _stage_records.has(record_offset):
		_stage_records[record_offset] = {}
	(_stage_records[record_offset] as Dictionary)["byte%d" % byte_offset] = value
	_stage_effects.append({"type": "record", "record": record_offset, "field": "byte%d" % byte_offset, "value": value})


func stage_global(address: int, value: int) -> void:
	_stage_globals[address] = value
	_stage_effects.append({"type": "global", "address": address, "value": value})


# --- built-in handlers -----------------------------------------------------------------------------
# PROVEN arms only, unless a handler calls use_adapter(name); then that arm is an adapter (G97 LIKELY
# reading, docs/DEVIATIONS.md) and the group result lists it. Sources: G95 HOST_CONTRACT and the G97
# step3/step3b/step4/step_opcode5 reports under AI_COMMS/grok_backlog_20261028/G97_opcode_table.

## Opcodes 1, 3, 13 share slot 0xB5937: [vtable+0xAC](object, command).
## Movable 0x63DAC: byte0 1 on mode 6 writes (angle word +0x4E * byte 4) / 100 into the low word at
## +0x50 (0fafc2 b964000000 31d2 f7f1 66894350). Other movable modes are refused. The later motion
## branches (+0x55 states) are not modelled; the world side animates (docs/DEVIATIONS.md).
## Byte0 other than 1/9 goes to control 0x5D904, which returns 1 without a store unless byte0 is 8.
## Control 0x5D904 and prop 0xF22B4 return 1 without a store for byte0 other than 8. Actor 0xA62F4:
## byte0 1 is out of its table (no store); byte0 3 and 13 enter UNKNOWN callees.
func _op_slot_ac(_host: Object, command: Dictionary) -> String:
	var opcode: int = int(command["opcode"])
	if opcode == 3 and int(command["kind"]) == 1:
		return _op_three_item(command)
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var cls: String = class_of_kind(int(command["kind"]))
	match cls:
		"movable":
			if opcode != 1:
				return ""
			return _travel_word(ref, command)
		"control", "prop":
			return ""
		"actor":
			if opcode == 1:
				return ""
			if opcode == 13:
				return _op_thirteen_actor(ref, command)
			return "actor slot +0xAC for byte0 %d enters an UNKNOWN callee" % opcode
	return "slot +0xAC of the kind-0x%02x class was not entered" % int(command["kind"])


## Opcode 13 on an actor (backlog 4 item 0 and backlog 6 item 12, PROVEN stores behind an unread gate): slot 0xA6348
## returns 1 without a store when actor byte +0xA8 is 0x0F. Otherwise the 0xA626C slot runs and 0xA6388 stores 0 at
## word +0x7C. Slot 0 (0xA6365) stores command byte 5 at +0xA8 and +0xA9 and ORs 1 into byte +0xB8. Slot 6 sets bit 0
## of +0xB5, slot 7 clears it, slot 10 clears bits 2/3, slot 0x0D sets bits 2/3, and byte 4 above 0x16 stores only the
## word. The other slots of the table were not entered. +0xA8 unknown: adapter opcode13_actor_a8.
func _op_thirteen_actor(ref: String, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var b4: int = int(bytes[4])
	if not (b4 in [0, 6, 7, 10, 0x0D] or b4 > 0x16):
		return "actor slot +0xAC for byte0 13 index %d was not entered" % b4
	var a8: int = stage_read(ref, "byte_0xa8", UNKNOWN)
	if a8 == 0x0F:
		return ""
	if a8 == UNKNOWN and not use_adapter("opcode13_actor_a8"):
		return "actor byte +0xA8 is not known (0x0F skips the store)"
	match b4:
		0:
			var byte5: int = int(bytes[5])
			stage_write(ref, "byte_0xa8", byte5)
			stage_write(ref, "byte_0xa9", byte5)
			_stage_bits(ref, 0xB8, 0x01, 1)
		6:
			_stage_bits(ref, 0xB5, 0x01, 1)
		7:
			_stage_bits(ref, 0xB5, 0x01, 0)
		10:
			_stage_bits(ref, 0xB5, 0x0C, 0)
		0x0D:
			_stage_bits(ref, 0xB5, 0x0C, 1)
	stage_write(ref, FIELD_WORD7C, 0)
	return ""


func _travel_word(ref: String, command: Dictionary) -> String:
	var attrs: Dictionary = attributes.get(ref, {}) as Dictionary
	if not attrs.has("mode"):
		return "target %s mode and angle word not known" % ref
	if int(attrs["mode"]) != MODE_ROTARY and not use_adapter("opcode1_other_modes"):
		return "target %s is mode %d; the not-equal path's continuation is not modelled (LIKELY, adapter opcode1_other_modes off)" % [ref, int(attrs["mode"])]
	var angle: int = int(attrs["angle_word"])
	# The load width/sign of the angle word is not in the cited bytes; both readings agree only on 0..0x7FFF.
	if angle < 0 or angle > 0x7FFF:
		return "angle word %d outside 0..32767" % angle
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	stage_write(ref, FIELD_TRAVEL, ((angle * int(bytes[4])) / 100) & 0xFFFF)
	return ""


## Opcode 2 (0xB5BAC), byte 4 selects the arm. 0x1C (0xD7890) is PROVEN: when the byte at 0x223D6 is 0 it
## writes byte5 & 0x1F to the dword at 0x223C8 and byte5 >> 5 to the dword at 0x223CC; otherwise no
## write. Both return 1. The byte at 0x223D6 is a host global the world side must supply.
## Grok backlog 4 item 0 (LIKELY: each arm ends in a callee that was not entered): arms 0x26/0x27/0x0B/0x0C/57 act on the
## object at encoded 0x22574 (OBJ_22574); arm 5 binds the command's kind/word object into it. Each runs on its adapter
## (ADAPTERS opcode2_*). Arms 0x0B/0x0C/57 also read the host global byte 0x223D4 (a nonzero byte: return 1, no store).
func _op_two(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var arm: int = int(bytes[4])
	match arm:
		0x1C:
			if not _stage_globals.has(0x223D6):
				return "global byte 0x223D6 is not known"
			if int(_stage_globals[0x223D6]) != 0:
				return ""
			stage_global(0x223C8, int(bytes[5]) & 0x1F)
			stage_global(0x223CC, (int(bytes[5]) & 0xE0) >> 5)
			return ""
		0x26, 0x27:
			return _op_two_lock(arm)
		0x05:
			return _op_two_object_ad(command)
		0x06:
			return _op_two_arm6(command)
		0x18:
			# 0xD7890 fall-through (backlog 6 item 1c): 0x91C0C stores dword 0 at 0x23348+0x90B (PROVEN); the old pointer's 0x95C24 path
			# and 0x5F878/0xACA44/0x77BD0/0x95804/0xA98F8/0x9B8F0 were not entered. Byte 5 unread.
			if not use_adapter("opcode2_arm18_clear"):
				return "opcode 2 arm 0x18 clears the 0x23348+0x90B pointer and hands the old one to callees not entered (LIKELY, adapter opcode2_arm18_clear off)"
			stage_write("0x23348", "dword_0x90b", 0)
			return ""
		0x3C:
			# 0xD7F5D (backlog 6 item 1d): PROVEN that every branch returns 1 (EDI stays 0, the command byte is not rewritten). The
			# stores of the 0xD6B20(object, 0, 0) path are the adapter opcode2_arm3c; the gates are the host's own +0x228 bit 0x10
			# (arms 0x26/0x27 write it), byte +0x1AB (not held: taken as nonzero) and the host global 0x223D4.
			if not use_adapter("opcode2_arm3c"):
				return ""
			if int(bytes[5]) != 0:
				return ""
			var bit10: int = _stage_bit(OBJ_22574, 0x228, 0x10)
			if bit10 == 0:
				return ""
			if _stage_bit(OBJ_22574, 0x229, 0x04) == 1:
				return ""
			stage_write(OBJ_22574, "dword_0x1a2", 0)
			if _stage_globals.has(0x223D4) and int(_stage_globals[0x223D4]) == 0:
				stage_write(OBJ_22574, "byte_0x199", 0)
			return ""
		0x24:
			# 0xD823A (backlog 5 item 9, PROVEN body): bit 0x10 then bit 0x20 of byte +0x228 of the 0x22574 object, return 1, no call;
			# byte 5 unread. The shared opcode-2 epilogue (0x663B8) is the one every arm, 0x1C included, runs through.
			_stage_bits(OBJ_22574, 0x228, 0x30, 1)
			return ""
		0x0B, 0x0C:
			return _op_two_counter(arm, int(bytes[5]))
		57:
			return _op_two_arm57()
	return "byte 4 %d: arm not decoded (0x1C PROVEN; 0x26/0x27/5/0x0B/0x0C/57 on adapters)" % arm


## 0xD0138(object, 1) (backlog 4 item 0, entered): zeroes bytes +0x1B6..+0x1BD, +0x22, +0x23, +0x1BE..+0x1C1, the low byte
## and bits 0/1 of the high byte of word +0x226, word +0x20A, and bit 1 of byte +0x22A. Its 0x151DAE -> 0x151B86 path
## (bits 2/3 of +0x229 set and dword +0x85 == 0) was not entered.
func _stage_d0138_reset(ref: String) -> void:
	for offset: int in range(0x1B6, 0x1BE):
		stage_write(ref, "byte_0x%x" % offset, 0)
	for offset: int in [0x22, 0x23, 0x1BE, 0x1BF, 0x1C0, 0x1C1]:
		stage_write(ref, "byte_0x%x" % offset, 0)
	stage_write(ref, "byte_0x226", 0)
	_stage_bits(ref, 0x227, 0x03, 0)
	stage_write(ref, "word_0x20a", 0)
	_stage_bits(ref, 0x22A, 0x02, 0)


## Arms 0x26 (0xD7A9B) and 0x27 (0xD7B21) on the 0x22574 object; adapter opcode2_lock_flags.
func _op_two_lock(arm: int) -> String:
	if not use_adapter("opcode2_lock_flags"):
		return "opcode 2 arm 0x%02x flags the 0x22574 object through 0xD0138/0x151DAE (LIKELY, adapter opcode2_lock_flags off)" % arm
	if arm == 0x26:
		_stage_bits(OBJ_22574, 0x228, 0x80, 1)
		_stage_bits(OBJ_22574, 0x228, 0x10, 0)
		_stage_d0138_reset(OBJ_22574)
		# +0x97 keeps EDI, which is 0 unless 0x151B86 (not entered) changed it; +0x9B is zeroed when nonzero.
		stage_write(OBJ_22574, "dword_0x97", 0)
		stage_write(OBJ_22574, "byte_0x9f", 0)
		stage_write(OBJ_22574, "byte_0x21e", 0)
		_stage_bits(OBJ_22574, 0x19F, 0x08, 0)
		stage_write(OBJ_22574, "dword_0x9b", 0)
	else:
		_stage_bits(OBJ_22574, 0x228, 0x80, 0)
		_stage_bits(OBJ_22574, 0x229, 0x80, 1)
		_stage_bits(OBJ_22574, 0x228, 0x10, 1)
	return ""


## Arm 5 (0xB5ACE -> 0xDD5DC): the kind/word object goes to dword +0xAD of the 0x22574 object; byte 5 nonzero sets bit 0 of
## +0x228 and runs the 0xD0138 reset, zero clears the bit; adapter opcode2_object_ad.
func _op_two_object_ad(command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	if not use_adapter("opcode2_object_ad"):
		return "opcode 2 arm 5 stores the kind/word object at +0xAD of the 0x22574 object (LIKELY, adapter opcode2_object_ad off)"
	stage_write(OBJ_22574, "object_0xad_kind", int(command["kind"]))
	stage_write(OBJ_22574, "object_0xad_index", int(command["target"]))
	if int(bytes[5]) != 0:
		_stage_bits(OBJ_22574, 0x228, 0x01, 1)
		_stage_d0138_reset(OBJ_22574)
	else:
		_stage_bits(OBJ_22574, 0x228, 0x01, 0)
	return ""


## Arm 6 (0xB5B05; Grok backlog 4 arm-6 answer, LIKELY): 0x5FBC8(byte 1, word +2) then a conditional call to 0x79310 that was not
## entered; byte 5 is not read. Adapter opcode2_arm6_object counts the call on the object.
func _op_two_arm6(command: Dictionary) -> String:
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	if not use_adapter("opcode2_arm6_object"):
		return "opcode 2 arm 6 calls 0x79310 on the object, which was not entered (LIKELY, adapter opcode2_arm6_object off)"
	stage_write(ref, "opcode2_arm6_calls", stage_read(ref, "opcode2_arm6_calls", 0) + 1)
	return ""


## Arms 0x0C (0xD7C18 -> +0x15D) and 0x0B (0xD8936 -> +0x159): byte 5 * 100 added when the byte at 0x223D4 is 0; adapter
## opcode2_counters keeps the hosted sum (the dword itself and its 0x7FFFFFF0 clamp are not held).
func _op_two_counter(arm: int, byte5: int) -> String:
	var offset: int = 0x15D if arm == 0x0C else 0x159
	if not use_adapter("opcode2_counters"):
		return "opcode 2 arm 0x%02x adds into dword +0x%x of the 0x22574 object and compares the 0xE810 table through 0x12415C (LIKELY, adapter opcode2_counters off)" % [arm, offset]
	if not _stage_globals.has(0x223D4):
		return "global byte 0x223D4 is not known"
	if int(_stage_globals[0x223D4]) != 0:
		return ""
	var field: String = "dword_0x%x_added" % offset
	stage_write(OBJ_22574, field, stage_read(OBJ_22574, field, 0) + byte5 * 100)
	return ""


## Arm 57 (0xD7E54): bit 0 of byte +0x16 of the 0x22574 object when the byte at 0x223D4 is 0, then three calls that were not
## entered (0xB3B04 with 0xB7D70 unless bit 0x20000000 of dword +0x14, 0xB3AC4 with 0xB7D6C, 0xD8D48); adapter opcode2_arm57.
func _op_two_arm57() -> String:
	if not use_adapter("opcode2_arm57"):
		return "opcode 2 arm 57 sets bit 0 of +0x16 of the 0x22574 object and calls 0xB3B04/0xB3AC4/0xD8D48, which were not entered (LIKELY, adapter opcode2_arm57 off)"
	if not _stage_globals.has(0x223D4):
		return "global byte 0x223D4 is not known"
	if int(_stage_globals[0x223D4]) != 0:
		return ""
	_stage_bits(OBJ_22574, 0x16, 0x01, 1)
	return ""


## Opcode 5 (0xB5970): [vtable+0xB0](object, byte 4, byte 5). Per class (G97 step_opcode5):
## movable/control 0x5D510: v = byte 4, plus the signed +0x3D when byte 5 is nonzero; equal to the
## signed +0x3D -> no store (PROVEN). Otherwise the +0x3D store, then +0x3B and a vtable+0xF8 loop
## that were not entered -> adapter "opcode5_followups". Kind 4 (0x950E8) returns 0, no store.
## Prop 0xF2944 (byte 5 = 0 only): +0x30 equal -> no store; otherwise +0x30 = byte 4 and a frame
## restart that was not entered -> adapter "opcode5_spatial". Actor 0xA7DC4: the same call, then
## +0x7C = 0 -> adapter "opcode5_spatial".
func _op_selector(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var b4: int = int(bytes[4])
	var b5: int = int(bytes[5])
	match class_of_kind(int(command["kind"])):
		"movable", "control":
			var current: int = stage_read(ref, FIELD_SELECTOR, UNKNOWN)
			var signed_current: int = current - 256 if current > 127 else current
			if current == UNKNOWN and b5 != 0:
				return "relative selector on %s with +0x3D unknown" % ref
			var value: int = b4 if b5 == 0 else b4 + signed_current
			if current != UNKNOWN and signed_current == value:
				return ""
			if not use_adapter("opcode5_followups"):
				return "the +0x3D store is followed by +0x3B and a vtable+0xF8 loop that were not entered"
			stage_write(ref, FIELD_SELECTOR, value & 0xFF)
			return ""
		"kind4":
			return ""
		"prop", "actor":
			if b5 != 0:
				return "relative frame on the spatial class needs template bytes that are not exported"
			var frame: int = stage_read(ref, FIELD_BYTE30, UNKNOWN)
			if frame == b4 and class_of_kind(int(command["kind"])) == "prop":
				return ""
			if not use_adapter("opcode5_spatial"):
				return "the +0x30 store is followed by 0xF1F94/0xF2814, which were not entered"
			stage_write(ref, FIELD_BYTE30, b4)
			if class_of_kind(int(command["kind"])) == "actor":
				stage_write(ref, FIELD_WORD7C, 0)
			return ""
	return "slot +0xB0 of kind 0x%02x is not PROVEN" % int(command["kind"])


## Opcode 7 (0xB5997): [vtable+0xB4](object, signed byte 4, byte 5). Per class (G97 step4_vtables):
## prop 0xF21A4: 0 -> +0x36 |= 0x05; 1 -> &= 0xFE; 7 -> |= 0x02; 8 -> &= 0xFD; 9 -> ^= 0x02;
## 10 -> +0x37 = (+0x37 & 0xF0) | byte 5 (refused, +0x37 is not known); 2..6 and > 10 enter UNKNOWN
## callees. Actor 0xA2558: every arm stores 0 at word +0x7C; 0 -> +0xB5 &= 0xFD; 1 -> |= 0x02;
## 2..6 call 0xF2814 (UNKNOWN). Movable/control 0x5D5F8 write through a vtable+0xF8 pointer (UNKNOWN).
func _op_seven(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var index: int = int(bytes[4])
	match class_of_kind(int(command["kind"])):
		"prop":
			match index:
				0:
					_stage_bits(ref, 0x36, 0x05, 1)
				1:
					_stage_bits(ref, 0x36, 0x01, 0)
				7:
					_stage_bits(ref, 0x36, 0x02, 1)
				8:
					_stage_bits(ref, 0x36, 0x02, 0)
				9:
					var bit: int = _stage_bit(ref, 0x36, 0x02)
					if bit == UNKNOWN:
						return "xor of +0x36 bit 0x02 with the bit unknown"
					_stage_bits(ref, 0x36, 0x02, 1 - bit)
				_:
					return "prop slot +0xB4 index %d is not decoded" % index
			return ""
		"actor":
			if index >= 2 and index <= 6:
				return "actor slot +0xB4 index %d calls 0xF2814 (UNKNOWN)" % index
			if index == 0:
				_stage_bits(ref, 0xB5, 0x02, 0)
			elif index == 1:
				_stage_bits(ref, 0xB5, 0x02, 1)
			stage_write(ref, FIELD_WORD7C, 0)
			return ""
		"control":
			# 0x5D5F8 (backlog 4 item 9 LIKELY): word +0x36 == 0xFFFF -> return 0, no store; otherwise [vtable+0xF8] = 0x5DA20 gives
			# [0x273E4] + that word and the loop over the control's records ORs bit 1 (index 0) or bit 2 (index 7) into byte +3 of
			# each record whose dword +0x3A >> 24 matches. Indexes 1-6, 8, 9 were not entered; above 9 skips the record.
			if index > 9:
				return ""
			if not index in [0, 7]:
				return "control slot +0xB4 index %d was not entered" % index
			if not use_adapter("opcode7_control_records"):
				return "opcode 7 on a control ORs bits into its records' byte +3 (LIKELY, adapter opcode7_control_records off)"
			_stage_bits(ref + ":records", 0x03, 0x02 if index == 0 else 0x04, 1)
			return ""
	return "slot +0xB4 of kind 0x%02x writes through UNKNOWN pointers" % int(command["kind"])


## Opcode 9 (0xB59B3 -> 0xB50C0), switch on byte 4 (G97 step3, step4_vtables, step4_b49ec).
func _op_nine(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var arm: int = int(bytes[4])
	var cls: String = class_of_kind(int(command["kind"]))
	match arm:
		0, 1:
			return ""
		2:
			# 0xB49EC(object, 0): with +0x15 bit 0x10 clear the zero-argument path can run 0x9EFA8 (backlog3 item4 LIKELY).
			var bit10: int = _stage_bit(ref, 0x15, 0x10)
			if bit10 == 1:
				return "0xB49EC with +0x15 bit 0x10 set enters UNKNOWN callees"
			if bit10 == UNKNOWN and not use_adapter("b71a0_bit_clear"):
				return "+0x15 bit 0x10 is not known"
			if not use_adapter("opcode9_release"):
				return "opcode 9 arm 2 releases the player record through 0x9EFA8 (LIKELY, adapter opcode9_release off)"
			stage_write(PLAYER_REF, "released_by", int(command["target"]))
			stage_write(PLAYER_REF, "word_0x0c", 0)
			stage_write(PLAYER_REF, "byte_0x41", 0)
			stage_write(PLAYER_REF, "byte_0x4e", 0)
			stage_write("0x23c68", "dword_0x2ce8", 0)
			stage_write("0x23c68", "byte_0x2d09", 0)
			stage_write("0x23c68", "bit_0x2d0e_0x01", 0)
			stage_write("0x23c68", "bit_0x2d0e_0x04", 0)
			stage_write("0x23c68", "bit_0x2d5c_0x40", 0)
			return ""
		0x15:
			# [object+0x28]+0xB8 = 0xB71A0 on the four classes: stores the context, returns P; 0xADDE0(P, 0x14) enqueues
			# the kind-6 record with byte +4 == 0x14 unless its trailer predicate fails (backlog3 item4 LIKELY).
			if not cls in ["movable", "control", "prop", "actor"]:
				return "slot +0xB8 of kind 0x%02x is not PROVEN" % int(command["kind"])
			var b10x: int = _stage_bit(ref, 0x15, 0x10)
			if b10x == 1:
				return "0xB71A0 returns 0 (+0x15 bit 0x10 set): nothing enqueued"
			if b10x == UNKNOWN and not use_adapter("b71a0_bit_clear"):
				return "+0x15 bit 0x10 is not known"
			if not use_adapter("opcode9_enqueue"):
				return "opcode 9 arm 0x15 enqueues the object's kind-6 record with byte +4 = 0x14 (LIKELY, adapter opcode9_enqueue off)"
			_stage_effects.append({"type": "enqueue", "ref": ref, "event_kind": 6, "caller_byte": 0x14})
			return ""
		3:
			# 0xB49EC(object, 1), G97 step4_b49ec. Bit 0x10 of byte +0x15 clear: EAX 0 and no write.
			# Bit set: store 0 at +0x0C, clear that bit (0xeba31), OR 1 into byte +0x16 (flag 0x10000,
			# 0xebb47) and OR 0x20 into byte +0x17 (flag 0x20000000, 0xebb7c). Those two ORs are the
			# link. 0xAF0E0, 0xB4130 and 0x5C9D0 run after the stores and were not entered, so their
			# extra writes are not staged. The opcode wrapper returns 1 either way. An unstaged bit
			# uses the constructor copy of placement word +8 (0xAE990, 668b4208 894314).
			var b10: int = _stage_bit(ref, 0x15, 0x10)
			if b10 == UNKNOWN:
				b10 = _placement_word_bit(ref, 0x1000)
			if b10 == UNKNOWN and not use_adapter("b71a0_bit_clear"):
				return "+0x15 bit 0x10 is not known"
			if b10 != 1:
				return ""
			stage_write(ref, "dword_0x0c", 0)
			_stage_bits(ref, 0x15, 0x10, 0)
			_stage_bits(ref, 0x16, 0x01, 1)
			_stage_bits(ref, 0x17, 0x20, 1)
			return ""
		7:
			_stage_bits(ref, 0x14, 0x80, 1)
		8:
			_stage_bits(ref, 0x14, 0x80, 0)
		9:
			_stage_bits(ref, 0x16, 0x02, 1)
		0x0A:
			_stage_bits(ref, 0x16, 0x02, 0)
		0x0B:
			_stage_bits(ref, 0x15, 0x20, 1)
		0x0C:
			_stage_bits(ref, 0x15, 0x20, 0)
		0x0D:
			_stage_bits(ref, 0x15, 0x80, 0)
		0x0E:
			_stage_bits(ref, 0x15, 0x80, 1)
		0x11:
			_stage_bits(ref, 0x15, 0x40, 1)
		0x12:
			_stage_bits(ref, 0x15, 0x40, 0)
		0x13:
			stage_write(ref, FIELD_BYTE26, int(bytes[5]))
		0x14:
			var b80: int = _stage_bit(ref, 0x15, 0x80)
			if b80 == UNKNOWN:
				return "arm 0x14 tests +0x15 bit 0x80, which is not known"
			if b80 == 0:
				_stage_bits(ref, 0x17, 0x04, 1)
		0x1A, 0x1B, 0x1C, 0x1D:
			# [vtable+0xAC] with byte0 9: no store on the four entered classes.
			if cls in ["movable", "control", "prop", "actor"]:
				return ""
			return "slot +0xAC of the kind-0x%02x class was not entered" % int(command["kind"])
		_:
			if arm <= 0x22:
				return "opcode 9 arm 0x%02x is not decoded" % arm
			# Above 0x22: [vtable+0xAC] with byte0 9.
			match cls:
				"movable":
					if arm == 0x23:
						_stage_bits(ref, 0x14, 0x10, 1)
					elif arm == 0x24:
						_stage_bits(ref, 0x14, 0x10, 0)
					return ""
				"control", "prop":
					return ""
				"actor":
					if arm == 0x25:
						return "actor arm 0x25 calls 0x5F878 (UNKNOWN)"
					return ""
			return "slot +0xAC of the kind-0x%02x class was not entered" % int(command["kind"])
	return ""


## Opcode 3 with kind byte 1 (backlog 6 item 1c): the kind-1 slot +0xAC is 0xD7890 (the opcode-2 handler's object, vtable 0x5C20 =
## the 0x22574 object, LIKELY binding); byte 0 == 3 reaches the 0x223D4 compare (PROVEN); when that byte is 0, 0x95B68(object,
## dword +4, byte 8, 1) walks the player record's 0x5B-stride list for the dword (PROVEN walk) and hands the hit to slot +0x6C
## (callees not entered). The port's hosted sources (museum_prism_source, hive_net_exile_source) read the dword as the item
## definition identity: adapter opcode3_item_grant emits item_request and stores nothing.
func _op_three_item(command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	if bytes.size() < 12:
		return "opcode 3 command shorter than 12 bytes"
	if not use_adapter("opcode3_item_grant"):
		return "opcode 3 kind 1 hands the item identity to vtable slot +0x6C, not entered (LIKELY, adapter opcode3_item_grant off)"
	if not _stage_globals.has(0x223D4):
		return "global byte 0x223D4 is not known"
	if int(_stage_globals[0x223D4]) != 0:
		return ""
	_stage_effects.append({"type": "item", "ref": target_ref(1, int(command["target"])), "identity": bytes.decode_u32(4), "arg": int(bytes[8])})
	return ""


## Opcode 12 (0xB5A9E -> 0xED6D0, backlog 6 item 1c): byte 4 is the room-archive stem index (0xED470: [index*4 + 0xEA6C], cut at
## '_', plus ".mix"); below 46 the byte at 0x269C4 gets bit 1. Two gates were not read (bit 25 of 0x2279A, the byte at 0xB860):
## adapter opcode12_room emits room_request and stages the bit. An index at or above 46 is rejected natively (no store).
func _op_twelve(_host: Object, command: Dictionary) -> String:
	var index: int = int((command["bytes"] as PackedByteArray)[4])
	if index >= 46:
		return ""
	if not use_adapter("opcode12_room"):
		return "opcode 12 opens room stem %d behind gates that were not read (LIKELY, adapter opcode12_room off)" % index
	var stem: String = ""
	var archive: String = ""
	if index < room_stems.size():
		stem = str((room_stems[index] as Dictionary).get("stem", ""))
		archive = str((room_stems[index] as Dictionary).get("archive", ""))
	_stage_bits("0x269c4", 0x00, 0x02, 1)
	_stage_effects.append({"type": "room", "index": index, "stem": stem, "archive": archive})
	return ""


## Opcode 210 (0x65954, backlog 6 item 1c): byte 4 above 0xB returns 1 with no store (PROVEN); arm 9 (0x65B37, entered) stores
## ((byte 5 << 15) - byte 5) >> 8 into the word at 0x26D1E, and into 0x26D1C too unless the dword at 0x26D2C equals 0x26D1A (not
## read): adapter opcode210_arm9 stages both. The other arms of the 0xC900 table were not entered.
func _op_two_one_zero(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var arm: int = int(bytes[4])
	if arm > 0x0B:
		return ""
	if arm != 9:
		return "opcode 210 arm %d of the 0xC900 table was not entered" % arm
	if not use_adapter("opcode210_arm9"):
		return "opcode 210 arm 9 stores a word at 0x26D1E/0x26D1C whose readers were not entered (LIKELY, adapter opcode210_arm9 off)"
	var byte5: int = int(bytes[5])
	var word: int = (((byte5 << 15) - byte5) >> 8) & 0xFFFF
	stage_write("0x26d1e", "word", word)
	stage_write("0x26d1c", "word", word)
	return ""


## Opcode 15 (0xB5C82; backlog 4 item 4): byte 4 above 0x70 goes to the epilogue (no store, PROVEN). Otherwise the slot of the
## 0xB56D8 table for byte 4 looks up the (byte 5, word +6) object and calls a per-form callee whose play effect was not entered:
## adapter opcode15_effect_request emits the form and both objects for the world side and stores nothing.
func _op_fifteen(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var form: int = int(bytes[4])
	if form > 0x70:
		return ""
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	if not use_adapter("opcode15_effect_request"):
		return "opcode 15 form 0x%02x plays through callees that were not entered (LIKELY, adapter opcode15_effect_request off)" % form
	var lookup: String = _resolve_staged(target_ref(int(bytes[5]), bytes.decode_u16(6))) if OBJECT_KINDS.has(int(bytes[5])) else ""
	_stage_effects.append({"type": "effect", "form": form, "ref": ref, "lookup": lookup})
	return ""


## Opcode 18 (0xB59CE; backlog 4 item 4 PROVEN arm): a zero dword at 0xB7D5E takes the command pointer, a nonzero one is left;
## bit 5 of the word at command +0xA (clear on every Act 1 command) would run 0x660F8, which edits the command (not modelled).
## The cell's start value and its reader were not entered: adapter opcode18_pending_slot takes the cell as empty at start.
func _op_eighteen(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	if bytes.size() >= 12 and (int(bytes[10]) & 0x20) != 0:
		return "opcode 18 with bit 5 of the word +0xA set runs 0x660F8 (edits the command; not modelled)"
	if not use_adapter("opcode18_pending_slot"):
		return "opcode 18 stores the command into the 0xB7D5E slot whose start value and reader were not entered (LIKELY, adapter opcode18_pending_slot off)"
	if stage_read("0xb7d5e", "command_file_offset", 0) == 0:
		stage_write("0xb7d5e", "command_file_offset", int(command["file_offset"]))
	return ""


## Opcode 19 (0xB6B5F -> 0x66130; backlog 4 item 4): the record (PROVEN fields) for the object's vtable slot +0x80 (not entered).
## Byte 9: 0 -> value byte 8; 1/2 -> a vtable percentage (slots +0x8C/+0x88, not entered: refused); other -> the dispatcher
## object pointer (value UNKNOWN here). Adapter opcode19_effect_record emits the record and stores nothing.
func _op_nineteen(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	if bytes.size() < 10:
		return "opcode 19 command shorter than 10 bytes"
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var byte9: int = int(bytes[9])
	if byte9 == 1 or byte9 == 2:
		return "opcode 19 byte 9 %d scales byte 8 by vtable slot +0x%02X, which was not entered" % [byte9, 0x8C if byte9 == 1 else 0x88]
	if not use_adapter("opcode19_effect_record"):
		return "opcode 19 hands its record to vtable slot +0x80, which was not entered (LIKELY, adapter opcode19_effect_record off)"
	var value: int = int(bytes[8]) if byte9 == 0 else UNKNOWN
	_stage_effects.append({"type": "effect_record", "ref": ref, "word0": bytes.decode_u16(4), "word2": bytes.decode_u16(6), "value": value, "byte9": byte9})
	return ""


## Opcode 208 (0x65518; backlog 4 item 4): byte 4 == 0 (every Act 1 command) takes 0x65535: a nonzero byte 5 raises the dword at
## 0x26B4E to byte 6 * 60 << 16 and the byte at 0x26B52 to byte 5 when the stored values are lower; byte 5 == 0 clears both.
## No call. The cells' start values and readers were not entered: adapter opcode208_cells takes them as 0 at start.
func _op_two_oh_eight(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	if int(bytes[4]) != 0:
		return "opcode 208 byte 4 %d: only the below-1 arm was entered" % int(bytes[4])
	if not use_adapter("opcode208_cells"):
		return "opcode 208 writes the 0x26B4E/0x26B52 cells whose start values and readers were not entered (LIKELY, adapter opcode208_cells off)"
	if int(bytes[5]) == 0:
		stage_write("0x26b4e", "dword", 0)
		stage_write("0x26b52", "byte", 0)
		return ""
	var product: int = (int(bytes[6]) * 60) << 16
	if stage_read("0x26b4e", "dword", 0) < product:
		stage_write("0x26b4e", "dword", product)
	if stage_read("0x26b52", "byte", 0) < int(bytes[5]):
		stage_write("0x26b52", "byte", int(bytes[5]))
	return ""


## Opcode 14 (0xB59BF -> 0xB47B4): [vtable+0xB8] (0xB71A0 on the four classes) gives the object's
## event list; the walk selects the (byte 6)-th kind-2 record, or the last one. Byte 4: 0 -> record
## byte +4 = byte 5; 1 -> +6; 2 -> +7; above 6 -> no write. 3..6 are not decoded. The list belongs to
## the target object, so the target must resolve to a placement (adapter "slot_index_binding").
func _op_fourteen(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	if not class_of_kind(int(command["kind"])) in ["movable", "control", "prop", "actor"]:
		return "slot +0xB8 of kind 0x%02x is not PROVEN" % int(command["kind"])
	var arm: int = int(bytes[4])
	if arm > 6:
		return ""
	if arm > 4:
		# Arm 5 is not decoded. Per-host adapter opcode14_arm5_noop (registered by the L16 host only, DEVIATIONS 2026-11-05)
		# lets the rest of the group run (L16 gate groups 672/698/3004: arm 5 on gate 2's timer, then opcode 1 opens it).
		if arm == 5 and use_adapter("opcode14_arm5_noop"):
			return ""
		return "opcode 14 arm %d is not decoded" % arm
	var b10: int = _stage_bit(ref, 0x15, 0x10)
	if b10 == 1:
		return "0xB71A0 returns 0 (+0x15 bit 0x10 set); the write target is not shown"
	if b10 == UNKNOWN and not use_adapter("b71a0_bit_clear"):
		return "+0x15 bit 0x10 is not known"
	if not object_lists.has(ref):
		return "the event list of %s is not known (unbound target)" % ref
	var count: int = int(bytes[6])
	var chosen: int = -1
	for raw: Variant in object_lists[ref] as Array:
		var row: Dictionary = raw as Dictionary
		var rb: PackedByteArray = row["bytes"] as PackedByteArray
		if rb.size() >= 2 and int(rb[1]) == 2:
			chosen = int(row["file_offset"])
			if count == 0:
				break
			count -= 1
	if chosen < 0:
		return "%s has no kind-2 record" % ref
	if arm > 2:
		# Arms 3/4 (backlog3 item4 LIKELY): start / stop the selected kind-2 record (adapter opcode14_timer).
		if not use_adapter("opcode14_timer"):
			return "opcode 14 arm %d starts/stops the kind-2 record (LIKELY, adapter opcode14_timer off)" % arm
		var chosen_bytes: PackedByteArray = PackedByteArray()
		for raw2: Variant in object_lists[ref] as Array:
			if int((raw2 as Dictionary)["file_offset"]) == chosen:
				chosen_bytes = (raw2 as Dictionary)["bytes"] as PackedByteArray
		var byte5: int = int((_stage_records.get(chosen, {}) as Dictionary).get("byte5", chosen_bytes[5] if chosen_bytes.size() > 5 else 0))
		if arm == 3:
			byte5 = (byte5 & ~0x01) | 0x80
		else:
			byte5 = (byte5 & ~0x80) | 0x01
		stage_record_byte(chosen, 5, byte5)
		_stage_records[chosen]["listed"] = 1 if arm == 3 else 0
		_stage_effects.append({"type": "record", "record": chosen, "field": "listed", "value": 1 if arm == 3 else 0})
		if int(bytes[5]) != 0:
			var byte4: int = int(chosen_bytes[4]) if chosen_bytes.size() > 4 else 0
			var ax: int = int(chosen_bytes[6]) if (byte4 & 0x20) != 0 and chosen_bytes.size() > 6 else UNKNOWN
			_stage_records[chosen]["word8"] = ax
			_stage_effects.append({"type": "record", "record": chosen, "field": "word8", "value": ax})
		return ""
	var offsets: Array[int] = [4, 6, 7]
	stage_record_byte(chosen, offsets[arm], int(bytes[5]))
	return ""


## Opcode 16, LOLG 0xB5A3C (8a4604 25ff000000 884325): stores command byte 4 at object +0x25.
func _op_byte25(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	stage_write(ref, FIELD_BYTE25, int(bytes[4]))
	return ""


## Opcode 20, LOLG 0xB5BF8: calls 0xE3924 with the request u16 at +4. The callee was not entered,
## so the host only emits sound_request(u16). The other bytes stay undecoded.
func _op_sound(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	stage_sound(int(bytes[4]) | (int(bytes[5]) << 8))
	return ""


## Opcode 6 (backlog3 item3): 0xB3EC8 on command byte 4, on P = the pointer slot +0xB8 returns (0xB71A0: [0xB7D74] +
## the object word +0x18, the object's 42-byte record; host ref "record:<object>"). Gate: bit 0x200 of the object dword
## +0x14 set and bit 0x10 of byte +0x15 clear, else no store (opcode6_gates when not known). Arms 3-6 are PROVEN stores
## of command byte 5 at P+9, P+0xA, P+8 and the word P+6. Arm 0 (PROVEN) starts the record through 0x9F584/0x9F5BC on
## flags the host does not hold; arm 1 (LIKELY) adds the 0xB4130 list move; arm 2 (LIKELY) sets bit 0x80 of P+2 and
## re-reads byte +0xD: all three through opcode6_record. Arms 7-0xC have no given effect (refused); above 0xC returns 1
## after the 0xB7D80 context store (no record store). No Act 1 command has byte 4 above 6.
func _op_six(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var arm: int = int(bytes[4])
	var value: int = int(bytes[5]) if bytes.size() > 5 else 0
	if arm > 0x0C:
		return ""
	if arm > 6:
		return "opcode 6 arm %d has no given effect (0xB3EC8 table 7-0xC)" % arm
	if not use_adapter("opcode6_gates"):
		return "opcode 6 needs bit 0x200 of the object dword +0x14 and bit 0x10 of byte +0x15 (not known; adapter opcode6_gates off)"
	var record: String = "record:" + ref
	match arm:
		3:
			stage_write(record, "byte_0x09", value)
		4:
			stage_write(record, "byte_0x0a", value)
		5:
			stage_write(record, "byte_0x08", value)
		6:
			stage_write(record, "word_0x06", value)
		0, 1, 2:
			if not use_adapter("opcode6_record"):
				return "opcode 6 arm %d acts on the object's record through 0x9F584/0x9F5BC on flags the host does not hold (adapter opcode6_record off)" % arm
			if arm == 2:
				stage_write(record, "bit_0x02_0x80", 1)
				stage_write(record, "byte_0x0d", UNKNOWN)
			else:
				stage_write(record, "word_0x04", 0)
				stage_write(record, "byte_0x0d", 1)
				stage_write(record, "bit_0x03_0x20", 1)
				if arm == 1:
					stage_write(record, "list_0x22d10", 1)
	return ""


## Opcode 8 (backlog3 item2): 0xB43EC on command byte 4. Arms 0, 2 and 10 call into the global player record at encoded
## 0x22CD8 with the object's own argument (sar 16 of [object+0x2C]+0x22, which the host has no record of: the command's
## target index stands in) and, for 2 and 10, the command's word +4 (bytes 5 and 7 are 0 on every Act 1 command, so that
## value is byte 6). Arms 1 and 3 call 0x9EFA8 / 0x9EEF4 on the same record. Arms 4-8 are PROVEN stores through the
## pointer at 0x22CE0 (+0x14, +0x1C, +0x1C with 0x15F03C, +0x30 with 0xFF -> -1, and 0x15EF3C). Arms above 10 index the
## shared table at 0xB4390 (not read): refused. The fields are the host's names for those stores (PLAYER_REF / PLAYER_PTR).
const PLAYER_REF := "0x22cd8"
## The object whose pointer sits at encoded 0x22574 (opcode-2 arms 0x26/0x27/5/0x0B/0x0C/57; backlog 4 item 0). Unnamed.
const OBJ_22574 := "0x22574"
const PLAYER_PTR := "0x22ce0"
func _op_eight(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var out: Dictionary = {}
	var ref: String = _target(command, out)
	if ref == "":
		return str(out["reason"])
	var arm: int = int(bytes[4])
	# sar 16 of the dword at command +4 = the signed word at +6 (bytes 5 and 7 are 0 on every Act 1 command: byte 6).
	var value: int = bytes.decode_s16(6) if bytes.size() > 7 else (int(bytes[6]) if bytes.size() > 6 else 0)
	if arm > 10:
		return "opcode 8 arm %d indexes the 0xB4390 table (UNKNOWN)" % arm
	if arm != 0 and not use_adapter("opcode8_gates"):
		return "opcode 8 arm %d needs bit 0x80000 of the object dword +0x14 (not known; adapter opcode8_gates off)" % arm
	match arm:
		0:
			if not use_adapter("opcode8_player"):
				return "opcode 8 arm 0 selects the object on the player record 0x22CD8 (LIKELY, adapter opcode8_player off)"
			stage_write(PLAYER_REF, "owner_0x14", int(command["target"]))
			stage_write(PLAYER_REF, "word_0x10", int(command["target"]))
		1:
			if not use_adapter("opcode8_player"):
				return "opcode 8 arm 1 releases the player record 0x22CD8 (LIKELY, adapter opcode8_player off)"
			stage_write(PLAYER_REF, "bit_0x14_0x4000000", 0)
			stage_write(PLAYER_REF, "bit_0x14_0x8000", 0)
			stage_write(PLAYER_REF, "released_by", int(command["target"]))
		2, 10:
			if not use_adapter("opcode8_player"):
				return "opcode 8 arm %d sets a player value (LIKELY, adapter opcode8_player off)" % arm
			stage_write(PLAYER_REF, "value_0x9edf8" if arm == 2 else "value_0x9ee70", value)
			stage_write(PLAYER_REF, "word_0x10", int(command["target"]))
		3:
			if not use_adapter("opcode8_player"):
				return "opcode 8 arm 3 copies the player byte +0x4E to +0x3C (LIKELY, adapter opcode8_player off)"
			stage_write(PLAYER_REF, "byte_0x3c_from_0x4e", 1)
		4:
			stage_write(PLAYER_PTR, "word_0x14", value)
		5:
			stage_write(PLAYER_PTR, "word_0x1c", value)
		6:
			stage_write(PLAYER_PTR, "word_0x1c", value)
			if value > 0:
				stage_write(PLAYER_PTR, "word_0x11e", value)
		7:
			stage_write(PLAYER_PTR, "word_0x30", -1 if value == 0xFF else value)
		8:
			stage_write(PLAYER_REF, "called_0x15ef3c", 1)
		_:
			return "opcode 8 arm %d: no arm" % arm
	return ""


## Opcode 21 (backlog3 item1): 0xCF2B4(byte 4, byte 5). A negative byte 4, or one above the image dword 85 at 0xE740,
## leaves the index path (nothing plays: a no-op here). Otherwise the name at table slot byte 4 is formatted "%s.vqa"
## (PROVEN) and 0xCF3C0 opens that container (LIKELY: play the movie). The host stages a movie request; the world side
## plays it through the port's player for that name (scripts/lol2/movie_players.json) or logs the name (adapter).
func _op_movie(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var index: int = bytes.decode_s8(4)
	if index < 0 or index > movie_table.size() or movie_table.is_empty():
		if movie_table.is_empty():
			return "opcode 21: the movie table is not loaded (%s)" % MOVIE_TABLE
		return ""
	if not use_adapter("opcode21_movie"):
		return "opcode 21 plays movie %d (%s.vqa) through 0xCF3C0 (LIKELY, adapter opcode21_movie off)" % [index, movie_table[mini(index, movie_table.size() - 1)]]
	var name: String = movie_table[index] if index < movie_table.size() else ""
	_stage_effects.append({"type": "movie", "index": index, "name": name, "byte5": int(bytes[5])})
	return ""


## Opcode 198, LOLG 0x64887 (a1546e0200 8a5304 01c2 8a4305 8802): stores byte 5 at [0x26E54] + byte 4.
## The base is a global pointer, so the array is held per area, not per object.
func _op_local(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	stage_local(int(bytes[4]), int(bytes[5]))
	return ""


## Opcode 197 (0x64CD4 through 0x6485A, Grok backlog-2 item 2 PROVEN): selects no object. The command word +2 (N) indexes
## the 44-byte table at [0x22D0C], the region records the movement check indexes by neighbour word (backlog-3b item 7;
## the pointer itself is unnamed). Arms 0-5 clear/set bits of the flag byte +0x1C: 0 clears bit 0, 1 clears bit 1, 2 sets
## bit 0, 3 sets bit 1, 4 sets both, 5 clears both (bits 0/1 are the ones the movement check drops a region on). Arm 8 sets
## and arm 9 clears bit 0 of byte +0x1D. Arms 6/7 clear/set bit 2 of byte +0x19 of the 42-byte record [0x22D10] + (word
## +0x18 of record N) * 42 (adapter opcode197_region_record: the word is not loaded). Arm 10 calls 0x66664 with N: the
## 12-byte table at [0x2B53C] (count [0x2B538], index from 1) is walked for word +6 == N and byte +9 of the match is set to
## 1; no match stores nothing (adapter opcode197_list_mark: the table is not held). Arms above 10 return 1 with no store.
## State keys: "0x22d0c:N" (shared with opcode 204), "0x22d10:region:N", "0x2b53c:N".
func _op_one_nine_seven(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var word: int = bytes.decode_u16(2)
	var arm: int = int(bytes[4])
	if arm > 10:
		return ""
	var record: String = "0x22d0c:%d" % word
	match arm:
		0:
			_stage_bits(record, 0x1C, 0x01, 0)
		1:
			_stage_bits(record, 0x1C, 0x02, 0)
		2:
			_stage_bits(record, 0x1C, 0x01, 1)
		3:
			_stage_bits(record, 0x1C, 0x02, 1)
		4:
			_stage_bits(record, 0x1C, 0x03, 1)
		5:
			_stage_bits(record, 0x1C, 0x03, 0)
		8:
			_stage_bits(record, 0x1D, 0x01, 1)
		9:
			_stage_bits(record, 0x1D, 0x01, 0)
		6, 7:
			if not use_adapter("opcode197_region_record"):
				return "opcode 197 arm %d acts on the 42-byte record of region %d's word +0x18, which the host does not load (adapter opcode197_region_record off)" % [arm, word]
			_stage_bits("0x22d10:region:%d" % word, 0x19, 0x04, 1 if arm == 7 else 0)
		10:
			if not use_adapter("opcode197_list_mark"):
				return "opcode 197 arm 10 marks the [0x2B53C] entry whose word +6 is %d, a table the host does not hold (adapter opcode197_list_mark off)" % word
			stage_write("0x2b53c:%d" % word, "byte_0x09", 1)
	return ""


## Opcode 204 (0x647B3, G97 step3b), on unnamed tables: signed word +4 == -2 -> byte +0x22 of the
## 44-byte record [0x22D0C] + word2*44 = byte 6; any other value except -1 -> the 8-byte record
## [0x22D08] + word4*8: word +0 = word +6 and byte +5 |= 0x40. The -1 arm enters 0xB861C (UNKNOWN).
## State keys are the raw tables: "0x22d0c:N" and "0x22d08:N".
func _op_two_oh_four(_host: Object, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"] as PackedByteArray
	var word4: int = bytes.decode_s16(4)
	if word4 == -1:
		return "the -1 arm calls 0xB861C (UNKNOWN)"
	if word4 == -2:
		stage_write("0x22d0c:%d" % bytes.decode_u16(2), FIELD_BYTE22, int(bytes[6]))
		return ""
	var entry: String = "0x22d08:%d" % word4
	stage_write(entry, FIELD_WORD00, bytes.decode_u16(6))
	_stage_bits(entry, 0x05, 0x40, 1)
	return ""
