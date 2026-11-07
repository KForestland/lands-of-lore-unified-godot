extends RefCounted
## Native1366EA direction8, DD8F4 fixed ratio and65EA5 vertical correction/clamp.
## Caller supplies horizontal distance/step; this helper does not decide collision or completion.
static func _signed_byte(value: int) -> int:
	return value-256 if value>=128 else value
static func pitch(delta: int, distance: int) -> int:
	var quadrant:=0xc0 if delta<0 else 0
	var c:=absi(delta)
	var a:=distance
	var direction: int=(quadrant&0x40)^0x40
	if a>=c:
		var swap:=a;a=c;c=swap
		direction^=0x40
	if a<256:
		while c>=256:
			c>>=1;a>>=1
	var ratio: int=0xffffffff if c==0 else (a<<8)/c
	ratio>>=3
	if direction!=0:
		direction-=1;ratio=-ratio
	return (ratio+direction+quadrant)&255
static func step(delta: int, distance: int, horizontal: int, quota: int, initial_pitch: int) -> Dictionary:
	if absi(delta)>0x3fffffff or distance<0 or distance>0x3fffffff or horizontal<0 or horizontal>distance or quota<0 or quota>0x3fffffff or initial_pitch<0 or initial_pitch>255:return {}
	if delta==0:return {"step":0,"pitch":initial_pitch}
	var current_pitch:=pitch(delta,distance)
	var latched_pitch:=current_pitch if initial_pitch==0 else initial_pitch
	var interpolated:=delta
	if distance>horizontal:
		var ratio: int=(horizontal<<16)/distance
		interpolated=(delta*ratio)>>16
	if _signed_byte(current_pitch)>_signed_byte(latched_pitch):interpolated+=65536
	elif _signed_byte(current_pitch)<_signed_byte(latched_pitch):interpolated-=65536
	var movement:=clampi(interpolated,-quota,quota)
	# Preserve the native zero-step fallback as well as its remaining-distance clamp.
	if absi(delta)<=absi(movement) or (movement==0 and delta>=distance):movement=delta
	return {"step":movement,"pitch":latched_pitch}
