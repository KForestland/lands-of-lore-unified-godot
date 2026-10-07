extends RefCounted
## Shared modern styling around recovered original artwork.
static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func create() -> Theme:
	var theme := Theme.new()
	var gold := Color("b69a62")
	theme.set_stylebox("normal", "Button", box(Color("202322"), Color("736443")))
	theme.set_stylebox("hover", "Button", box(Color("36392f"), gold))
	theme.set_stylebox("pressed", "Button", box(Color("45412c"), Color("e5be72")))
	theme.set_stylebox("hover_pressed", "Button", theme.get_stylebox("pressed", "Button"))
	theme.set_stylebox("disabled", "Button", box(Color("202322"), Color("524c3c")))
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, Color("e5be72"), 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color("f1e9d9"))
	theme.set_color("font_disabled_color", "Button", Color("a6a394"))
	theme.set_stylebox("panel", "ItemList", box(Color("171d1c"), Color("736443")))
	theme.set_stylebox("focus", "ItemList", box(Color.TRANSPARENT, gold))
	theme.set_stylebox("selected", "ItemList", box(Color("48432e"), gold))
	theme.set_stylebox("selected_focus", "ItemList", box(Color("48432e"), Color("e5be72")))
	theme.set_color("font_color", "ItemList", Color("ddd8ca"))
	theme.set_color("font_selected_color", "ItemList", Color("fff1cb"))
	return theme
