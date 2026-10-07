extends SceneTree
const Transaction = preload("res://scripts/lol2/hive_rune_transaction.gd")
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const Entry = preload("res://scripts/lol2/hive_rune_entry_state.gd")
func _initialize():
	var quests := Quests.initial()
	quests.hive_rune_entry = Entry.initial()
	quests.hive_rune_entry.merge({"room":"RUNECL","lights":true,"marker642_enabled":true},true)
	var inventory := {"collected":[Transaction.WAX],"equipped_item":"","equipped_armor":"","health":30}
	var before := quests.duplicate(true)
	var result := Transaction.copy_wax(quests,inventory)
	if result.has("error") or quests != before or inventory.collected != [Transaction.WAX]:
		push_error("Copy failed or mutated input: "+str(result)); quit(1); return
	if result.quests.player_reward_state.player.experience != 200 or result.quests.player_magic_reward_state.player.experience != 200 or result.inventory.health != 30:
		push_error("First-copy rewards or legacy health changed incorrectly"); quit(1); return
	var first := result.duplicate(true)
	result.inventory.collected.append(Transaction.WAX)
	result = Transaction.copy_wax(result.quests,result.inventory)
	if result.has("error") or result.first_copy or result.inventory.collected.size() != 2 or result.quests.player_reward_state != first.quests.player_reward_state or result.quests.player_magic_reward_state != first.quests.player_magic_reward_state:
		push_error("Repeat-copy reward/instance handling differs"); quit(1); return
	var dark := quests.duplicate(true)
	dark.hive_rune_entry.lights = false
	if not Transaction.copy_wax(dark,inventory).has("error"):
		push_error("Dark inscription admitted"); quit(1); return
	quests.player_magic_reward_state = {"version":1,"player":{"experience":0,"level":31,"maximum":20,"mana":20}}
	if not Transaction.copy_wax(quests,inventory).has("error") or inventory.collected != [Transaction.WAX]:
		push_error("Invalid progression consumed wax"); quit(1); return
	print("PASS: atomic wax/rune transaction, first-only dual rewards, repeat copies and invalid-state rollback")
	quit()
