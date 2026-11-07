extends SceneTree
const Dispatch=preload("res://scripts/lol2/dawn_cast_dispatch.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_dispatch_native.json"))
	assert(data.rows.size()==192)
	var bindings={"instance":0x450000,"owner":0x400000,"target":0x410000,"alternate":0x420000}
	for row in data.rows:
		var result:=Dispatch.plan(row.context)
		assert(not result.has("error"),str(result))
		for field in row.expected:assert(result[field]==row.expected[field],str(field,row,result))
		assert(result.arguments.size()==row.constructor_args.size())
		for i in range(result.arguments.size()):assert(bindings.get(result.arguments[i],result.arguments[i])==row.constructor_args[i],str(row,result))
	assert(Dispatch.plan({"spell":0,"allocated":true,"heading":0,"saved_heading":0,"exclusive":0}).has("error"))
	print("PASS:192 native dispatch branches; six constructor argument orders, shield flag before allocation, heading restoration and unconditional completion tail")
	quit()
