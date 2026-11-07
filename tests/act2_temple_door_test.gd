extends SceneTree
## Subsystem test, NOT the full hintbook-route test required for task F.
const Door = preload("res://scripts/lol2/act2_temple_door_state.gd")
const Native = preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL temple door: ", message)
func _initialize() -> void:
	var native = Native.new()
	check(native.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "load source")
	# Existing binder environment adapter; this is not a quest-local seed.
	native.set_global(0x223D6, 0)
	var state := Door.initial()
	check(not Door.enter(state, native), "closed door refuses without writing permission")
	check(not native.locals.has(13), "no arrival seed")
	check(not Door.offer(state, "Silverleaf"), "wrong item refused")
	check(Door.offer(state, Door.ITEM), "held dreamstone opens")
	check(Door.offer(state, Door.ITEM) and not state.open, "second offer closes as native hotspot does")
	check(not Door.enter(state, native), "closed again refuses")
	check(Door.offer(state, Door.ITEM), "reopen")
	state = JSON.parse_string(JSON.stringify(state))
	check(Door.validate(state).is_empty(), "open state survives serialization")
	check(Door.enter(state, native), "native room action earns local13")
	check(native.locals.get(13, -1) == 1, "earned permission")
	check(not Door.enter(state, native), "duplicate entry refused")
	var results = native.fire_event("prop:1198", 6, {"caller_byte":20, "caller_byte_2":0})
	if native.locals.get(13, -1) != 0: print(results)
	check(not results.is_empty(), "native exit event matched")
	check(native.globals.get(0x223C8, -1) == 14 and native.globals.get(0x223CC, -1) == 1, "original group selects temple")
	check(native.locals.get(13, -1) == 0, "original group consumes permission")
	check(not Door.validate({"open":false,"entered":true}).is_empty(), "corrupt state rejected")
	if failures == 0: print("PASS temple door source-state path to native L14 exit without arrival seed; full L8 quest not claimed")
	quit(0 if failures == 0 else 1)
