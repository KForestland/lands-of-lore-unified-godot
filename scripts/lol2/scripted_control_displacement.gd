extends RefCounted
## Original AFE99/93AE4/AFEF6 proposed movement before collision admission.
## Native XY coordinates, 16.16 units; the caller owns world-axis conversion.
static var _table: Array=[]
static func _sine(heading: int) -> int:
	if _table.is_empty():
		_table=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/scripted_control_sine.json"))
		assert(_table.size()==4096)
	var wrapped:=heading&65535
	var value:=int(_table[(wrapped&32767)>>3])
	return -value if wrapped&32768 else value
static func step(heading: int, length: int) -> Dictionary:
	if heading<0 or heading>65535 or length<0 or length>0x3fffffff:return {}
	return {"dx":(_sine(heading)*length)>>16,"dy":(_sine(heading+16384)*length)>>16}
