extends SceneTree
## Read-only runtime catalog facts for the game-wide item census.
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Definitions=preload("res://scripts/lol2/item_definitions.gd")
const Act2=preload("res://scripts/lol2/act2_items_catalog.gd")
const Handlers=preload("res://scripts/lol2/item_handlers.gd")
func _initialize():
 var args:=OS.get_cmdline_user_args()
 assert(args.size()==2 and args[0]=="--out","--out path required")
 assert(Definitions.ready(),"Stage all original definitions first")
 var ids:Array=Catalog.ids("world")
 for id in Act2.all_ids():
  if id not in ids:ids.append(id)
 ids.sort()
 var rows:Array=[]
 for index in Definitions.COUNT:
  var row:Dictionary={"index":index,"definition":Definitions.row(index),"identities":[],"use_route":Handlers.route(index,1),"equip_route":Handlers.route(index,10)}
  for id in ids:
   if Catalog.definition(id)!=index:continue
   row.identities.append({"id":id,"slot":Catalog.slot(id),"use":Catalog.use_kind(id),"scope":Catalog.entry(id).get("origin",""),"stored_school":Catalog.stored_school(id),"defense":Catalog.defense(id)})
  rows.append(row)
 var out:=FileAccess.open(args[1],FileAccess.WRITE)
 assert(out!=null,"Writable census destination required")
 out.store_string(JSON.stringify({"version":1,"definition_count":Definitions.COUNT,"definitions_sha256":FileAccess.get_sha256(Definitions.PATH),"rows":rows},"  ",true,true)+"\n")
 out.close()
 print("PASS exported all ",rows.size()," definitions and ",ids.size()," finite catalog identities; no grants or state changes")
 quit()
