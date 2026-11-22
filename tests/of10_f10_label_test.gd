extends SceneTree
## OF10. Act 2 maps used to file an F10 report as area "Jungle" because they extend the Jungle host.
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const Map = preload("res://scripts/lol2/act2_map.gd")
const Jungle = preload("res://scripts/lol2/jungle_walkthrough.gd")
const Cave = preload("res://scripts/lol2/cave_walkthrough.gd")
const Museum = preload("res://scripts/lol2/museum_walkthrough.gd")
const Halls = preload("res://scripts/lol2/dark_halls.gd")
var host: Node
var jungle: Node
var cave: Node
var museum: Node
var halls: Node
var dropped_ids: Array[int] = []

func _initialize() -> void:
	run.call_deferred()

## Field nodes such as curse are parented in _ready. A host that never enters the tree would keep that script in use.
func drop(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var id := node.get_instance_id()
	if id in dropped_ids:
		return
	dropped_ids.append(id)
	var orphans: Array[Node] = []
	for prop in node.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var extra: Variant = node.get(str(prop.name))
		if extra is Node and is_instance_valid(extra) and extra != node and extra.get_parent() == null:
			orphans.append(extra)
	for extra in orphans:
		drop(extra)
	if is_instance_valid(node):
		node.free()

func release() -> void:
	drop(host)
	host = null
	drop(jungle)
	jungle = null
	drop(cave)
	cave = null
	drop(museum)
	museum = null
	drop(halls)
	halls = null
	await process_frame

func fail(message: String) -> void:
	push_error(message)
	print("FAIL of10 label: ", message)
	await release()
	quit(1)

func run() -> void:
	host = Map.new()
	host.set("area_id", "L10_DC")
	if Diagnostics.host_kind(host) != "Jungle":
		await fail("L10 host dispatch changed")
		return
	var report: Dictionary = Diagnostics.capture(host)
	if report.area != "L10_DC Dracoid Cemetery":
		await fail("L10 area is %s" % report.area)
		return
	if Diagnostics.record(host, "of10", "") != "":
		await fail("record changed the error")
		return
	if str(Diagnostics.last_operation.area) != "L10_DC Dracoid Cemetery":
		await fail("operation area %s" % str(Diagnostics.last_operation.area))
		return
	host.set("area_id", "L9_DR")
	if Diagnostics.area_name(host) != "L9_DR Dracoid Ruins":
		await fail("L9 area is %s" % Diagnostics.area_name(host))
		return
	host.set("area_id", "L12_CM")
	if Diagnostics.area_name(host) != "L12_CM Claw Mountains":
		await fail("L12 area is %s" % Diagnostics.area_name(host))
		return
	drop(host)
	host = null
	jungle = Jungle.new()
	if Diagnostics.area_name(jungle) != "Jungle" or Diagnostics.host_kind(jungle) != "Jungle":
		await fail("the Jungle host changed")
		return
	drop(jungle)
	jungle = null
	cave = Cave.new()
	if Diagnostics.area_name(cave) != "Cave" or Diagnostics.host_kind(cave) != "Cave":
		await fail("Cave area is %s" % Diagnostics.area_name(cave))
		return
	drop(cave)
	cave = null
	museum = Museum.new()
	if Diagnostics.area_name(museum) != "Museum" or Diagnostics.host_kind(museum) != "Museum":
		await fail("Museum area is %s" % Diagnostics.area_name(museum))
		return
	drop(museum)
	museum = null
	halls = Halls.new()
	if Diagnostics.area_name(halls) != "Dark Halls" or Diagnostics.host_kind(halls) != "Jungle":
		await fail("Dark Halls area is %s" % Diagnostics.area_name(halls))
		return
	print("PASS of10 label: Act 2 reports name the map, Cave and Museum keep their names")
	await release()
	quit(0)
