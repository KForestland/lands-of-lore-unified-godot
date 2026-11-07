extends RefCounted
## Native111C34/136594 hardware FPATAN branch; live FPU rounding mode is caller-owned.
## Native158EDE truncates the angle regardless of that mode.
const SOURCE_PI=3.1415926536
static func from_delta(dx: int, dy: int, rounding_mode: int) -> Dictionary:
	if absi(dx)>0x3fffffff or absi(dy)>0x3fffffff or rounding_mode<0 or rounding_mode>3:return {}
	var magnitude:=sqrt(float(dx)*float(dx)+float(dy)*float(dy))
	var distance: int=roundi(magnitude) if rounding_mode==0 else ceili(magnitude) if rounding_mode==2 else floori(magnitude)
	var heading: int=int((atan2(float(-dx),float(-dy))+SOURCE_PI)*32768.0/SOURCE_PI) if dx!=0 or dy!=0 else 0
	return {"heading":heading,"distance":distance}
