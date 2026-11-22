extends Node
## Ordered, declarative owners; the level still owns engine services and geometry.
## String resource paths deliberately avoid an eager preload graph through hosts/saves.
const AREAS := ["L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB"]
const SCRIPT_ROOT := "res://scripts/lol2/"
var _area := ""
var _definition: Script
var _entries: Array[Dictionary] = []
var _attached := {}
var _static_claims := []
var _collision_claims := []

static func definition_for(area: String) -> Script:
 if area not in AREAS: return null
 return load(SCRIPT_ROOT + "area_owners/" + area + ".gd") as Script

static func method(script: Script, member: String) -> Dictionary:
 var current := script
 while current != null:
  for row in current.get_script_method_list():
   if row.name == member and int(row.flags) & METHOD_FLAG_STATIC: return row
  current = current.get_base_script()
 return {}

static func constants_for(script: Script) -> Dictionary:
 var chain: Array[Script] = []
 var current := script
 while current != null:
  chain.push_front(current)
  current = current.get_base_script()
 var result := {}
 for part in chain: result.merge(part.get_script_constant_map(), true)
 return result

func prepare(area: String, definition: Script = null) -> String:
 if _area == area: return ""
 if not _attached.is_empty(): return "Cannot change a live area owner registry."
 if definition == null: definition = definition_for(area)
 if definition == null: return "Unknown owner area: " + area
 var declarations: Variant = definition.get_script_constant_map().get("OWNERS")
 if not declarations is Array: return "Missing area owner list: " + area
 var entries: Array[Dictionary] = []
 var keys := {}
 for declaration in declarations:
  if not declaration is Dictionary or not declaration.get("script") is String: return "Invalid area owner declaration: " + area
  var path: String = declaration.script
  if not path.begins_with("res://"): path = SCRIPT_ROOT + path
  var script := load(path) as Script
  if script == null: return "Missing area owner: " + path
  var constants := constants_for(script)
  var key: String = declaration.get("key", constants.get("KEY", ""))
  if not key.is_empty():
   if keys.has(key): return "Duplicate area owner key: " + key
   keys[key] = true
  var entry: Dictionary = declaration.duplicate(true)
  entry["resource"] = script
  entry["constants"] = constants
  entry["key"] = key
  entries.append(entry)
 _area = area
 _definition = definition
 _entries = entries
 _static_claims = _claim_calls("static")
 _collision_claims = _claim_calls("collision")
 name = "AreaOwners"
 return ""

func attach_all(host: Node, area: String, phase: String = "") -> void:
 var error := prepare(area)
 assert(error.is_empty(), error)
 if not error.is_empty(): return
 for i in _entries.size():
  var entry: Dictionary = _entries[i]
  if _attached.has(i) or (not phase.is_empty() and entry.get("phase", "late") != phase): continue
  if entry.get("needs", "") == "progression" and host.get("progression") == null: continue
  var script: Script = entry.resource
  var node: Variant
  if entry.get("factory", "") == "new":
   node = script.new()
   node.set("host", host)
   host.add_child(node)
  else:
   var args: Array = [host]
   args.append_array(entry.get("args", []))
   node = script.callv(entry.get("attach", "attach"), args)
  if is_instance_valid(node) and node is Node: _attached[i] = node

func owners() -> Array[Node]:
 var result: Array[Node] = []
 for i in _entries.size():
  var node: Variant = _attached.get(i)
  if is_instance_valid(node): result.append(node)
 return result

func _claim_calls(field: String) -> Array:
 var calls := []
 for entry in _entries:
  var script: Script = entry.resource
  var methods: Array = entry.get(field, [])
  if not entry.has(field):
   if field == "collision" and not method(script, "owns_collision").is_empty(): methods = ["owns_collision"]
   elif not method(script, "owns").is_empty(): methods = ["owns"]
  for member in methods: calls.append([script, member])
 var member := "claims_collision" if field == "collision" else "claims_static"
 if not method(_definition, member).is_empty(): calls.append([_definition, member])
 return calls
func _claims(face: Dictionary, collision: bool) -> bool:
 for call in (_collision_claims if collision else _static_claims):
  if call[0].call(call[1], face): return true
 return false
func claims_static(face: Dictionary) -> bool: return _claims(face, false)
func claims_collision(face: Dictionary) -> bool: return _claims(face, true)

func restore_all(reason: String) -> String:
 var ordered := []
 for i in _entries.size():
  var entry: Dictionary = _entries[i]
  var node: Variant = _attached.get(i)
  if is_instance_valid(node) and reason in entry.get("restore_on", entry.constants.get("RESTORE_ON", [])): ordered.append(i)
 ordered.sort_custom(func(a: int, b: int): return int(_entries[a].get("restore_order", a + 1000)) < int(_entries[b].get("restore_order", b + 1000)))
 for i in ordered:
  var result: Variant = _attached[i].callv("restore", _entries[i].get("restore_args", []))
  if result is String and not result.is_empty(): return result
 return ""

func validate_quests(quests: Variant) -> String:
 if not quests is Dictionary: return "Invalid area owner quests."
 for entry in _entries:
  var key: String = entry.key
  if key.is_empty() or not quests.has(key): continue
  var script: Script = entry.resource
  var member: String = entry.get("validate", "validate")
  var validator := method(script, member)
  if validator.is_empty(): continue
  var args: Array = [quests[key]]
  if validator.args.size() == 2: args.append(quests)
  var result: String = script.callv(member, args)
  if not result.is_empty(): return result
 return ""

static func validate_all_quests(quests: Variant) -> String:
 if not quests is Dictionary: return "Invalid area owner quests."
 for area in AREAS:
  var registry = load(SCRIPT_ROOT + "area_owner_registry.gd").new()
  var error: String = registry.prepare(area)
  if error.is_empty(): error = registry.validate_quests(quests)
  registry.free()
  if not error.is_empty(): return error
 return ""
