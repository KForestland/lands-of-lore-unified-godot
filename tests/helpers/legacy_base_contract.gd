extends RefCounted
## Eight explicitly reviewed pre-G04 schema additions, observed on unchanged
## a95a90c. Old d5 fixture bytes stay immutable; this is not a regenerated golden.
const ROOT:="res://tests/fixtures/saves_d5da60a/areas/"
const PATCH:="res://tests/fixtures/g04_inputs/pre_g04_legacy_additions.json"
static func expected(area:String)->Dictionary:
 var path:=ROOT+area+"_roundtrip.json"
 var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATCH))
 if not manifest.areas.has(area):return original
 var row:Dictionary=manifest.areas[area]
 assert(FileAccess.get_sha256(path)==row.original_sha256,"Untouched original legacy bytes: "+area)
 for patch:Dictionary in row.additions:
  if patch.path in ["/help","/display/creatures"] and "--demo-interface" not in OS.get_cmdline_user_args():continue # Cave demo mode hides its development-only population display.
  var pieces:PackedStringArray=str(patch.path).split("/",false)
  var parent:Dictionary=original
  for i in pieces.size()-1:parent=parent[pieces[i]]
  if patch.was_missing:assert(not parent.has(pieces[-1]),"Independently identified pre-G04 added field")
  else:assert(parent[pieces[-1]]==patch.before,"Independently identified pre-G04 replaced field")
  parent[pieces[-1]]=patch.value
 return original
