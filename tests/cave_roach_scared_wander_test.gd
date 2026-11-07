extends SceneTree
## Roach r4 (owner 2026-10-29: "walking around and scared of the player, if they attack the lizard that is ok").
## Headless: a perceived human -> Wander, no pursuit, and every scurry leg (adapter, native action-0 movement untraced)
## heads away from him, never pauses, and stays repeatable by seed; outside the leash a scared leg never leads further
## out; a perceived lizard -> Destroy and pursuit; health stat 50 -> Flee while unperceived; the state save round trip stays exact.
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
var failures:=0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error("FAIL: "+label)

func _initialize() -> void:
	# Human near and perceived: Wander, never pursue or bite.
	var human:=State.initial()
	for i in range(80):
		var step: Dictionary=State.advance_disposed(human,"41",0.05,30.0,true,false,30,0,0)
		check(int(step.goal)==State.GOAL_WANDER and int(step.damage)==0 and int(human.live["41"].mode)==Live.IDLE,"human near: Wander, no pursuit/bite (step %d)" % i)
	# Scared legs: away from the player, no pauses, repeatable.
	for away in [Vector3(1,0,0),Vector3(0,0,-1),Vector3(-0.6,0,0.8)]:
		for count in range(40):
			var leg: Dictionary=State.wander_leg("41",count,away,Vector3.ZERO,160.0)
			check(leg.heading!=Vector3.ZERO and Vector3(leg.heading).dot(away)>=0.49,"scared leg %d heads away (dot %.2f)" % [count,Vector3(leg.heading).dot(away)])
			check(State.wander_leg("41",count,away,Vector3.ZERO,160.0)==leg,"scared leg %d repeatable by seed" % count)
	# Outside the leash a scared leg never leads further from the spawn.
	var back:=Vector3(0,0,200)
	for count in range(40):
		var leg: Dictionary=State.wander_leg("41",count,Vector3(0,0,-1),back,160.0)
		check(Vector3(leg.heading).dot(back)>=-0.000001 and Vector3(leg.heading).length()>0.99,"outside the leash, scared leg %d does not lead further out" % count)
	# Unscared legs keep the r2/r3 adapter: some pauses, some runs.
	var pauses:=0
	for count in range(40):
		if State.wander_leg("41",count,Vector3.ZERO,Vector3.ZERO,160.0).heading==Vector3.ZERO: pauses+=1
	check(pauses>0 and pauses<40,"unscared wander keeps pauses and runs (%d pauses)" % pauses)
	# Lizard near and perceived: Destroy and pursuit (native row 19).
	var lizard:=State.initial()
	var pursued:=false
	for i in range(40):
		var step: Dictionary=State.advance_disposed(lizard,"41",0.05,100.0,true,false,30,0,2)
		check(int(step.goal)==State.GOAL_DESTROY,"lizard near: Destroy (step %d got %d)" % [i,int(step.goal)])
		if int(lizard.live["41"].mode)==Live.PURSUE: pursued=true
	check(pursued,"lizard near: the Roach pursues")
	# Health stat 50 -> Flee (F8) while the player is not perceived (the native human row keeps Wander when he is).
	var weak:=State.initial();weak.actors["41"].stats[4]=50
	check(State.dispose(weak,"41",0,false)==State.GOAL_FLEE,"health stat 50, unperceived: Flee")
	# Save round trip exact after the scenario.
	for state in [human,lizard,weak]:
		var restored:=State.canonical(JSON.parse_string(JSON.stringify(State.saved(state))))
		check(State.validate(restored).is_empty() and restored==State.canonical(State.saved(state)),"save round trip exact")
	if failures:
		push_error("FAIL: %d cave Roach scared-wander checks" % failures)
		quit(1)
		return
	print("PASS cave Roach scared wander: human near Wanders with legs away from him (adapter), no pauses while scared, leash kept, lizard Destroy/pursue, low health Flee, exact save round trip")
	quit()
