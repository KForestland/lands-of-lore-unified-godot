extends RefCounted
## Optional L19 legacy-area transport for opcode196's moving-floor clock/accumulators.
## Older saves have no packet and therefore restore the source floor baseline.
static func error(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or not (packet.get("version") is int or packet.get("version") is float) or packet.get("version")!=1 or not packet.get("motions") is Dictionary:
		return "Invalid moving-floor checkpoint."
	var clock: Variant=packet.get("clock")
	if not (clock is int or clock is float) or not is_finite(float(clock)) or float(clock)<0.0 or float(clock)>=1.0:return "Invalid moving-floor clock."
	if packet.motions.size()>65536:return "Invalid moving-floor count."
	for key in packet.motions:
		if not str(key).is_valid_int() or str(int(str(key)))!=str(key) or int(str(key))<0 or int(str(key))>65535:return "Invalid moving-floor region."
		var row: Variant=packet.motions[key]
		if not row is Dictionary or row.size()!=4:return "Invalid moving-floor state."
		for field in ["height","remaining","fraction","speed"]:
			var value: Variant=row.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)):return "Invalid moving-floor number."
		if row.remaining < -32768 or row.remaining>32767 or row.height < -32768 or row.height>32767 or row.height+row.remaining < -32768 or row.height+row.remaining>32767:return "Invalid moving-floor height."
		if row.fraction<0 or row.fraction>65535 or row.speed<0 or row.speed>255 or (row.speed==0 and row.remaining!=0):return "Invalid moving-floor rate."
	return ""
