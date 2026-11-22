extends RefCounted
## One exact source-to-cast table for optional rescue hint and admission.
const Book=preload("res://scripts/lol2/player_spell_book.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Globes=preload("res://scripts/lol2/player_stored_globes.gd")
const IDS:=["mists1","prism5"]
static func accepts(id:String)->bool:return id in IDS
static func stored_id(item:Variant)->String:
 if not item is String:return ""
 var globe:Dictionary=Globes.spell(item)
 var id:String=""
 if not globe.is_empty():id=str(globe.school)+str(int(globe.charge))
 else:
  var school:String=Catalog.stored_school(item)
  if Book.STORED_CHARGES.has(school):id=school+str(int(Book.STORED_CHARGES[school]))
 return id if accepts(id) else ""
static func available(book:Dictionary,carried:Array)->bool:
 for id in book.get("learned",[]):
  if id is String and accepts(id):return true
 for item in carried:
  if not stored_id(item).is_empty():return true
 return false
