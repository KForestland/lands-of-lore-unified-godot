extends RefCounted
## D6180 player-height state stages; live region/call scheduling remains external.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func finish_state(state: Variant, retained_initial: Variant) -> Dictionary:
	if not state is Dictionary: return {"error":"Invalid player height state."}
	if not Numbers._integer(retained_initial,255): return {"error":"Invalid retained height state."}
	for field in ["byte24","byte1b3","byte1ce","flags7","flags8","dword125"]:
		if not Numbers._integer(state.get(field),0xffffffff if field=="dword125" else 255): return {"error":"Invalid player height field: "+field}
	var result: Dictionary = state.duplicate(true)
	if int(retained_initial)!=0 and int(state.byte24)==0:
		result.dword125=1;result.byte1b3=0;result.byte1ce=0
		if int(state.flags7)&128: result.flags8=int(state.flags8)|1
	return {"state":result}

static func region_gate(state: Variant, proposed: Variant, region_height: Variant, lower: Variant) -> Dictionary:
	if not state is Dictionary: return {"error":"Invalid region height state."}
	for field in ["byte1b3","byte229"]:
		if not Numbers._integer(state.get(field),255): return {"error":"Invalid region height field: "+field}
	for value in [proposed,region_height,lower]:
		if not preload("res://scripts/lol2/hive_spatial_admission.gd")._signed(value): return {"error":"Invalid region height coordinate."}
	var result: Dictionary = state.duplicate(true)
	var retained := int(state.byte1b3)
	var material_needed := false
	if int(proposed)<=int(region_height):
		retained=0
		if int(state.byte1b3)==0 and (int(state.byte229)&3)==0:
			result.byte1b3=1
			material_needed=true
	return {"state":result,"lower":maxi(int(lower),int(region_height)),"retained":retained,"material_needed":material_needed}

static func material_notification(kind: Variant) -> Dictionary:
	# D633F dispatch after region20 != FF; caller owns81284 invocation.
	if not Numbers._integer(kind,255): return {"error":"Invalid material kind."}
	return {"controller":0x23819,"code":{5:56,6:59,9:59,12:55,13:56}.get(int(kind),32)}

static func resolve_prepared(state: Variant, proposed: Variant, lower: Variant, upper: Variant, region: Variant) -> Dictionary:
	# Proposed height and resolved region are upstream outputs. Notifications are
	# staged for the caller to execute before committing the returned state.
	var checked := finish_state(state,0)
	if checked.has("error"): return checked
	if not region is Dictionary or not Numbers._integer(region.get("depth"),255): return {"error":"Invalid resolved height region."}
	var candidate: Dictionary = checked.state
	var retained := int(candidate.byte1b3)
	var notifications: Array = []
	if int(region.depth)!=0:
		var admitted := region_gate(candidate,proposed,region.get("height"),lower)
		if admitted.has("error"): return admitted
		candidate=admitted.state;lower=admitted.lower;retained=admitted.retained
		if admitted.material_needed:
			if not Numbers._integer(region.get("material_index"),255): return {"error":"Missing region material index."}
			if int(region.material_index)!=255:
				var notice := material_notification(region.get("material_kind"))
				if notice.has("error"): return notice
				notifications.append(notice)
	var bounded := preload("res://scripts/lol2/hive_spatial_admission.gd").player_height_bounds(proposed,lower,upper)
	if bounded.has("error"): return bounded
	var finished := finish_state(candidate,retained)
	if finished.has("error"): return finished
	return {"height":bounded.height,"state":finished.state,"notifications":notifications}

static func proposed_height(height: Variant, offset45: Variant, player_z: Variant, extra115: Variant) -> Dictionary:
	if not preload("res://scripts/lol2/hive_spatial_admission.gd")._signed(height) or not Numbers._integer(offset45,255): return {"error":"Invalid player virtual height or offset."}
	var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
	if not spatial._signed(player_z) or not spatial._signed(extra115): return {"error":"Invalid player height position."}
	return {"height":spatial._i32(((int(height)-int(offset45))<<16)+int(player_z)+int(extra115))}

static func resolve_fields(state: Variant, virtual_height: Variant, region: Variant) -> Dictionary:
	if not state is Dictionary: return {"error":"Invalid player height fields."}
	var proposed := proposed_height(virtual_height,state.get("byte45"),state.get("z"),state.get("extra115"))
	if proposed.has("error"): return proposed
	return resolve_prepared(state,proposed.height,state.get("lower_b9"),state.get("upper_b5"),region)

