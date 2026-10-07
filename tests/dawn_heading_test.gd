extends SceneTree
const Heading=preload("res://scripts/lol2/dawn_heading.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_heading_native.json"))
	assert(data.rows.size()==612)
	for row in data.rows:
		var result:=Heading.between(row.first,row.second)
		assert(not result.has("error") and result.byte==row.expected and result.word==int(row.expected)<<8,str(row,result))
	for bad in [[],[0],[true,0],[0.5,0],[2147483648,0]]: assert(Heading.between(bad,[0,0]).has("error"))
	print("PASS:612 native integer headings, signed-overflow boundaries and coincident points")
	quit()
