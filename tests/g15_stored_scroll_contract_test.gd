extends SceneTree
const C=preload("res://scripts/lol2/item_catalog.gd")
const H=preload("res://scripts/lol2/item_handlers.gd")
const S=preload("res://scripts/lol2/museum_scroll_state.gd")
const B=preload("res://scripts/lol2/player_spell_book.gd")
const I=preload("res://scripts/lol2/player_item_state.gd")
func _initialize():
 for row in [[148,"heal",31],[75,"spark",32],[149,"summon",12],[150,"mists",34],[151,"prism",33]]:
  var id:String=C.generic_id(row[0])
  assert(C.stored_school(id)==row[1] and C.use_kind(id)=="stored_spell")
  assert(H.route(row[0],1).hosted and H.route(row[0],1).handler==row[2] and not H.route(row[0],5).hosted)
  assert(id in C.consumables())
 assert("heal" in B.schools(B.initial()) and B.learn(B.initial(),"heal").is_empty(),"Healing stays already known; no extra learned level from scrolls")
 assert(H.group_of(31).grade=="UNKNOWN","Heal adapter does not promote the native shared callee")
 assert(H.group_of(32).grade=="UNKNOWN","Hosting a modern adapter never promotes native callee evidence")
 var carried:=[S.IDS[1]];var spent:=[S.IDS[0],S.IDS[4]]
 var before:=[carried.duplicate(),spent.duplicate()]
 var recovered:=S.from_inventory(carried,spent)
 assert(recovered.taken==[true,true,false,false,true] and recovered.consumed==[true,false,false,false,true])
 assert(S.validate(recovered,carried).is_empty() and before==[carried,spent],"Missing Museum receipts derive only from immutable carried/spent evidence")
 var effects:=I.initial();effects.spent=["act2:L14_HT:item20","act2:L9_DR:item12",S.IDS[4]]
 assert(I.validate(effects,[]).is_empty(),"Act2 and Museum consumed source IDs fit saved history")
 assert(not I.validate(effects,[S.IDS[4]]).is_empty(),"A consumed scroll cannot also be carried")
 print("PASS G15 stored mappings/mode1-only/native UNKNOWN/Heal stays already known/Museum receipt reconstruction/consumed ID bounds")
 quit()
