extends SceneTree
const Registry = preload("res://scripts/lol2/area_owner_registry.gd")
const HOSTS := ["act2_map.gd", "darker_jungle.gd", "dragon_level.gd"]
var scripts := {}
func violation(source: String) -> bool:
	var resource := RegEx.new()
	assert(resource.compile("(?:preload|load)\\s*\\(\\s*[\"']res://scripts/lol2/([^\"']+\\.gd)[\"']\\s*\\)") == OK)
	var restore := RegEx.new()
	assert(restore.compile("get_node(?:_or_null)?\\s*\\(\\s*[\"']L[0-9]+[^\"']*[\"']\\s*\\)\\s*\\.\\s*(?:restore\\s*\\(|call\\s*\\(\\s*[\"']restore[\"'])") == OK)
	for found in resource.search_all(source):
		if scripts.has(found.get_string(1)): return true
	return restore.search(source) != null
func _initialize() -> void:
	for area in Registry.AREAS:
		for row in Registry.definition_for(area).get_script_constant_map().OWNERS: scripts[row.script] = true
	for host in HOSTS:
		var source := FileAccess.get_file_as_string("res://scripts/lol2/" + host)
		assert(not violation(source), host + " regained a hand owner preload/restore list")
		assert(source.contains("area_owners.attach_all(") and source.contains("area_owners.restore_all(") and source.contains("area_owners.claims_static(") and source.contains("area_owners.claims_collision("), host + " registry delegation")
	for mutant in [
		'preload("res://scripts/lol2/l10_main_gate.gd").attach(self)',
		'load ( "res://scripts/lol2/l13_elevator.gd" ).attach_lift(self)',
		"const Owner = preload('res://scripts/lol2/l8_tree.gd')\nOwner.attach(self)",
		'preload("res://scripts/lol2/placed_vqa_billboard.gd").attach_dawn(self)',
		'get_node("L12FrozenBow").restore()',
		"get_node_or_null ( 'L9Escape' ).restore(true)",
		'get_node("L8TreeBridge").call("restore")']:
		assert(violation(mutant), mutant)
	assert(not violation('preload("res://scripts/lol2/act2_world_items.gd").attach(self, area_id)'))
	assert(not violation('get_node("L12Citadel").arm(id)'))
	print("PASS converted host source policy and seven mutation probes: no hand owner loads/attach aliases or named restore lists; engine parts/actions allowed")
	quit()
