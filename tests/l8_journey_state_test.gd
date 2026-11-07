extends SceneTree
const Journey = preload("res://scripts/lol2/l8_journey_state.gd")
const Native = preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL L8 journey: ",message)
func _initialize() -> void:
	var ownership = JSON.parse_string(FileAccess.get_file_as_string("res://docs/act2_quest_ownership.json"))
	var owners := {}
	for consequence in ownership.consequences:
		check(not owners.has(consequence.id), "one owner per consequence " + str(consequence.id))
		check(not str(consequence.owner).is_empty() and not str(consequence.source).is_empty(), "owner and source recorded")
		owners[consequence.id] = consequence.owner
	check(owners.get("l8.travel.cemetery") == "native:L8_SJ:0:564", "existing native exit retains ownership")
	var state := Journey.initial()
	var inventory: Array = [Journey.BLADE]
	check(not Journey.act(state,inventory,"show_guard",Journey.BLADE).ok,"early admission refused")
	check(not Journey.act(state,inventory,"offer_daniel","wrong").ok,"wrong gift refused")
	check(not Journey.act(state,[],"offer_daniel",Journey.BLADE).ok,"unowned gift refused")
	for action in ["offer_daniel","hopper_interruption","recover_blade","visit_temple","show_guard","offer_daniel"]:
		if action == "recover_blade":
			var occupied: Array = []
			for i in range(Journey.LIMIT): occupied.append("fixture:%d" % i)
			check(not Journey.act(state,occupied,action).ok and state.gift=="dropped", "full inventory preserves dropped blade")
		var result := Journey.act(state,inventory,action,Journey.BLADE)
		check(result.ok,"book step " + action)
		if not result.ok: quit(1); return
		state = result.state
		inventory = result.inventory
		# Every boundary can survive JSON persistence, including the dropped blade.
		state = JSON.parse_string(JSON.stringify(state))
		check(Journey.validate(state).is_empty(),"saved boundary " + action)
	check(Journey.BLADE not in inventory and state.gift=="returned","second delivery consumes blade")
	var full: Array = []
	for i in range(Journey.LIMIT): full.append("fixture:%d" % i)
	var before := state.duplicate(true)
	check(not Journey.act(state,full,"visit_shaman").ok and state==before,"full inventory cannot lose key reward")
	var reward := Journey.act(state,inventory,"visit_shaman")
	check(reward.ok and reward.inventory.count(Journey.KEY)==1,"shaman grants exactly one key")
	check(not Journey.act(reward.state,reward.inventory,"visit_shaman").ok,"duplicate reward refused")
	var corrupt: Dictionary = Journey.initial()
	corrupt.key_awarded = true
	check(not Journey.validate(corrupt).is_empty(),"orphan key history refused")
	# Destination uses the existing original exit group. No arrival or quest seeds.
	# This is a state/exit contract test, not a spatial walk or UI qualification.
	var native = Native.new()
	check(native.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(),"source loaded")
	native.set_global(0x223D6,0) # Existing host environment adapter, not quest completion.
	var exit_result = native.execute_group(0,564)
	check(exit_result.status=="ran" and native.globals.get(0x223C8)==10 and native.globals.get(0x223CC)==1,"original L10 exit destination")
	if failures==0: print("PASS L8 modern first-departure state/exit contract; spatial/UI route not qualified")
	quit(0 if failures==0 else 1)
