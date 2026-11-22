extends RefCounted
## Published per-area census. No absent/copied rows or dedicated-owner rows are activated.
static var _rows: Dictionary = {}
static var _moves: Dictionary = {}
static var _breaks: Dictionary = {}
const PACKETS := {"L9_DR":"l9","L8_SJ":"l8","L12_CM":"l12","L13_RC":"l13","L14_HT":"l14","L16_CA":"l16","L17_HC":"l17","L19_BC":"l19","L20_BB":"l20"}
static var _areas:Dictionary={}
static var _area_moves:Dictionary={}
static var _area_breaks:Dictionary={}
static func rows(area: String) -> Dictionary:
 if area != "L10_DC":
  if not PACKETS.has(area):return {}
  if not _areas.has(area):
   var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/generic_objects_%s.json"%PACKETS[area]))
   if not parsed is Dictionary or not parsed.get("rows") is Array:
    push_error("Generic objects: invalid census for "+area);return {}
   if FileAccess.get_sha256("res://scripts/lol2/native_scripts/"+area+".json")!=str(parsed.get("native_sha256","")):
    push_error("Generic objects: native export differs from the pinned census for "+area);return {}
   var result:Dictionary={}
   for row in parsed.rows:
    if row.get("in_162",false) or row.get("in_57",false) or row.get("generic_motion",false):result["%s:%d"%[row.native_class,int(row.index)]]=row
   _areas[area]=result
  return _areas[area]
 if _rows.is_empty():
  var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/generic_objects_l10.json"))
  if not parsed is Dictionary or not parsed.get("rows") is Array:
   push_error("Generic objects: missing or invalid L10 census; original map frames retained.");return {}
  var doc:Dictionary=parsed
  for row in doc.rows:
   if row.in_162 or row.in_57:_rows["%s:%d"%[row.native_class,int(row.index)]]=row
 return _rows
static func movables(area: String) -> Dictionary:
 if area!="L10_DC":
  if not _area_moves.has(area):
   var result:Dictionary={}
   for row in rows(area).values():
    if (row.get("in_162",false) or row.get("generic_motion",false)) and not row.get("dedicated_owner",false):result[int(row.index)]=row
   _area_moves[area]=result
  return _area_moves[area]
 if _moves.is_empty():
  for ref in rows(area):
   if rows(area)[ref].in_162:_moves[int(rows(area)[ref].index)]=rows(area)[ref]
 return _moves
static func breakables(area: String) -> Dictionary:
 if area!="L10_DC":
  if not _area_breaks.has(area):
   var result:Dictionary={}
   for row in rows(area).values():
    if row.get("in_57",false) and not row.get("dedicated_owner",false):result[int(row.index)]=row
   _area_breaks[area]=result
  return _area_breaks[area]
 if _breaks.is_empty():
  for ref in rows(area):
   if rows(area)[ref].in_57:_breaks[int(rows(area)[ref].index)]=rows(area)[ref]
 return _breaks
