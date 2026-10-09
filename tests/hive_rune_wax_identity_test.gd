extends SceneTree
## Source RUNECL admits held wax by GLOBAL definition "71-Wax" (identity 2925189839): Hive wax and Jungle wax row50.
## - is_wax: both waxes yes; sap, runes, unknown and empty no.
## - Jungle wax alone makes runes with the first-copy dual reward; the exact held wax is consumed, other wax kept.
## - Without a held item the first carried wax is used. Invalid or uncarried held items consume nothing.
## - A repeat copy grants no second reward. Inputs are never mutated; GV_HAS_RUNES is set; Hive pickup history untouched.
const T=preload("res://scripts/lol2/hive_rune_transaction.gd")
const Quests=preload("res://scripts/lol2/act_one_quest_state.gd")
const Entry=preload("res://scripts/lol2/hive_rune_entry_state.gd")
const Items=preload("res://scripts/lol2/hive_rune_items.gd")
const JW:="jungle:item50:Wax"
const SAP:="jungle:item52:Ironwod_sap"
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func lit() -> Dictionary:
	var q:=Quests.initial();q.hive_rune_entry=Entry.initial();q.hive_rune_entry.merge({"room":"RUNECL","lights":true,"marker642_enabled":true},true);return q
func inv(items: Array) -> Dictionary: return {"collected":items,"equipped_item":"","equipped_armor":"","health":30}
func run() -> void:
	if not check(T.is_wax(T.WAX) and T.is_wax(JW) and not T.is_wax(SAP) and not T.is_wax("") and not T.is_wax(Items.PREFIX+"0") and not T.is_wax("jungle:item999:Wax") and not T.is_wax(7),"is_wax identity"): return
	# Jungle wax alone, held.
	var q:=lit();var i:=inv([JW]);var qb:=q.duplicate(true);var ib:=i.duplicate(true)
	var r:=T.copy_wax(q,i,JW)
	if not check(not r.has("error") and q==qb and i==ib,"Jungle wax refused or input mutated: %s"%[r.get("error","")]): return
	if not check(r.consumed==JW and r.inventory.collected.size()==1 and Items.valid(r.inventory.collected[0]) and r.first_copy and r.quests.monastery.globals.GV_HAS_RUNES==1,"Jungle wax exchange outcome"): return
	if not check(r.quests.player_reward_state.player.experience==200 and r.quests.player_magic_reward_state.player.experience==200 and not r.quests.get("hive_wax_collected",false),"First-copy reward/pickup history"): return
	# Both waxes: the held one is consumed, the other kept; repeat copy with the other grants no second reward.
	var both:=T.copy_wax(lit(),inv([T.WAX,JW]),JW)
	if not check(both.consumed==JW and T.WAX in both.inventory.collected and JW not in both.inventory.collected,"Held Jungle wax not the one consumed"): return
	var again:=T.copy_wax(both.quests,both.inventory,T.WAX)
	if not check(not again.has("error") and not again.first_copy and again.quests.player_reward_state==both.quests.player_reward_state and again.quests.player_magic_reward_state==both.quests.player_magic_reward_state and not again.inventory.collected.any(func(x): return T.is_wax(x)),"Repeat copy reward/consumption"): return
	if not check(T.copy_wax(lit(),inv([T.WAX,JW]),T.WAX).consumed==T.WAX,"Held Hive wax not consumed"): return
	# No held item: first carried wax (legacy callers).
	if not check(T.copy_wax(lit(),inv([SAP,JW,T.WAX])).consumed==JW,"First carried wax not used"): return
	# Invalid held items consume nothing.
	var bad:=inv([T.WAX,SAP]);var badb:=bad.duplicate(true)
	if not check(T.copy_wax(lit(),bad,SAP).has("error") and T.copy_wax(lit(),bad,JW).has("error") and T.copy_wax(lit(),inv([SAP])).has("error") and bad==badb,"Invalid/uncarried held item admitted"): return
	var dark:=lit();dark.hive_rune_entry.lights=false
	if not check(T.copy_wax(dark,inv([JW]),JW).has("error"),"Dark inscription admitted Jungle wax"): return
	print("PASS hive_rune_wax_identity_test: is_wax by definition 71-Wax; Jungle wax exchange with first-copy reward; exact held wax consumed; first carried fallback; repeat copy no reward; invalid/uncarried/dark refused; inputs unmutated")
	quit(0)
