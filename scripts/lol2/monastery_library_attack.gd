extends RefCounted
## Monastery library (WOMS\MLIB_.WOM) messages 6/7 → 0x98F → 0xF09: the player attacks Dawn in the library.
## Room-framework messages 6/7 come from the player action routines 8523C/84F92 (the same senders as Rashar's death in
## MAGIC); the live host binds Use Weapon / Cast Spell to these messages. This portable planner has native-verified effects
## (docs/mlib-dawn-attack-checks.json, tools/verify_mlib_dawn_attack.py), not a room input.
## First attack (flag190 clear): GV_DAWN_ATTACKED_IN_MONASTERY=1, Luther's soul −1, Dawn relationship −1 then +1 in her
## exit (net 0), flag191 (she is absent from the library afterwards), reaction movie 3/773, NPC18 loop995, flags185/190.
## That global is the precondition of her Hive appearance (hive_dawn20_state.gd, predicate184).
## present = DLL 0x125C (Dawn installed in the room this load); guard = DLL 0x1270 (re-entry latch, per room load).
static func attacked(message: int, present: bool, guard: bool, flags: Dictionary, globals: Dictionary) -> Dictionary:
	var handled:=1 if message==7 else 0
	if guard or not present: return {"handled":handled,"effects":[],"present":present,"guard":guard}
	var g: Dictionary=globals.duplicate()
	var effects: Array=[]
	var f190:=int(flags.get("190",0))!=0
	var f191:=int(flags.get("191",0))!=0
	if f190 and f191: return {"handled":0,"effects":[],"present":present,"guard":true}
	if not f190:
		effects.append_array([["stop_timer"],["arm_timer",900],["set_flag",191],["set_global","GV_DAWN_ATTACKED_IN_MONASTERY",1]])
		for name in ["GV_LUTHERS_SOUL","GV_DAWN_RELATIONSHIP"]:
			g[name]=int(g.get(name,0))-1;effects.append(["set_global",name,g[name]])
	else:
		effects.append_array([["stop_timer"],["set_flag",191],["set_global","GV_DAWN_ATTACKED_IN_MONASTERY",1]])
	# 0xF09: Dawn leaves the library (attacked branch).
	g.GV_DAWN_RELATIONSHIP=int(g.get("GV_DAWN_RELATIONSHIP",0))+1
	effects.append_array([["stop_timer"],["movie",3,773,7],["set_global","GV_DAWN_RELATIONSHIP",g.GV_DAWN_RELATIONSHIP],
		["stop_loop",3,999,7],["stop_npc",0],["npc",0,18,307,254,100,100],["start_loop",18,995,7],["set_flag",185]])
	if not f190: effects.append(["set_flag",190])
	return {"handled":handled,"effects":effects,"present":false,"guard":false}

## Applies the flag/global effects to a monastery quest state (movies/NPC/timer are presentation receipts).
static func apply(state: Dictionary, effects: Array) -> void:
	for e in effects:
		match str(e[0]):
			"set_flag": state.flags[str(int(e[1]))]=1
			"set_global": state.globals[str(e[1])]=int(e[2])
