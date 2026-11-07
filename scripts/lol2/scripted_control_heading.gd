extends RefCounted
## Original opcode18 heading block65F0E..6601B for the rapids controls only.
## Caller supplies native path direction, far/near admission and fixed movement quota.
## Caller stores the returned heading as the native 16-bit owner heading.
static func step(current: int, path_heading: int, desired: int, flags: int, far: bool, quota: int) -> Dictionary:
	if current<0 or current>65535 or path_heading<0 or path_heading>65535 or desired<0 or desired>65535 or quota<0 or quota>0x7fffffff:return {}
	if flags not in [0x101,0x111,0x901,0x911]:return {}
	if flags&0x800:return {"heading":desired,"flags":flags,"completion_allowed":true}
	var target:=desired
	if far:target=current if flags&0x10 else path_heading
	if current==target:return {"heading":current,"flags":flags,"completion_allowed":true}
	var distance:=target-current
	var positive:=distance>0
	distance=absi(distance)
	# Preserve original branch arithmetic, including its 0x8000 subtraction.
	if distance>0x8000:
		positive=not positive
		distance-=0x8000
	var half: int=distance/2
	var amount:=mini(half,quota>>9)
	if distance<0x20 or amount==0:
		return {"heading":target,"flags":flags|0x10,"completion_allowed":false}
	return {"heading":(current+(amount if positive else -amount))&65535,"flags":flags,"completion_allowed":false}
