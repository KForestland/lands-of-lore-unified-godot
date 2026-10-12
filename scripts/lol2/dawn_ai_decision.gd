extends RefCounted
## Native AACD4..AAE7E. Effective stats, world admission context and RNG are
## supplied by the actor owner. Does not commit AI, cast, debit mana or run tail.
const Goals=preload("res://scripts/lol2/hive_ai_goal_choice.gd")
const Actions=preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Spells=preload("res://scripts/lol2/hive_ai_spell_choice.gd")
const Selection=preload("res://scripts/lol2/dawn_spell_selection.gd")
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
const Numbers=preload("res://scripts/lol2/hive_player_conditions.gd")
const SOURCE="res://scripts/lol2/dawn_ai_profile.json"
var _goals:=Goals.new()
var _actions:=Actions.new()
var _spells:=Spells.new()
var _window:=0
var _ready:=false

func configure(profile: Variant) -> String:
	if not profile is Dictionary or not Numbers._integer(profile.get("window"),0,65535): return "Invalid Dawn profile."
	# Configure temporary objects so a rejected profile cannot partially replace it.
	var goals:=Goals.new();var actions:=Actions.new();var spells:=Spells.new()
	for pair in [[goals,"goals"],[actions,"actions"],[spells,"spells"]]:
		var error: String=pair[0].configure(profile.get(pair[1]))
		if not error.is_empty(): return error
	_goals=goals;_actions=actions;_spells=spells;_window=int(profile.window);_ready=true
	return ""

func configure_source() -> String:
	return configure(JSON.parse_string(FileAccess.get_file_as_string(SOURCE)))

func decide(saved: Variant, stats: Variant, context: Variant, rng: Variant) -> Dictionary:
	if not _ready: return {"error":"Dawn profile unavailable."}
	if not saved is Dictionary or not context is Dictionary: return {"error":"Invalid Dawn decision context."}
	for field in ["b5","a9","ab","spell","reason"]:
		if not Numbers._integer(saved.get(field),0,255): return {"error":"Invalid Dawn decision field: "+field}
	if not Numbers._integer(saved.get("b8"),0,4294967295): return {"error":"Invalid Dawn decision flags."}
	if not stats is Array or stats.size()!=30: return {"error":"Invalid Dawn stat bank."}
	for value in stats:
		if not Numbers._integer(value,0,255): return {"error":"Invalid Dawn stat byte."}
	var owner: Dictionary=context.duplicate(true)
	owner.spell=7;owner.b8=int(saved.b8);owner.previous_reason=int(saved.reason)
	var checked:=Admission.admit(owner)
	if checked.has("error"): return checked
	var state: Dictionary=saved.duplicate(true)
	for field in ["b5","a9","ab","spell","reason","b8"]: state[field]=int(state[field])
	if (state.b5&1)!=0: return {"state":state,"accepted":false,"scanned":false,"rng_requested":false}
	var goal_result:=_goals.update_pending(state,stats)
	if goal_result.has("error"): return goal_result
	state=goal_result.state
	var action_result:=_actions.update_pending(state,stats)
	if action_result.has("error"): return action_result
	state=action_result.state
	var previous:=int(state.spell)
	state.spell=0
	if int(owner.mana)==0: return {"state":state,"accepted":false,"scanned":false,"rng_requested":false}
	var scored:=_spells.score(stats,state.a9)
	if scored.has("error"): return scored
	if scored.candidates.is_empty(): return {"state":state,"accepted":false,"scanned":false,"rng_requested":false}
	var scores: Dictionary={}
	for spell in scored.candidates: scores[str(spell)]=scored.scores[spell]
	var selected:=Selection.scan(owner,scores,scored.maximum,_window,previous,rng,scored.candidates)
	if selected.has("error"): return selected
	state.spell=selected.stored_choice;state.b8=selected.b8
	if not selected.attempts.is_empty(): state.reason=int(selected.attempts[-1].reason)
	return {"state":state,"accepted":selected.accepted,"scanned":true,"rng_requested":selected.rng_requested}
