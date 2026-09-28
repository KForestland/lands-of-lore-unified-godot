extends RefCounted
## JSON-safe primitives shared by independently saved effect/encounter packets.
static func integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<=maximum
static func vector(value: Variant, limit: float) -> bool:
	if not value is Array or value.size()!=3: return false
	for n in value:
		if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n))>limit: return false
	return true
