extends SceneTree
## Headless Rashar state: source handler scripts, host timer, saves and legacy data.
const State = preload("res://scripts/lol2/magic_shop_state.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func roundtrip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))
func finish_script(state: Dictionary) -> Array:
	var effects: Array = []
	for step in range(64):
		if not State.active(state): break
		effects.append_array(State.advance(state,0.5))
	return effects
func kinds(effects: Array) -> Array:
	var out: Array = []
	for e in effects: out.append(e[0])
	return out
func _run() -> void:
	# Legacy save: first MAGIC format without the new fields still loads.
	var legacy := {"room":"","conversation":{"sequence":"","cursor":0,"elapsed":0.0},"flags":{"49":0,"52":0,"53":0,"54":0,"55":0,"56":0,"57":0,"58":1},"timer_armed":true}
	check(State.validate(roundtrip(legacy)).is_empty(),"legacy save rejected")
	check(State.normalize(legacy.duplicate(true)).timer_left == State.TIMER_SECONDS,"legacy armed timer not restored")
	var s := State.initial()
	check(State.validate(roundtrip(s)).is_empty(),"initial invalid")
	# First visit: intro, then the host deadline (600 ticks) arms.
	check(State.enter(s) and s.conversation.sequence == "MAGIC","intro did not start")
	var host := []
	for step in range(200): host.append_array(State.advance(s,1.0))
	check(host == [["mana_debit",1000]] and s.timer_armed and s.timer_left == State.TIMER_SECONDS,"intro end effects/timer")
	check(State.validate(roundtrip(s)).is_empty(),"completed intro invalid")
	# Empty-hand click on Rashar: host stop then re-arm (flag53 set, flag55 clear).
	State.tick_timer(s,4.0)
	check(kinds(State.offer(s,"","",false)) == [] and s.timer_armed and s.timer_left == State.TIMER_SECONDS,"empty offer did not re-arm")
	# Region quips: once per trigger bit per room load.
	check(State.click_region(s,0) == [] and State.script_active(s) and s.script.handler == "quip","quip did not start")
	var quip_line: int = s.script.args.line
	check(quip_line in [56,21,27,58,26,33,57,20],"quip line")
	var saved := roundtrip(s)
	check(State.validate(saved).is_empty(),"mid-quip save invalid")
	finish_script(s)
	check(State.click_region(s,0) == [] and not State.script_active(s),"second quip for the same bit played")
	check(int(s.quip_mask) & 0x100 != 0,"quip bit missing")
	# In-room expiry after the current movie: 430/431, flag55, exit.
	State.tick_timer(s,State.TIMER_SECONDS)
	check(State.poll_timer(s) == [] and s.script.handler == "timer" and not s.timer_armed,"timer script did not start")
	host = finish_script(s)
	check(host == [["exit_room"]] and s.room == "" and s.flags["55"] == 1,"timer exit")
	check(int(s.quip_mask) & 0x100 != 0,"trigger bits cleared before the next load")
	# Second visit: source 440/441 greeting; trigger bits reset on load.
	check(State.enter(s) and s.conversation.sequence == "MAGIC_RETURN" and int(s.quip_mask) & 0x1f00 == 0,"return greeting/reset")
	for step in range(20): State.advance(s,1.0)
	# Exit request (message8) sets flag56.
	check(State.leave(s) and s.room == "" and s.flags["56"] == 1,"exit request flag56")
	# Third visit is silent (56 set, 57 clear).
	check(State.enter(s) and s.conversation.sequence == "","third visit not silent")
	# Pickups: War cluster then Luther 2:452; save mid-line; flags must agree.
	var result := State.click_sprite(s,0)
	check(result[0] and result[1] == [["give_item","124-War cluster",0]] and s.flags["51"] == 1,"war cluster pickup")
	check(State.script_active(s),"pickup line not playing")
	saved = roundtrip(s)
	check(State.validate(saved).is_empty(),"mid-pickup save invalid")
	saved.flags["51"] = 0
	check(not State.validate(saved).is_empty(),"lost pickup flag accepted")
	finish_script(s)
	check(not State.click_sprite(s,0)[0],"hidden sprite picked twice")
	var gifts := 0
	for n in range(3):
		var crystal := State.click_sprite(s,[4,3,2][n])
		gifts += 1 if crystal[1] == [["give_item","57a-Fire crstl",4]] else 0
		finish_script(s)
	check(gifts == 3 and s.flags["46"] == 1 and s.flags["47"] == 1 and s.flags["48"] == 1,"fire crystal chain")
	# Broken Thohan with flag49 clear: orb knowledge after line427.
	check(State.offer(s,"12-Tho Broken","test:broken",false) == [],"knowledge offer leading effects")
	var knowledge_at := -1
	for step in range(200):
		var effects := State.advance(s,0.25)
		if ["set_global","GV_KNOWLEDGE_OF_POWER_ORB",1] in effects: knowledge_at = int(s.script.cursor)
		if not State.active(s): break
		if knowledge_at < 0: check(State.validate(roundtrip(s)).is_empty(),"mid-knowledge save invalid")
	check(knowledge_at == 7 and s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1,"knowledge global order")
	# Power orb held with the broken Thohan carried: flag49, soul+1, orb consumed.
	host = State.offer(s,"83-Power orb","test:orb",true)
	check(host == [["consume_held","test:orb"],["set_global","GV_LUTHERS_SOUL",1]] and s.flags["49"] == 1,"orb offer")
	finish_script(s)
	# Now the broken Thohan is exchanged for the fixed one after 443/444.
	host = State.offer(s,"12-Tho Broken","test:broken",false)
	check(host == [["consume_held","test:broken"],["award_fighting",100]],"fixed offer leading effects")
	host = finish_script(s)
	check(host == [["give_item","21-Tho fixed",0]],"fixed Thohan after line444")
	# Any other held item: Rashar's refusal line429.
	State.offer(s,"94-Iron flute","test:flute",false)
	check(s.script.handler == "offer" and State.script_effects(s.script.handler,s.script.args)[1] == ["movie",30,429,6],"refusal")
	finish_script(s)
	# Leave before a re-armed deadline; the stale deadline preempts the next entry.
	s.flags["55"] = 0; s.flags["56"] = 0; s.flags["57"] = 0
	State.offer(s,"","",false)
	check(s.timer_armed,"re-arm for stale deadline case")
	check(State.leave(s) and s.flags["55"] == 1,"leave with armed timer")
	State.tick_timer(s,30.0)
	check(State.validate(roundtrip(s)).is_empty(),"expired-outside save invalid")
	check(State.enter(s) and s.script.handler == "timer" and s.conversation.sequence == "","stale deadline did not preempt entry")
	finish_script(s)
	check(s.room == "" and s.flags["56"] == 1,"stale deadline exit")
	# Death (messages6/7): flag52 and soul-1; offers and dialogue stop.
	check(State.enter(s),"enter before death")
	for step in range(20): State.advance(s,1.0)
	var soul: int = s.globals.GV_LUTHERS_SOUL
	host = State.kill(s,7)
	check(host == [["set_global","GV_LUTHERS_SOUL",soul-1]] and s.flags["52"] == 1,"death effects")
	finish_script(s)
	check(State.offer(s,"12-Tho Broken","test:broken",false) == [] and not State.active(s),"dead Rashar accepted an offer")
	State.leave(s)
	check(State.enter(s) and s.conversation.sequence == "","dead Rashar spoke on entry")
	# Structural rejection.
	var bad := roundtrip(s)
	bad.script = {"handler":"offer","args":{"held":"","held_id":"","has_broken":false,"soul":0,"flags":{}},"cursor":0,"elapsed":0.0}
	check(not State.validate(bad).is_empty(),"non-movie script cursor accepted")
	bad = roundtrip(s)
	bad.room = ""
	bad.script = {"handler":"quip","args":{"line":56},"cursor":0,"elapsed":0.1}
	check(not State.validate(bad).is_empty(),"script outside room accepted")
	bad = roundtrip(s)
	bad.pending_items = ["83-Power orb"]
	check(not State.validate(bad).is_empty(),"foreign pending item accepted")
	if failures:
		push_error("FAIL: %d Rashar state checks" % failures)
		quit(1)
		return
	print("PASS: Rashar handler scripts, host timer (in-room expiry, stale deadline on re-entry), offers, pickups, quips, death and save validation")
	quit()
