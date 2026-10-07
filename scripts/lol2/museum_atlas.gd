extends Control
## Geometry overview, not a reconstruction of native automap discovery rules.
var walkthrough: Node3D
var geometry_path := "res://assets/lol2/generated/museum_review/museum.json"
var edges: Array = []
var floor_polygons: Array[PackedVector2Array] = []
var bounds := Rect2()
var zoom := 1.0
var pan := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "Scroll to zoom · Drag to move"
	var data = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var perimeter := {}
	for face in data.faces:
		if face.kind != "floor": continue
		var polygon := PackedVector2Array()
		for p in face.points: polygon.append(Vector2(p[0],p[2]))
		var area := 0.0
		for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area) < 0.02: continue
		floor_polygons.append(polygon)
		for i in polygon.size():
			var start := polygon[i]
			var end := polygon[(i+1)%polygon.size()]
			if start.distance_to(end) < 0.1: continue
			if perimeter.is_empty(): bounds = Rect2(start,Vector2.ZERO)
			bounds = bounds.expand(start).expand(end)
			if start.x > end.x or (start.x == end.x and start.y > end.y):
				var swap := start
				start = end
				end = swap
			var key := Vector4(start.x,start.y,end.x,end.y)
			if perimeter.has(key): perimeter[key].count += 1
			else: perimeter[key] = {"a":start,"b":end,"count":1}
	for edge in perimeter.values():
		if edge.count == 1: edges.append([edge.a,edge.b])

func _process(_delta: float) -> void:
	queue_redraw()

func map_point(point: Vector2) -> Vector2:
	var scale_factor := minf((size.x - 24) / maxf(bounds.size.x, 1), (size.y - 24) / maxf(bounds.size.y, 1))
	return (point - bounds.get_center()) * scale_factor * zoom + size / 2 + pan

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171d20"))
	for polygon in floor_polygons:
		var mapped := PackedVector2Array()
		for point in polygon: mapped.append(map_point(point))
		draw_colored_polygon(mapped,Color("64765d"))
	for edge in edges:
		draw_line(map_point(edge[0]),map_point(edge[1]),Color("090f12"),5,true)
		draw_line(map_point(edge[0]),map_point(edge[1]),Color("b3bb95"),1.5,true)
	if not is_instance_valid(walkthrough): return
	var position_3d: Vector3 = walkthrough.player.global_position
	var point := map_point(Vector2(position_3d.x, position_3d.z))
	var forward: Vector3 = -walkthrough.player.global_basis.z
	draw_circle(point, 4, Color("e5be72"))
	draw_line(point, point + Vector2(forward.x, forward.z) * 14, Color("e5be72"), 2)

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next_zoom := clampf(zoom * factor, 1.0, 12.0)
	pan = anchor - size / 2 - (anchor - size / 2 - pan) * next_zoom / zoom
	zoom = next_zoom
	queue_redraw()

func overview() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func center_player() -> void:
	if not is_instance_valid(walkthrough): return
	zoom = maxf(zoom, 3.0)
	var position_3d: Vector3 = walkthrough.player.global_position
	pan += size / 2 - map_point(Vector2(position_3d.x, position_3d.z))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.25, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(0.8, event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pan += event.relative
		queue_redraw()
		accept_event()
