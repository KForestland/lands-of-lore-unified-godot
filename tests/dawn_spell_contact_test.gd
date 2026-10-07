extends SceneTree
const Contact=preload("res://scripts/lol2/dawn_spell_contact.gd")
func _initialize() -> void:
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_contact_native.json"))
	assert(rows.size()==864)
	for row in rows:
		var before: Dictionary=row.duplicate(true)
		var result:=Contact.contact(row.state,row.event)
		assert(not result.has("error") and result.request==row.expected.request)
		for field in row.expected.state: assert(result.state[field]==row.expected.state[field],str(row))
		assert(row==before)
		var roundtrip:=Contact.restore(JSON.parse_string(JSON.stringify(result.state)))
		assert(not roundtrip.has("error") and roundtrip.state==result.state)
		if result.request:
			var repeated:=Contact.contact(roundtrip.state,row.event)
			assert(not repeated.request and repeated.state.done)
	for field in ["last_contact","counter","threshold","heading","done","contact_seen"]:
		var bad: Dictionary=rows[0].state.duplicate(true);bad.erase(field)
		assert(Contact.restore(bad).has("error"))
	for field in ["collision","target","distance","movement_heading","collision_heading"]:
		var bad: Dictionary=rows[0].event.duplicate(true);bad[field]=true
		assert(Contact.contact(rows[0].state,bad).has("error"))
	var lifecycle=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_lifecycle_native.json"))
	assert(lifecycle.size()==144)
	for row in lifecycle:
		var before: Dictionary=row.state.duplicate(true)
		var result:=Contact.update(row.state,row.cancelled,row.child_radius)
		assert(not result.has("error"))
		assert(result.retired==row.expected.retired and result.spawn_child==row.expected.spawn_child)
		var events: Array=[]
		if "allocate" in row.native_calls: events.append("spawn_child")
		if row.expected.retired: events.append("retire")
		assert(result.events==events)
		assert(result.state.done==row.expected.done and result.state.threshold==row.expected.threshold)
		assert(row.state==before)
		var restored:=Contact.restore(JSON.parse_string(JSON.stringify(result.state)))
		assert(restored.state==result.state)
		if result.spawn_child and not result.retired:
			var next:=Contact.update(restored.state,false,row.child_radius)
			assert(not next.spawn_child and not next.retired)
	for value in [-1,true,0.5,256]: assert(Contact.update(rows[0].state,false,value).has("error"))
	print("PASS: 864 native collision and144 lifecycle cases; save continuation, spawn ordering and repeated-contact suppression")
	quit()
