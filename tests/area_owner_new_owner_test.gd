extends SceneTree
const Registry = preload("res://scripts/lol2/area_owner_registry.gd")
const List = preload("res://tests/area_owners/dummy_list.gd")
class Host extends Node3D:
	var calls := []
	var progression: Node
	var fail := false
class Duplicate extends RefCounted:
	const OWNERS := [{"script": "res://tests/area_owners/dummy_owner.gd"}, {"script": "res://tests/area_owners/dummy_owner.gd", "args": ["Other"]}]
class Two extends RefCounted:
	const OWNERS := [{"script": "res://tests/area_owners/dummy_owner.gd", "restore_order": 2}, {"script": "res://tests/area_owners/second_owner.gd", "attach": "attach_entry", "args": ["Second"], "needs": "progression", "restore_order": 1, "restore_args": [true]}]
class InheritedDuplicate extends RefCounted:
	const OWNERS := [{"script": "res://tests/area_owners/dummy_owner.gd"}, {"script": "res://tests/area_owners/inherited_owner.gd"}]
class InheritedOnly extends RefCounted:
	const OWNERS := [{"script": "res://tests/area_owners/inherited_owner.gd"}]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var registry := Registry.new()
	host.add_child(registry)
	assert(registry.prepare("test", List).is_empty())
	assert(registry.name == "AreaOwners")
	# Claims are available before geometry and before attachment.
	assert(registry.claims_static({"source_index": 777}))
	assert(not registry.claims_collision({"source_index": 777}))
	assert(registry.claims_collision({"source_index": 778}))
	assert(registry.restore_all("load").is_empty() and host.calls.is_empty())
	registry.attach_all(host, "test", "early")
	assert(registry.owners().is_empty())
	registry.attach_all(host, "test", "late")
	registry.attach_all(host, "test")
	assert(registry.owners() == [host.get_node("Dummy")])
	assert(host.get_node("Dummy").get_parent() == host, "sibling names/paths stay intact")
	assert(registry.restore_all("load").is_empty() and host.calls == [&"Dummy"])
	assert(registry.restore_all("arrival").is_empty() and host.calls.size() == 2)
	assert(registry.restore_all("other").is_empty() and host.calls.size() == 2)
	assert(registry.validate_quests({"f16_dummy": {"ok": true}}).is_empty())
	assert(registry.validate_quests({"f16_dummy": false}) == "Invalid dummy.")
	assert(registry.validate_quests({}).is_empty())
	assert(not registry.validate_quests([]).is_empty())
	var duplicate := Registry.new()
	assert(duplicate.prepare("duplicate", Duplicate) == "Duplicate area owner key: f16_dummy")
	duplicate.free()
	duplicate = Registry.new()
	assert(duplicate.prepare("inherited_duplicate", InheritedDuplicate) == "Duplicate area owner key: f16_dummy", "inherited KEY cannot evade duplicate guard")
	duplicate.free()
	host.free()
	# No progression: defer just the guarded owner; the first remains attached once.
	host = Host.new(); root.add_child(host)
	registry = Registry.new(); host.add_child(registry)
	assert(registry.prepare("two", Two).is_empty())
	registry.attach_all(host, "two")
	assert(registry.owners().size() == 1 and not host.has_node("Second"))
	host.progression = Node.new(); host.add_child(host.progression)
	registry.attach_all(host, "two")
	assert(registry.owners().size() == 2)
	assert(registry.claims_static({"source_index": 779}) and registry.claims_collision({"source_index": 779}), "collision defaults to owns")
	assert(registry.restore_all("load").is_empty() and host.calls == ["Second:true", &"Dummy"], "legacy order and restore arguments")
	host.fail = true
	assert(registry.restore_all("load") == "Second refused." and host.calls.size() == 3, "restore errors stop later owners")
	assert(registry.validate_quests({"f16_second": true}).is_empty())
	assert(registry.validate_quests({"f16_second": 1}) == "Invalid second.")
	host.free()
	host = Host.new(); root.add_child(host)
	registry = Registry.new(); host.add_child(registry)
	assert(registry.prepare("inherited", InheritedOnly).is_empty())
	assert(registry.claims_static({"source_index": 777}) and registry.claims_collision({"source_index": 778}))
	assert(not registry.claims_collision({"source_index": 777}), "inherited collision override")
	registry.attach_all(host, "inherited")
	assert(registry.validate_quests({"f16_dummy": {"ok": true}}).is_empty())
	assert(registry.validate_quests({"f16_dummy": false}) == "Invalid dummy.")
	assert(registry.restore_all("load").is_empty() and host.calls == [&"Dummy"], "inherited RESTORE_ON")
	host.free()
	print("PASS new owner via one test-only list: sibling attachment, phases/needs, duplicate KEY, independent claims, restore order/args/errors, one/two-argument validation")
	quit()
