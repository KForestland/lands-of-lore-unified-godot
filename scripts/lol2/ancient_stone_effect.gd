extends RefCounted
## Ancient Stone handler 6, in source units.
## Replayed by tools/verify_ancient_stone_use.py; fixtures in docs/ancient-stone-use.json.
## Admitted events are 1 and 9 while byte 23C3F is <= 8. Success increments that byte.
## 7C5DC is called as (object 23819, 1) and selects resource index 0x25, 0x26, or 0x27.
## Byte 223D4 == 0 clears held item 23C57 through 77ACC and requests 9B8F0.
const DEFINITION := 68
const IDENTITY := 3764690106
const HANDLER := 6
const COUNTER_LIMIT := 8

static func shape_index(flag_42c: int, field_400: int, flag_42d: int) -> int:
	if (flag_42c & 0x80) != 0:
		if field_400 == 5 and (flag_42d & 0x80) != 0:
			return 0x27
		return 0x26
	if field_400 == 5:
		return 0x27
	return 0x25

## hold is byte 223D4. present is byte 269C4. word is the u16 at [269CC]+130.
## flag_42c, field_400, and flag_42d are object 23819 bytes +42C, dword +400, and byte +42D.
static func use(event: int, counter: int, hold: int, flag_42c: int = 0, field_400: int = 0, flag_42d: int = 0, present: int = 1, word: int = 0) -> Dictionary:
	var open := (event == 1 or event == 9) and counter >= 0 and counter <= COUNTER_LIMIT
	if not open:
		return {"result": 0, "consumed": false, "counter": counter, "shape": -1, "release": false, "presentation": false, "presentation_args": []}
	var show := (present & 1) == 0
	var args: Array = []
	if show:
		args = [0x23c68, word & 0xffff, 0, 0, 1]
	return {
		"result": 1,
		"consumed": hold == 0,
		"counter": (counter + 1) & 0xff,
		"shape": shape_index(flag_42c, field_400, flag_42d),
		"release": hold == 0,
		"presentation": show,
		"presentation_args": args,
	}
