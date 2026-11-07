extends RefCounted
## Presentation adapter for the room hand selectors (owner r12e report 1): items the room asks for come first; the rest
## of the pack keeps its carried order. The selector stands in for the original held cursor.
static func wanted_first(carried: Array, wanted: Callable) -> Array:
	return carried.filter(func(id): return wanted.call(id)) + carried.filter(func(id): return not wanted.call(id))
