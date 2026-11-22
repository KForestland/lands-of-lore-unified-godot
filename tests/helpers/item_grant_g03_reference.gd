extends RefCounted
## Independent G03 observations BEFORE WO4/WO5. Original golden files remain
## pinned and unchanged; only exact independently recorded added world fields
## are removed for the old pack/history/owner comparison. Raw saves get a new
## independent byte pin as well. No wildcard ignores or expected-value rewrite.
const PATH="res://tests/fixtures/item_grant_g03_additions_1a795b66.json"
const SHA="bae2e3beca649bb535089fdbd692f1519058bfbee2480bb5fbf0f31fb84e2803"
static var cached:Dictionary={}
static func data()->Dictionary:
 if not cached.is_empty():return cached
 assert(FileAccess.get_sha256(PATH)==SHA,"Independent pre-items G03 reference pin")
 cached=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 assert(cached.version==1 and cached.source_head=="1a795b665830564243a2a08ac68fdcc86b4c17f3","Independent G03 provenance")
 assert(FileAccess.get_sha256("res://tests/fixtures/item_grant_host_saves_20c7797/manifest.json")==cached.original_manifest_sha256,"Original F08 manifest remains immutable")
 for path in cached.catalog_sha256:
  assert(FileAccess.get_sha256("res://"+str(path))==str(cached.catalog_sha256[path]),"Same independently qualified G03 catalogue: "+str(path))
 return cached
static func raw_pin(area:String)->String:return str(data().raw_pins.get(area,""))
static func project(kind:String,name:String,actual:Dictionary)->Dictionary:
 var projected:Dictionary=actual.duplicate(true)
 for addition:Dictionary in data().normalizations[kind].get(name,[]):
  var keys:Array=addition.path
  assert(not keys.is_empty() and "generic_objects" in keys and keys[0] in ["quests","grant_quests"],"Only named added generic world state may be projected")
  var parent:Dictionary=projected
  for index in keys.size()-1:
   assert(parent.has(keys[index]) and parent[keys[index]] is Dictionary,"Recorded world-state parent exists")
   parent=parent[keys[index]]
  var key:String=str(keys[-1])
  assert(parent.has(key) and parent[key]==addition.value,"Actual added world packet equals independent pre-items G03 record: "+kind+"/"+name)
  parent.erase(key)
 return projected
static func records(kind:String,actual:Dictionary)->Dictionary:
 var result:Dictionary=actual.duplicate(true)
 for name in result:
  if kind=="legacy_variants":result[name].loaded=project(kind,str(name),result[name].loaded)
  else:result[name]=project(kind,str(name),result[name])
 return result
