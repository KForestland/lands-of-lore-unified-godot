extends Control
## Rising blue-green drown veil (owner r16). Height is the viewport times elapsed/LIMIT, full at death.
## The top edge is a wave. Both editions use this veil; it does not read lol2_enhanced.
var shown_ratio := 0.0
var phase := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func sync(elapsed: float, limit: float, show: bool) -> void:
	shown_ratio = 0.0
	if show and limit > 0.0:
		shown_ratio = clampf(elapsed / limit, 0.0, 1.0)
	visible = shown_ratio > 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	phase += delta
	queue_redraw()

func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 2.0 or height < 2.0: return
	var tint := Color(0.12, 0.45, 0.48, 0.55)
	if shown_ratio >= 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), tint)
		return
	var top := height * (1.0 - shown_ratio)
	var pts := PackedVector2Array()
	var steps := 32
	for i in steps + 1:
		var x := width * float(i) / float(steps)
		var wave := sin(x * 0.04 + phase * 3.0) * 8.0
		pts.append(Vector2(x, top + wave))
	pts.append(Vector2(width, height))
	pts.append(Vector2(0.0, height))
	draw_colored_polygon(pts, tint)