static func virtual_height_without_region_event(state: Variant, bypass_cache: Variant) -> Dictionary:
	return _virtual_height(state,bypass_cache,null)

static func virtual_height_hive_source_bank(state: Variant, bypass_cache: Variant, region_present: Variant) -> Dictionary:
	# Only the unmodified Hive bank has verified event5 no-op behavior.
	if not region_present is bool: return {"error":"Explicit Hive region presence required."}
	return _virtual_height(state,bypass_cache,region_present)

static func _virtual_height(state: Variant, bypass_cache: Variant, hive_region: Variant) -> Dictionary:
	# D5F94 paths without a newF2D2C event; existing event flag can admit reductions.
	if not state is Dictionary or not bypass_cache is bool: return {"error":"Invalid virtual height context."}
	if not Numbers._integer(state.get("cache1e5"),255): return {"error":"Invalid cached player height."}
	if not bypass_cache and int(state.cache1e5)!=0:
		return {"height":int(state.cache1e5),"state":state.duplicate(true)}
	for field in ["byte3e","byte3f","byte22a"]:
		if not Numbers._integer(state.get(field),255): return {"error":"Invalid virtual height field: "+field}
	if not Numbers._integer(state.get("reduction16d"),0x7fffffff): return {"error":"Unsupported player height reduction."}
	var reduction := int(state.reduction16d)
	var shrink := int(state.byte3f)<<16
	var mark_region_event := false
	if reduction!=0 and reduction>=shrink:
		if not Numbers._integer(state.get("byte229"),255): return {"error":"Invalid player region-event flags."}
		if (int(state.byte229)&16)==0:
			if hive_region==null: return {"error":"Player height reduction requires region-event handling."}
			mark_region_event=hive_region
	var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
	if not spatial._signed(state.get("upper_b5")) or not spatial._signed(state.get("z")): return {"error":"Invalid virtual height clearance."}
	var clearance := maxi(spatial._i32(int(state.upper_b5)-int(state.z)),0)
	var base := int(state.byte3e)<<16
	var effective := base-mini(shrink,reduction) if reduction!=0 else base
	var result: Dictionary = state.duplicate(true)
	if mark_region_event: result.byte229=int(state.byte229)|16
	result.byte22a=int(state.byte22a)&239
	var deficit: int = spatial._i32(effective-clearance)
	if deficit>0:
		effective=clearance
		result.reduction16d=maxi(deficit,reduction)
		if effective<base-shrink: result.byte22a|=16
	var height := effective>>16
	result.cache1e5=mini(height,255)&255
	return {"height":height,"state":result}

static func resolve_hive_source_bank(state: Variant, bypass_cache: Variant, region_present: Variant, region: Variant) -> Dictionary:
	var measured := virtual_height_hive_source_bank(state,bypass_cache,region_present)
	if measured.has("error"): return measured
	return resolve_fields(measured.state,measured.height,region)

static func region_reference(context: Variant) -> Dictionary:
	# D61BF reference selection only; the caller resolves the returned reference.
	if not context is Dictionary or not context.get("override_active") is bool or not context.get("override_matches") is bool: return {"error":"Invalid region reference context."}
	if context.override_active and context.override_matches:
		if not Numbers._integer(context.get("override_region"),0xffffffff): return {"error":"Invalid override region reference."}
		return {"reference":int(context.override_region)}
	if not Numbers._integer(context.get("flags15"),255) or not Numbers._integer(context.get("reference_c"),0xffffffff): return {"error":"Invalid player region reference."}
	if (int(context.flags15)&16)!=0 or int(context.reference_c)==0:
		return {"reference":int(context.reference_c)}
	if not Numbers._integer(context.get("indirect_region"),0xffffffff): return {"error":"Missing indirect region reference."}
	return {"reference":int(context.indirect_region)}

static func loaded_region_depth(flags1c: Variant, material_index: Variant, material_depth: Variant) -> Dictionary:
	# F39FC initialization; restoration/runtime updates must not rerun it blindly.
	if not Numbers._integer(flags1c,65535) or not Numbers._integer(material_index,255): return {"error":"Invalid source region depth selector."}
	if int(material_index)==255 or ((int(flags1c)&32)!=0 and (int(flags1c)&128)==0): return {"depth":0}
	if not Numbers._integer(material_depth,255): return {"error":"Missing source material depth."}
	return {"depth":int(material_depth)}

