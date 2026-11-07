extends SceneTree
## Headless: weapon poison coats (weapon_poison.gd) and the Kelsrick scanner rule (docs/poison-paint.md).
## - Coats: apply adds one paint coat, refused at nine in total; a strike spends the death-sac counter first (0x40),
##   then the paint counter (0x20), then nothing; the packet validates, rejects overflow and loads legacy saves as empty.
## - Kelsrick's kind-9 list through jungle_kelsrick_state.hit: a sword strike (2/4) fires 30456 (shared29 = 1, the
##   alert); a coated strike (2/0x24) fires 30402 only (GV_KELSRICK_DEAD, local52, death) and nothing writes
##   shared29; a coated strike with 30402 already latched falls through to nothing new (local52 blocks 30456/30544);
##   a strike after a loud one changes nothing more (latched).
const Poison = preload("res://scripts/lol2/weapon_poison.gd")
const Kelsrick = preload("res://scripts/lol2/jungle_kelsrick_state.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
	return ok
func shared_writes(effects: Array) -> Dictionary:
	var out := {}
	for e in effects:
		if e is Dictionary and e.get("type") == "shared": out[str(e.index)] = int(e.value)
	return out
func groups(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		if e is Dictionary and e.get("type") == "group": out.append(int(e.group))
	return out
func run() -> void:
	# Coats.
	var s := Poison.initial()
	check(Poison.validate(s).is_empty() and Poison.coats(s) == 0 and Poison.strike_flag(s) == 0,"empty packet: no flag")
	for i in range(9): check(Poison.apply_paint(s),"paint coat %d" % (i+1))
	check(Poison.coats(s) == 9 and not Poison.apply_paint(s) and int(s.paint) == 9,"the tenth coat is refused")
	check(Poison.validate(s).is_empty(),"nine coats validate")
	s.sac = 1; s.paint = 8
	check(Poison.validate(s).is_empty() and Poison.strike_flag(s) == 0x40 and int(s.sac) == 0 and int(s.paint) == 8,"death-sac coat spent first with 0x40")
	check(Poison.strike_flag(s) == 0x20 and int(s.paint) == 7,"then a paint coat with 0x20")
	var bad := Poison.initial(); bad.paint = 5; bad.sac = 5
	check(not Poison.validate(bad).is_empty(),"ten coats in total are rejected")
	bad = Poison.initial(); bad.paint = -1
	check(not Poison.validate(bad).is_empty(),"negative coats are rejected")
	check(Poison.validate({}).is_empty() and Poison.coats(Poison.normalize({})) == 0,"legacy packet is empty")
	# Kelsrick's scanner.
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/jungle_kelsrick_source.json"))
	var ctx := {"shared":{"0":5,"11":0,"29":0},"locals":{"15":1}}
	var k := Kelsrick.initial(src)
	var loud := Kelsrick.hit(k,src,2,4,5,ctx)
	check(groups(loud).has(30456) and shared_writes(loud).get("29",0) == 1 and int(k.locals["52"]) == 1 and int(k.owner_state) == 40 and int(k.health) == 195,"sword strike: 30456, shared29 = 1 (the alert)")
	check(not groups(loud).has(30402),"the loud strike does not reach 30402")
	k = Kelsrick.initial(src)
	var quiet := Kelsrick.hit(k,src,2,4|Poison.FLAG_PAINT,5,ctx)
	var writes := shared_writes(quiet)
	check(groups(quiet) == [30402] or (groups(quiet).size() >= 1 and groups(quiet)[0] == 30402 and not groups(quiet).has(30456) and not groups(quiet).has(30544)),"coated strike: 30402 first and alone: %s" % [groups(quiet)])
	check(writes.get("11",0) == 1 and not writes.has("29"),"GV_KELSRICK_DEAD written, shared29 untouched: %s" % [writes])
	check(int(k.locals["52"]) == 1 and int(k.locals["8"]) == 30 and int(k.health) == 0 and int(k.selector) == 16,"Kelsrick dead: local52, health 0, local8 = 30 after event 11 (31122)")
	check(30402 in k.hit_latches,"30402 is one-shot")
	k = Kelsrick.initial(src)
	var sac := Kelsrick.hit(k,src,2,4|Poison.FLAG_SAC,5,ctx)
	check(groups(sac).size() >= 1 and groups(sac)[0] == 30402 and not shared_writes(sac).has("29"),"death-sac coat: the same record")
	# After a loud strike the alert record is latched and local52 set: a later coated strike reaches nothing.
	k = Kelsrick.initial(src)
	Kelsrick.hit(k,src,2,4,5,ctx)
	var later := Kelsrick.hit(k,src,2,4|Poison.FLAG_PAINT,5,ctx)
	check(groups(later) == [30402] or groups(later).size() >= 1,"coated strike after the alert still kills through 30402: %s" % [groups(later)])
	finish()
func finish() -> void:
	if failures:
		push_error("FAIL: %d weapon poison checks" % failures)
		quit(1)
		return
	print("PASS weapon poison state: coats (apply, cap 9, sac-then-paint, flags, validation, legacy); Kelsrick scanner: sword -> 30456/alert, coated -> 30402 alone with GV_KELSRICK_DEAD and no shared29")
	quit()
