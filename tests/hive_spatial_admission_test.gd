extends SceneTree
const Spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
const Bridge = preload("res://scripts/lol2/hive_executioner_action.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void:
	var bearings = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_bearing_native.json"))
	assert(bearings.size()==1137)
	for row in bearings: assert(Spatial.bearing(row.points).bearing==row.bearing,str(row)+str(Spatial.bearing(row.points)))
	var perception_helpers = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_helpers_native.json"))
	assert(perception_helpers.regions.size()==63 and perception_helpers.levels.size()==70)
	for row in perception_helpers.regions:
		assert(preload("res://scripts/lol2/hive_perception.gd").region_value(row.counter,row.stamp).value==row.expected)
	for row in perception_helpers.levels:
		assert(preload("res://scripts/lol2/hive_perception.gd").player_level(row.thresholds,row.value).value==row.expected)
	var composed_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_composed_native.json"))
	assert(composed_rows.size()==1024)
	for row in composed_rows:
		var whole_perception: Dictionary = preload("res://scripts/lol2/hive_perception.gd").evaluate_player(row.actor,row.context)
		assert(not whole_perception.has("error"),str(whole_perception))
		assert(whole_perception.result==row.result and whole_perception.calls==row.calls,str(row)+str(whole_perception))
		for field in row.expected: assert(whole_perception.state[field]==row.expected[field],field+str(row)+str(whole_perception))
	var channel_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_channels_native.json"))
	assert(channel_rows.size()==960)
	for row in channel_rows:
		var channel_actor := {"byte60":row.old,"byte5f":row.old,"byte5a":row.old,"b7":9}
		var channel_context := {"flags":2,"whole":row.whole,"region_value":row.region_value,"ranges":[64,128,128,128,128,128],"level55":row.level,"level51":row.level,"visibility":row.visibility,"cached":row.cached}
		var middle: Dictionary = preload("res://scripts/lol2/hive_perception.gd").player_channels(channel_actor,channel_context)
		assert(not middle.has("error"),str(middle))
		assert(middle.flags==row.expected.flags and middle.calls==row.calls,str(row)+" => "+str(middle))
		for field in ["byte60","byte5f","byte5a","b7"]: assert(middle.state[field]==row.expected[field],field+str(row)+str(middle))
		assert(channel_actor.b7==9 and channel_actor.byte60==row.old)
	var finish_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_finish_native.json"))
	assert(finish_rows.size()==1536)
	for row in finish_rows:
		var before_finish := {"b4":row.b4,"b5":row.b5,"byte51":row.byte51,"byte52":row.byte52,"byte61":row.byte61,"word70":row.mode}
		var finished_perception: Dictionary = preload("res://scripts/lol2/hive_perception.gd").finish_player(before_finish,row.flags,row.facing)
		assert(not finished_perception.has("error"))
		for field in ["byte51","byte52","b5"]: assert(finished_perception.state[field]==row.expected[field])
		assert(before_finish.byte51==row.byte51 and before_finish.b5==row.b5)
	var facing_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_facing_native.json"))
	assert(facing_rows.size()==720)
	for row in facing_rows:
		var facing_context: Dictionary = row.duplicate(true)
		facing_context.near_range=128;facing_context.falloff=128;facing_context.byte61=77
		var channel: Dictionary = preload("res://scripts/lol2/hive_perception.gd").facing_channel(facing_context)
		assert(not channel.has("error"),str(channel))
		for field in ["facing","queried","flags","byte61","strength"]:
			assert(channel[field]==row[field],field+": "+str(row)+" => "+str(channel))
	var perception_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_perception_distance_native.json"))
	assert(perception_rows.size()==360)
	for row in perception_rows:
		var measured: Dictionary = preload("res://scripts/lol2/hive_perception.gd").distance_gate(row.prior,row.distance,row.z,row.target_z,row.near,row.falloff)
		assert(not measured.has("error") and measured.whole==row.whole and measured.in_range==row.in_range)
	var reach_gate = preload("res://scripts/lol2/hive_attack_reach_gate.gd")
	var target_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_target_validity_native.json"))
	assert(target_rows.size()==2048)
	for row in target_rows:
		var source := {"target":0x430000 if row.present else 0,"b7":int(row.b7)}
		var admission: Dictionary = reach_gate.target_admission(source,row.flags)
		assert(not admission.has("error") and admission.valid==row.valid)
		assert(admission.state.b7==row.after_b7)
		assert(admission.state.target==(0x430000 if row.valid else 0))
		if not row.valid:
			assert(admission.distance==0x27100000 and admission.threshold==admission.distance and admission.edge_distance==admission.distance)
	var target_composed: Dictionary = reach_gate.evaluate_target({"target":1,"b7":0,"b4":0,"byte9e":2},0,[0,0,128*65536,0],128,0,32)
	assert(target_composed.valid and target_composed.distance==128*65536 and target_composed.state.b7==1 and target_composed.state.b4==1)
	assert(not reach_gate.evaluate_target({"target":0,"b7":1},null,null,null,null,null).valid)
	var reach_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_attack_reach_gate_native.json"))
	assert(reach_rows.size()==864)
	for row in reach_rows:
		var source_actor := {"byte9e":row.mode,"b4":row.b4,"b7":row.b7,"b5":173,"b6":201}
		var gate: Dictionary = reach_gate.run(source_actor,row.distance,row.reach,row.obstruction,row.draw)
		assert(not gate.has("error"))
		assert(gate.state.b4==row.expected_b4 and gate.state.b7==row.expected_b7)
		assert(gate.threshold==row.threshold and gate.calls==row.calls)
		assert(gate.state.b5==173 and gate.state.b6==201)
		assert(source_actor.b4==row.b4 and source_actor.b7==row.b7)
	assert(reach_gate.run({"byte9e":2,"b4":0,"b7":0},0,128,0,null).has("error"))
	assert(not reach_gate.run({"byte9e":0,"b4":0,"b7":1},0,null,null,null).has("error"))
	var material_changes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_region_material_setter_native.json"))
	assert(material_changes.size()==3072)
	for row in material_changes:
		var initial := {"material_index":90,"depth":90,"flags1c":int(row.flags),"neighbors":[1,2,3,4]}
		var changed := preload("res://scripts/lol2/hive_player_height.gd").prepare_region_material_change(initial,row.selector,row.depth)
		assert(not changed.has("error") and changed.state.material_index==row.selector and changed.state.depth==row.depth)
		assert(changed.state.flags1c==initial.flags1c and changed.refresh=={"argument2":0,"argument3":1})
		changed.state.neighbors[0]=99
		assert(initial.material_index==90 and initial.depth==90 and initial.neighbors[0]==1)
	var triangles = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_plane_triangle_native.json"))
	assert(triangles.size()==280)
	for row in triangles:
		var selected := preload("res://scripts/lol2/hive_player_height.gd").plane_triangle(row.points,row.query)
		assert(not selected.has("error") and selected.triangle==[int(row.triangle[0]),int(row.triangle[1]),int(row.triangle[2])],str(row)+" => "+str(selected))
		var height := preload("res://scripts/lol2/hive_player_height.gd").plane_height_return(0,0,[row.points[0][1],row.points[1][1],row.points[2][1],row.points[3][1]])
		assert(not height.has("error") and height.height==row.height)
		var clamped := preload("res://scripts/lol2/hive_player_height.gd").finish_slope_height(height.height,row.points[0][1],row.points[2][1],false,null)
		assert(not clamped.has("error") and clamped.height==row.height)
	var plane_returns = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_plane_return_native.json"))
	assert(plane_returns.size()==6400)
	for row in plane_returns:
		var result := preload("res://scripts/lol2/hive_player_height.gd").plane_height_return(row.status,row.quotient,row.heights)
		assert(not result.has("error") and result.height==row.expected)
	var slope_finishes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_slope_height_finish_native.json"))
	assert(slope_finishes.size()==2058)
	for row in slope_finishes:
		var finished := preload("res://scripts/lol2/hive_player_height.gd").finish_slope_height(row.proposed,row.first,row.second,row.subtract,row.depth)
		assert(not finished.has("error") and finished.height==row.expected)
	var loaded_regions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_region_depth_loader_native.json"))
	assert(loaded_regions.size()==1292)
	var nonzero_regions := 0
	for row in loaded_regions:
		var loaded := preload("res://scripts/lol2/hive_player_height.gd").loaded_region_depth(row.flags,row.selector,row.material_depth)
		assert(not loaded.has("error") and loaded.depth==row.expected)
		if loaded.depth!=0: nonzero_regions+=1
		var context := preload("res://scripts/lol2/hive_player_height.gd").region_context(loaded.depth,row.flags,row.floor,row.selector,row.material_kind)
		if loaded.depth!=0 and (int(row.flags)&4)!=0:
			assert(context.get("error","")=="Native sloped region height required.")
		else:
			assert(not context.has("error") and context.depth==loaded.depth)
			if loaded.depth!=0: assert(context.height==int(row.floor)*65536 and context.material_kind==row.material_kind)
	assert(nonzero_regions==50)
	var region_refs = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_region_reference_native.json"))
	assert(region_refs.size()==2048)
	for row in region_refs:
		var reference := preload("res://scripts/lol2/hive_player_height.gd").region_reference({"override_active":row.active!=0,"override_matches":row.match,"override_region":0x430000,"flags15":row.flags,"reference_c":(0x420000 if int(row.flags)&16 else 0x410000) if row.linked else 0,"indirect_region":0x420000})
		assert(not reference.has("error") and reference.reference==row.expected)
	var reduced = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_reduced_player_height_native.json"))
	assert(reduced.size()==960)
	for row in reduced:
		var state := {"cache1e5":0,"byte3e":row.base,"byte3f":row.shrink,"byte22a":255,"byte229":row.event_flag,"reduction16d":row.reduction,"z":0,"upper_b5":row.clearance}
		var measured := preload("res://scripts/lol2/hive_player_height.gd").virtual_height_hive_source_bank(state,true,row.region_present)
		assert(not measured.has("error"),str(measured))
		assert(measured.height==row.height and measured.state.cache1e5==row.cache and measured.state.reduction16d==row.after_reduction and measured.state.byte22a==row.flags and measured.state.byte229==row.after_event_flag,str(row)+" => "+str(measured))
		state.merge({"byte45":0,"extra115":0,"lower_b9":-5*65536,"byte24":0,"byte1b3":1,"byte1ce":11,"dword125":99,"flags7":128,"flags8":8})
		var resolved := preload("res://scripts/lol2/hive_player_height.gd").resolve_hive_source_bank(state,true,row.region_present,{"depth":0})
		assert(not resolved.has("error"),str(resolved))
		assert(resolved.height==row.final.height and resolved.notifications.is_empty())
		for field in ["byte1b3","byte1ce","dword125","flags8"]: assert(resolved.state[field]==row.final[field])
		assert(resolved.state.reduction16d==row.after_reduction and resolved.state.cache1e5==row.cache and resolved.state.byte229==row.after_event_flag)
		assert(state.byte1b3==1 and state.dword125==99 and state.cache1e5==0)
	var fresh_heights = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_fresh_player_height_native.json"))
	assert(fresh_heights.size()==1536)
	for row in fresh_heights:
		var state := {"cache1e5":0,"byte3e":row.base,"byte3f":10,"byte22a":0,"reduction16d":0,"z":100*65536,"upper_b5":100*65536+row.clearance}
		var measured := preload("res://scripts/lol2/hive_player_height.gd").virtual_height_without_region_event(state,false)
		assert(not measured.has("error"),str(measured))
		assert(measured.height==row.height and measured.state.reduction16d==row.reduction and measured.state.byte22a==row.flags22a)
		assert(state.cache1e5==0 and state.reduction16d==0)
	for height in range(1,256):
		var cached := preload("res://scripts/lol2/hive_player_height.gd").virtual_height_without_region_event({"cache1e5":height},false)
		assert(cached.height==height and cached.state=={"cache1e5":height})
	var proposals = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_height_proposal_native.json"))
	assert(proposals.size()==512)
	for row in proposals:
		var proposed := preload("res://scripts/lol2/hive_player_height.gd").proposed_height(row.height,row.offset,row.z,row.extra)
		assert(not proposed.has("error") and proposed.height==row.expected)
	var materials = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_height_material_native.json"))
	assert(materials.size()==256)
	for row in materials:
		var notice := preload("res://scripts/lol2/hive_player_height.gd").material_notification(row.kind)
		assert(not notice.has("error") and notice.controller==0x23819 and notice.code==row.notification)
	var region_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_height_region_gate_native.json"))
	assert(region_rows.size()==432)
	for row in region_rows:
		var state := {"byte1b3":row.initial,"byte229":row.flags}
		var gate := preload("res://scripts/lol2/hive_player_height.gd").region_gate(state,row.proposed,row.region,row.lower)
		assert(not gate.has("error"))
		assert(gate.state.byte1b3==row.expected.byte1b3 and gate.lower==row.expected.lower and gate.retained==row.expected.retained and gate.material_needed==row.expected.material_needed)
		assert(state.byte1b3==row.initial)
		var full_state := {"byte24":0,"byte1b3":row.initial,"byte229":row.flags,"byte1ce":11,"dword125":99,"flags7":128,"flags8":8}
		var resolved := preload("res://scripts/lol2/hive_player_height.gd").resolve_prepared(full_state,row.proposed,row.lower,0x100000,{"depth":1,"height":row.region,"material_index":255})
		assert(not resolved.has("error"),str(resolved))
		assert(resolved.height==row.final.height and resolved.notifications.is_empty())
		for field in ["byte1b3","byte1ce","dword125","flags8"]: assert(resolved.state[field]==row.final[field])
		assert(full_state.byte1b3==row.initial and full_state.dword125==99)
		full_state.merge({"byte45":46,"z":row.proposed,"extra115":0,"lower_b9":row.lower,"upper_b5":0x100000})
		var from_fields := preload("res://scripts/lol2/hive_player_height.gd").resolve_fields(full_state,46,{"depth":1,"height":row.region,"material_index":255})
		assert(not from_fields.has("error") and from_fields.height==row.final.height)
		for field in ["byte1b3","byte1ce","dword125","flags8"]: assert(from_fields.state[field]==row.final[field])
	var cleanups = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_height_cleanup_native.json"))
	assert(cleanups.size()==4608)
	for row in cleanups:
		var input := {"byte24":row.flag24,"byte1b3":7,"byte1ce":11,"dword125":99,"flags7":row.flags7,"flags8":row.flags8}
		var cleaned := preload("res://scripts/lol2/hive_player_height.gd").finish_state(input,row.initial)
		assert(not cleaned.has("error"))
		assert(cleaned.state.dword125==row.expected.word125 and cleaned.state.byte1b3==row.expected.byte1b3 and cleaned.state.byte1ce==row.expected.byte1ce and cleaned.state.flags8==row.expected.flags8)
		assert(input.byte1b3==7 and input.byte1ce==11 and input.dword125==99)
	var bounds = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_height_bounds_native.json"))
	assert(bounds.size()==729)
	for row in bounds:
		var limited := Spatial.player_height_bounds(row.proposed,row.lower,row.upper)
		assert(not limited.has("error") and limited.height==row.result)
	var heights = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_obstruction_height_native.json"))
	assert(heights.size()==18)
	for row in heights:
		var height_gate := Spatial.obstruction_height(row.first,row.second,4)
		assert(not height_gate.has("error") and height_gate.rejected==row.rejected and height_gate.needs_virtual8==row.needs_virtual8)
	var transforms = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_obstruction_transform_native.json"))
	assert(transforms.transforms.size()==1052 and transforms.compositions.size()==45)
	for row in transforms.transforms:
		var transformed := Spatial.inverse_transform(row.point,row.origin,row.sine,row.cosine)
		assert(not transformed.has("error"),str(transformed))
		assert(transformed.point[0]==row.expected[0] and transformed.point[1]==row.expected[1],str(row)+" => "+str(transformed))
	for row in transforms.compositions:
		var composed := Spatial.obstruction_xy(row)
		assert(not composed.has("error") and composed.rejected==row.rejected)
	var boxes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_obstruction_box_native.json"))
	assert(boxes.size()==2560)
	for row in boxes:
		var box := Spatial.obstruction_box(row.points,row.width,row.height)
		assert(not box.has("error") and box.rejected==row.rejected)
	var projections = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_target_projection_native.json"))
	assert(projections.size()==1052)
	for row in projections:
		var projected := Spatial.target_projection(row.points,row.sine,row.cosine)
		assert(not projected.has("error") and projected.distance==row.result)
	var sword_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_reach_native.json"))
	assert(sword_rows.size()==2560)
	for row in sword_rows:
		var gate := Spatial.sword_distance_gate(row.distance,row.form)
		assert(not gate.has("error") and gate.limit==row.limit and gate.admitted==row.admitted)
	assert(Spatial.sword_distance_gate(0,256).has("error"))
	assert(Spatial.sword_distance_gate(0.5,1).has("error"))
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_spatial_admission_native.json"))
	assert(fixture.horizontal.size() == 4096 and fixture.vertical.size() == 6400 and fixture.euclidean.size() == 4080)
	for row in fixture.horizontal: assert(Spatial.horizontal_approximate(row.points).distance == row.result)
	for row in fixture.euclidean:
		var measured := Spatial.horizontal_euclidean(row.points,row.control_word)
		assert(measured.distance == row.result and measured.integer_invalid == (row.result == -2147483648))
	for row in fixture.vertical: assert(Spatial.vertical(row).classification == row.result)
	# Source distance and vertical fixtures compose in player→target order.
	for index in range(fixture.euclidean.size()):
		var horizontal: Dictionary = fixture.euclidean[index]
		var elevation: Dictionary = fixture.vertical[index%fixture.vertical.size()]
		var form := 2 if index%2==0 else 1
		var spatial := Spatial.sword_spatial({"points":horizontal.points,"control_word":horizontal.control_word,"player_form":form,"vertical":elevation})
		assert(not spatial.has("error"),str(spatial))
		assert(spatial.distance==horizontal.result and spatial.integer_invalid==(horizontal.result==-2147483648))
		var in_range: bool = horizontal.result<=((64 if form==2 else 128)<<16)
		assert(spatial.admitted==(in_range and elevation.result==4))
		assert(spatial.has("classification")==in_range)
	var outside := {"points":[0,0,129*65536,0],"control_word":0x127f,"player_form":1,"vertical":null}
	assert(not Spatial.sword_spatial(outside).has("error") and not Spatial.sword_spatial(outside).admitted)
	outside.points=[0,0,128*65536,0]
	assert(Spatial.sword_spatial(outside).has("error"))
	var context := {"z":-235*65536,"height":35,"target_z":-235*65536,"target_height":46}
	assert(Spatial.vertical(context).classification == 4)
	var actor := {"ac":1,"ad":0,"b4":0,"b5":0,"b7":1,"b9":0,"target":0}
	var helpers := {"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	var attack := Attack.new()
	var result := Bridge.run(actor,{"action":0,"terminal":true,"spatial":context},helpers,attack,2)
	assert(not result.has("error") and result.selections.size() == 1)
	context.target_z = context.z+100*65536
	assert(Spatial.vertical(context).classification == 0)
	result = Bridge.run(actor,{"action":0,"terminal":true,"spatial":context},helpers,attack)
	assert(not result.has("error") and result.selections.is_empty())
	for bad in [null,true,"0",0.5,NAN,INF,2147483648,-2147483649]:
		assert(Spatial.horizontal_approximate([bad,0,0,0]).has("error"))
		context.z = bad
		assert(Spatial.vertical(context).has("error"))
	for word in [null,true,0x27f,0,0x137f,-1,65536]:
		assert(Spatial.horizontal_euclidean([0,0,0,0],word).has("error"))
	print("PASS:4080 Euclidean endpoint cases,4096 native fixed distances,6400 vertical gates and spatial-to-action composition")
	quit(0)