static func region_context(depth: Variant, flags1c: Variant, floor_base: Variant, material_index: Variant, material_kind: Variant, sloped_height: Variant = null) -> Dictionary:
	if not Numbers._integer(depth,255): return {"error":"Invalid loaded region depth."}
	if int(depth)==0: return {"depth":0}
	if not Numbers._integer(flags1c,65535) or not Numbers._integer(material_index,255): return {"error":"Invalid loaded height region."}
	var height: int
	if int(flags1c)&4:
		if not preload("res://scripts/lol2/hive_spatial_admission.gd")._signed(sloped_height): return {"error":"Native sloped region height required."}
		height=int(sloped_height)
	else:
		if not preload("res://scripts/lol2/hive_spatial_admission.gd")._signed(floor_base) or int(floor_base)<-32768 or int(floor_base)>32767: return {"error":"Invalid source floor word."}
		height=int(floor_base)<<16
	return {"depth":int(depth),"height":height,"material_index":int(material_index),"material_kind":material_kind}

static func finish_slope_height(proposed: Variant, first_corner: Variant, second_corner: Variant, subtract_depth: Variant, depth: Variant) -> Dictionary:
	# F46CE: plane evaluation and source corner selection precede this step.
	var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
	if not spatial._signed(proposed) or not spatial._signed(first_corner) or not spatial._signed(second_corner): return {"error":"Invalid source slope height."}
	if not subtract_depth is bool: return {"error":"Invalid slope depth mode."}
	if subtract_depth and not Numbers._integer(depth,255): return {"error":"Invalid slope depth."}
	var height := clampi(int(proposed),mini(int(first_corner),int(second_corner)),maxi(int(first_corner),int(second_corner)))
	if subtract_depth: height=spatial._i32(height-(int(depth)<<16))
	return {"height":height}

static func plane_height_return(status: Variant, quotient: Variant, heights: Variant) -> Dictionary:
	# 135A59 dispatch; status and quotient belong to the source division helper.
	if not Numbers._integer(status,255): return {"error":"Invalid plane division status."}
	if int(status)>3: return {"height":0}
	if int(status)==2: return {"height":2147483647}
	if int(status)==3: return {"height":-2147483648}
	var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
	if not heights is Array or heights.size()!=4: return {"error":"Invalid plane corner heights."}
	if int(status)==0:
		if not spatial._signed(quotient) or not spatial._signed(heights[0]): return {"error":"Invalid plane quotient or origin height."}
		return {"height":spatial._i32(int(quotient)+int(heights[0]))}
	var total := 0
	for height in heights:
		if not spatial._signed(height): return {"error":"Invalid plane fallback height."}
		total+=int(height)
	return {"height":spatial._i32(total)>>2}

static func plane_triangle(points: Variant, query: Variant) -> Dictionary:
	var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
	if not points is Array or points.size()!=4 or not query is Array or query.size()!=2: return {"error":"Invalid plane geometry."}
	for point in points:
		if not point is Array or point.size()!=3: return {"error":"Invalid plane point."}
		for value in point:
			if not spatial._signed(value): return {"error":"Invalid plane coordinate."}
	for value in query:
		if not spatial._signed(value): return {"error":"Invalid plane query."}
	# 1359A5 uses high halves separately; a full determinant changes edge cases.
	var dx := spatial._i32(int(query[0])-int(points[2][0]))
	var dy := spatial._i32(int(query[1])-int(points[2][2]))
	var edge_x := spatial._i32(int(points[0][0])-int(points[2][0]))
	var edge_y := spatial._i32(int(points[0][2])-int(points[2][2]))
	var side := spatial._i32(((dx*edge_y)>>32)-((dy*edge_x)>>32))
	return {"triangle":[0,1,2] if side>0 else [0,2,3]}

static func prepare_region_material_change(state: Variant, material_index: Variant, material_depth: Variant) -> Dictionary:
	# F44CC, before B861C refresh. Caller must resolve a real preset first.
	if not state is Dictionary: return {"error":"Invalid mutable region state."}
	if not Numbers._integer(material_index,255) or not Numbers._integer(material_depth,255): return {"error":"Invalid resolved region material."}
	var changed: Dictionary = state.duplicate(true)
	changed.material_index=int(material_index)
	changed.depth=int(material_depth)
	return {"state":changed,"refresh":{"argument2":0,"argument3":1}}
