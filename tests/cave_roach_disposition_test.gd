extends SceneTree
## Roach disposition (ROACH_BEHAVIOUR_DECODE_20261028 s5/s6): a Roach that perceives Luther wanders when he is human
## or beast and chooses Destroy (pursue/bite) when he is a lizard (native form rows 20/21/19; r4 2026-10-29 applies the
## lizard row again: owner "if they attack the lizard that is ok"). A landed player hit sets "Attacked by player
## before" to 255 (decays 1/s): toward a human it still wanders (native). The pre-r2 rule chased every awake Roach.
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const HUMAN:=0
const BEAST:=1
const LIZARD:=2
var failures:=0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error("FAIL: "+label)

## Two seconds of steps at 20 units with sight: enough for the old rule to pursue, attack and land a bite.
func run(state: Dictionary, id: String, form: int) -> Dictionary:
	var damage:=0
	var modes: Array=[]
	var goal:=-1
	for i in range(80):
		var step: Dictionary=State.advance_disposed(state,id,0.05,20.0,true,false,30,0,form)
		damage+=int(step.damage);goal=int(step.goal)
		if not int(state.live[id].mode) in modes: modes.append(int(state.live[id].mode))
	return {"damage":damage,"modes":modes,"goal":goal}

func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(State.AI_SOURCE))
	check(data.version==1 and data.goals.weights.size()==30 and data.adjustments.conditions.size()==49,"AI source tables staged")
	# The staged tables are the native-recorded contracts (240+240 DOSBox cases in cave_roach_ai_choice_native).
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_choice_native.json")).contracts
	for part in ["goals","actions"]:
		for field in ["weights","goals","initial_goal_bias"]: check(data[part][field]==native[part][field],"staged %s.%s equals the native contract" % [part,field])
	var adjust: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_adjustments.json"))
	check(data.adjustments.goals==adjust.goals and data.adjustments.conditions==adjust.conditions,"staged adjustment rows equal the native-verified profile")

	for form in [HUMAN,BEAST]:
		var state:=State.initial()
		var r:=run(state,"40",form)
		check(r.goal==State.GOAL_WANDER,"form %d: a perceiving Roach chooses Wander (got %d)" % [form,r.goal])
		check(r.damage==0 and r.modes==[Live.IDLE],"form %d: no pursuit and no bite at 20 units (modes %s, damage %d)" % [form,str(r.modes),r.damage])
	check(State.form_condition(LIZARD)==19 and State.form_condition(HUMAN)==20 and State.form_condition(BEAST)==21,"native form rows 19/20/21 all applied")
	# Lizard (native row 19, Aggr/Attacked +127): a perceiving Roach chooses Destroy on sight, pursues and bites.
	var lizard:=State.initial()
	var l:=run(lizard,"40",LIZARD)
	check(l.goal==State.GOAL_DESTROY,"perceived lizard: Destroy (got %d)" % l.goal)
	check(Live.PURSUE in l.modes or Live.ATTACK in l.modes,"lizard: the Roach pursues/attacks")
	check(l.damage>0,"lizard: the Roach bites")
	# Out of perception the form row does not apply: an unperceived lizard is not attacked.
	check(State.dispose(State.initial(),"40",LIZARD,false)==State.GOAL_WANDER,"an unperceived lizard: Wander")
	# Low health stat (<= 60, F8): Flee when the player is not perceived. Facing a human the native human row
	# keeps Wander (native scorer result, not a port rule).
	var weak:=State.initial();weak.actors["40"].stats[4]=50
	check(State.dispose(weak,"40",HUMAN,false)==State.GOAL_FLEE,"health stat 50, unperceived: Flee")
	weak=State.initial();weak.actors["40"].stats[4]=50
	check(State.dispose(weak,"40",HUMAN,true)==State.GOAL_WANDER,"health stat 50, perceived human: Wander")

	# Unperceived: the form row does not apply; the source bank wanders.
	var far:=State.initial()
	check(State.dispose(far,"40",HUMAN,false)==State.GOAL_WANDER,"an unperceived Roach wanders")

	# Player hit: Attacked-by-player 255, last-hit condition 0, still Wander for a human; decays 1 per second.
	var hit:=State.initial()
	State.player_hit(hit,"41")
	check(int(hit.actors["41"].stats[State.ATTACKED_STAT])==255 and hit.ai.last_hit=="41","a player hit sets Attacked 255 and the last-hit creature")
	var h:=run(hit,"41",HUMAN)
	check(h.goal==State.GOAL_WANDER and h.damage==0,"a Roach hit by a human still wanders and does not bite")
	State.advance_ai(hit,10.0)
	check(int(hit.actors["41"].stats[State.ATTACKED_STAT])==245,"Attacked decays one per game second (got %d)" % int(hit.actors["41"].stats[State.ATTACKED_STAT]))
	State.advance_ai(hit,0.5);State.advance_ai(hit,0.75)
	check(int(hit.actors["41"].stats[State.ATTACKED_STAT])==244 and is_equal_approx(float(hit.ai.clock),0.25),"sub-second remainders carry over")

	# Saves: the disposition packet round-trips; older packets without it stay valid.
	var restored:=State.canonical(JSON.parse_string(JSON.stringify(hit)))
	check(State.validate(restored).is_empty() and restored==State.canonical(hit),"disposition save round trip")
	var legacy:=State.initial()
	check(State.validate(legacy).is_empty() and not legacy.has("ai"),"older saves without the packet stay valid")
	var bad:=restored.duplicate(true);bad.ai.last_hit="999"
	check(not State.validate(bad).is_empty(),"unknown last-hit identity rejected")
	bad=restored.duplicate(true);bad.ai.clock=1.0
	check(not State.validate(bad).is_empty(),"out-of-range clock rejected")
	# A defeated Roach never chooses.
	var dead:=State.initial();State.damage(dead,"42",10)
	check(State.dispose(dead,"42",LIZARD,true)==15,"a defeated Roach does not choose")

	if failures:
		push_error("FAIL: %d cave Roach disposition checks" % failures)
		quit(1)
		return
	print("PASS cave Roach disposition: human/beast wander without biting, a perceived lizard is attacked (native row 19), low health flees when unperceived, human hit stays Wander, unperceived wanders, save packet strict, defeated never chooses")
	quit()
