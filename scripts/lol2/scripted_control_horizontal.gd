extends RefCounted
## Native65DC9..65E3F for the five group4076 commands (all have flag bit0).
## Distance/quota and native extra-field equality are supplied by the caller.
## A completion candidate must still pass vertical and heading gates.
static func step(distance: int, delta: int, quota: int, elapsed: int, extra_matches: bool) -> Dictionary:
	if distance<0 or distance>0x3fffffff or absi(delta)>0x3fffffff or quota<0 or quota>0x0fffffff or elapsed<0 or elapsed>255:return {}
	var far:=quota*4<distance or delta>quota*4
	if far:
		return {"horizontal":mini(distance,quota),"far":true,"completion_candidate":false,"elapsed":elapsed}
	return {"horizontal":distance/2,"far":false,"completion_candidate":distance<0x20000,"elapsed":elapsed/2 if extra_matches else elapsed}
