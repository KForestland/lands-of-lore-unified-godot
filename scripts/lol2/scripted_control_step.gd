extends RefCounted
## Native65BB0 kind16/source flags0101 or0901. Proposes movement; collision is caller-owned.
## Native current speed, clock and FPU mode must be supplied explicitly.
const Polar=preload("res://scripts/lol2/scripted_control_polar.gd")
const Horizontal=preload("res://scripts/lol2/scripted_control_horizontal.gd")
const Vertical=preload("res://scripts/lol2/scripted_control_vertical.gd")
const Heading=preload("res://scripts/lol2/scripted_control_heading.gd")
static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
static func step(value: Variant) -> Dictionary:
	if not value is Dictionary:return {}
	for key in ["position","target"]:
		if not value.get(key) is Array or value[key].size()!=3:return {}
		for coordinate in value[key]:
			if not _integer(coordinate,-0x7fffffff,0x7fffffff):return {}
	for key in ["heading","target_heading"]:
		if not _integer(value.get(key),0,65535):return {}
	for key in ["elapsed","pitch","base_speed","target_speed","ticks"]:
		if not _integer(value.get(key),0,255):return {}
	if not _integer(value.get("tick_fixed"),0,65536) or not _integer(value.get("rounding_mode"),0,3):return {}
	if not _integer(value.get("flags"),0,65535) or int(value.flags) not in [0x101,0x111,0x901,0x911]:return {}
	var position: Array=value.position
	var target: Array=value.target
	var polar:=Polar.from_delta(int(target[0])-int(position[0]),int(target[1])-int(position[1]),int(value.rounding_mode))
	if polar.is_empty():return {}
	var elapsed:=mini(255,int(value.elapsed)+int(value.ticks))
	var speed: int=int(value.base_speed)+mini(elapsed,int(value.target_speed)-int(value.base_speed)) if int(value.base_speed)<=int(value.target_speed) else int(value.base_speed)-mini(elapsed,int(value.base_speed)-int(value.target_speed))
	var units: int=speed*10/4
	var quota: int=units*int(value.tick_fixed)/60
	var delta:=int(target[2])-int(position[2])
	# For kind16 frame+5C copies the extra field, so the native near comparison equals.
	var horizontal:=Horizontal.step(int(polar.distance),delta,quota,elapsed,true)
	if horizontal.is_empty():return {}
	var vertical:=Vertical.step(delta,int(polar.distance),int(horizontal.horizontal),quota,int(value.pitch))
	if vertical.is_empty():return {}
	var heading:=Heading.step(int(value.heading),int(polar.heading)&65535,int(value.target_heading),int(value.flags),bool(horizontal.far),quota)
	if heading.is_empty():return {}
	var complete: bool=horizontal.completion_candidate and delta==0 and heading.completion_allowed
	var next_position: Array=target.duplicate() if complete else position.duplicate()
	return {"flags":int(heading.flags)|(0x20 if complete else 0),"elapsed":int(horizontal.elapsed),"pitch":int(vertical.pitch),"position":next_position,"heading":int(value.target_heading) if complete else int(heading.heading),"result":1 if complete else 0,"vector":[int(polar.heading),int(horizontal.horizontal),int(vertical.step)]}
