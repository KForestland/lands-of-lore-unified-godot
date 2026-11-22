extends SceneTree
const Belt=preload("res://scripts/lol2/item_belt_state.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
func _initialize():
 var value:=Belt.initial()
 var owned:=["act2:L14_HT:item68","act2:L10_DC:item44","act2:L10_DC:item45:charged:yellow","museum:control87:Sk_key","act2:L13_RC:item53"]
 assert(Belt.validate(value).is_empty())
 assert(Belt.put(value,owned[0],owned,0));assert(Belt.put(value,owned[1],owned,1))
 assert(Belt.put(value,owned[0],owned,4) and value.slots[0]==-1)
 value.active=4;assert(Belt.roll(value,owned,1) and value.active==1)
 assert(not Belt.put(value,"fake",owned))
 assert(Belt.validate(Belt.canonical(value)).is_empty())
 var bad:=value.duplicate(true);bad.slots[2]=bad.slots[1];assert(not Belt.validate(bad).is_empty())
 bad=value.duplicate(true);bad.version="1";assert(not Belt.validate(bad).is_empty())
 for field in ["active","clock"]:
  bad=value.duplicate(true);bad[field]=1.5;assert(not Belt.validate(bad).is_empty())
 bad=value.duplicate(true);bad.ages[0]=999;assert(not Belt.validate(bad).is_empty())
 value=Belt.initial()
 for id in owned:Belt.pickup(value,id,owned)
 assert(98 in value.slots and 99 in value.slots and Catalog.definition(owned[3]) in value.slots and not 118 in value.slots)
 assert(Belt.resolve(value,2,[]).is_empty(),"Belt references cannot create owned items")
 var packet:=preload("res://scripts/lol2/player_item_state.gd").initial();packet.belt=value
 assert(preload("res://scripts/lol2/player_item_state.gd").validate(packet,owned).is_empty())
 assert(preload("res://scripts/lol2/player_item_state.gd").canonical(packet).belt==value)
 var pack:=["act2:L14_HT:item68","act2:L13_RC:item53","act2:L10_DC:item44","act2:L10_DC:item45:charged:yellow","museum:control87:Sk_key","act2:L10_DC:item43:charged:white"]
 value=Belt.initial()
 for i in 5:assert(Belt.put(value,pack[i],pack,i))
 assert(Belt.pickup(value,pack[5],pack) and value.slots[0]==100 and pack[0] in pack,"Full belt evicts oldest nonquest reference, never consumes it")
 var body:="act2:L14_HT:hopper_corpse91";assert(Belt.put(value,body,[body],4))
 assert(Belt.validate(Belt.canonical(value)).is_empty() and Belt.resolve(value,4,[body])==body,"Quest corpses without a native item definition still have exact saved references")
 print("PASS item belt shape/bounds/unique definitions/move/wrap/skip/owned-reference-only/old-state optional/save canonical")
 quit()
