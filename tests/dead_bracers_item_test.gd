extends SceneTree
const Item=preload("res://scripts/lol2/dead_bracers_item.gd")
const Catalog=preload("res://scripts/lol2/act2_items_catalog.gd")
var failures:=0
func check(ok: bool,message: String):
 if not ok:failures+=1;printerr("FAIL dead bracers: ",message)
func _initialize():
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dead_bracers_native.json"))
 check(source.cases.size()==512,"all native request/null-live bank vectors")
 for c in source.cases:
  var result:=Item.request(int(c.mode),int(c.before),c.bank)
  check(result.local==c.after and result.result==c.result,"native request "+str(c.mode)+" bank "+str(c.bank))
 check(Catalog.definition(Item.ID)==59,"actual Ruins original bracers definition59")
 for mode in [14,16,18]:check(Item.Handlers.route(59,mode).hosted,"native implemented request "+str(mode))
 check(not Item.Handlers.route(59,1).hosted,"no invented standalone spell")
 var inventory: Array=[Item.ID,"reserved"];var before:=inventory.duplicate()
 check(Item.available(inventory) and inventory==before,"carried book effect preserves inventory")
 inventory.erase(Item.ID)
 check(not Item.available(inventory),"removal immediately ends dead speech")
 check(not Item.available(["jungle:weapon_shop:Gargoyle_Bracers"]),"other bracers cannot grant dead speech")
 check(Item.available(JSON.parse_string(JSON.stringify(before))),"inventory roundtrip restores derived effect")
 check(Catalog.definition("act2:L8_SJ:item25")==59 and Item.available(["act2:L8_SJ:item25"]),"same original definition from another placement has the same effect")
 if failures==0:print("PASS dead bracers512 native replay vectors, handler70 requests, carried/removal/wrong/roundtrip admission; no native local writes")
 quit(0 if failures==0 else 1)
