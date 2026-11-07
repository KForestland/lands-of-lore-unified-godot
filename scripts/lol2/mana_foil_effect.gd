extends RefCounted
## Definition133/handler43 calls nativeD6A88(player,50). Signed32 addition/clamp order.
static func signed32(value: int) -> int:
	var bits:=value & 0xffffffff
	return bits-0x100000000 if bits>=0x80000000 else bits
static func apply(current: int, maximum: int) -> int:
	var total:=signed32(current+50)
	var cap:=signed32(maximum)
	return (cap if total>cap else maxi(0,total)) & 0xffffffff
