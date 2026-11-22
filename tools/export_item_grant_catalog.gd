extends SceneTree
## Build-time metadata only. Run through the lane's guarded Godot launcher.
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
func _initialize():
 var args:=OS.get_cmdline_user_args()
 assert(args.size()==2 and args[0]=="--out","--out path is required")
 var rows:Array=[]
 for id:String in Items.all_ids():
  var row:Dictionary=Items.row(id)
  assert(not row.is_empty() and row.has("definition"),id)
  rows.append({"id":id,"area":id.get_slice(":",1),"definition":int(row.definition),"identity":int(row.get("identity",0))})
 var data:Dictionary={"version":1,"rule":"Catalog facts only, no new grants; includes placements, finite specials and charged identities.","placements_sha256":FileAccess.get_sha256("res://scripts/lol2/act2_items_source.json"),"definitions_sha256":FileAccess.get_sha256("res://assets/lol2/generated/items/definitions.json"),"items":rows}
 var file:=FileAccess.open(args[1],FileAccess.WRITE);assert(file!=null,args[1]);file.store_string(JSON.stringify(data,"  ",true,true)+"\n");file.close()
 print("PASS exported ",rows.size()," finite Act2 catalog identities")
 quit()
