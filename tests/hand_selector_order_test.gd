extends SceneTree
## Headless: owner r12e report 1 pack (19 items, Jungle wax 14th). The RUNECL selector order lists the wax first and the
## Monastery order lists rune copies first; every other item keeps its carried order and nothing is lost or duplicated.
const Order = preload("res://scripts/lol2/hand_selector_order.gd")
const Transaction = preload("res://scripts/lol2/hive_rune_transaction.gd")
const Runes = preload("res://scripts/lol2/hive_rune_items.gd")
const PACK := ["cave:captain:Short_Sword","cave:guard52:Guard_Shield","cave:guard52:Short_Sword","cave:prop1050:Ancients_Stone","cave:prop146:harvest1:Stalagmite","cave:prop149:harvest1:Stalagmite","cave:prop641:harvest1:Stalagmite","cave:prop792:harvest1:Cave_Aloe","cave:prop792:harvest2:Cave_Aloe","cave:prop792:harvest3:Cave_Aloe","draracle/prop/1108/sample","hive:runes:Ancients_Stone","jungle:item0:Snare","jungle:item50:Wax","monastery:item94:Iron_Flute","museum:item10:Mail_Shirt","museum:item11:Fine_Longsword","museum:item8:Champion_Stone","museum:item9:Champion_Stone"]
func _initialize() -> void:
	var hive: Array = Order.wanted_first(PACK,Transaction.is_wax)
	if hive[0] != "jungle:item50:Wax": return fail("RUNECL order does not start with the wax: %s" % [hive])
	var rest: Array = PACK.duplicate(); rest.erase("jungle:item50:Wax")
	if hive.slice(1) != rest: return fail("RUNECL order changed the rest of the pack")
	var with_runes: Array = PACK.duplicate(); with_runes.erase("jungle:item50:Wax"); with_runes.append("hive:Wax_runes:0")
	if not Runes.valid("hive:Wax_runes:0"): return fail("Fixture rune id is not a valid rune copy")
	var monastery: Array = Order.wanted_first(with_runes,Runes.valid)
	if monastery[0] != "hive:Wax_runes:0" or monastery.size() != with_runes.size(): return fail("Monastery order does not start with the runes: %s" % [monastery])
	if Order.wanted_first(rest,Transaction.is_wax) != rest: return fail("Order changed a pack without wax")
	print("PASS hand selector lists the wanted item first")
	quit(0)
func fail(message: String) -> void:
	push_error(message)
	quit(1)
