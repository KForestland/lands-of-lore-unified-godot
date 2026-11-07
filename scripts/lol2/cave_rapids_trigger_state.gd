extends RefCounted
## Original control103 record0A09F826000000000181, property18, prop518 event20/local7 predicate,
## prop453 selector1 callback and control103 property8. External effects are caller-owned.
static func initial() -> Dictionary:
	return {"version":1,"hit_mode":0x81,"control_flags":0x44b1,"prop453_selector":0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1:return "Invalid rapids trigger."
	for key in ["hit_mode","control_flags","prop453_selector"]:
		var item: Variant=value.get(key)
		if not (item is int or item is float) or not is_finite(float(item)) or float(item)!=floorf(float(item)):return "Invalid rapids trigger field."
	if value.hit_mode==0x81 and value.control_flags==0x44b1 and value.prop453_selector==0:return ""
	if value.hit_mode==0 and value.control_flags==0x04b1 and value.prop453_selector==0:return ""
	if value.hit_mode==0 and value.control_flags==0x0431 and value.prop453_selector==1:return ""
	return "Rapids trigger latches disagree."
static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"hit_mode":int(value.hit_mode),"control_flags":int(value.control_flags),"prop453_selector":int(value.prop453_selector)}
static func released(value: Dictionary) -> bool:return int(value.prop453_selector)==1
## Both original hit masks are wildcards. Positive supplied damage consumes the event even
## when prop518's local7 predicate declines the downstream group.
static func hit(state: Dictionary, mask0: int, mask2: int, amount: int, local7: int) -> Dictionary:
	if mask0<0 or mask0>65535 or mask2<0 or mask2>65535 or amount<0 or amount>0x7fffffff or local7<0 or local7>255:return {"accepted":false,"released":false}
	if int(state.hit_mode)!=0x81 or amount<1:return {"accepted":false,"released":false}
	state.hit_mode=0
	state.control_flags=int(state.control_flags)&~0x4000
	if local7!=0:return {"accepted":true,"released":false}
	state.prop453_selector=1
	state.control_flags=int(state.control_flags)&~0x80
	return {"accepted":true,"released":true}
