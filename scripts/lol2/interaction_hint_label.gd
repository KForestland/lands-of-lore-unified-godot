extends Label
## Presentation alone keeps ticking while overlays pause the world. Never enable
## paused processing on the gameplay owner just to clear its interaction text.
func _init() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_theme_color_override("font_outline_color",Color.BLACK)
 add_theme_constant_override("outline_size",3)
static func attach(owner:Node,at:Vector2)->Label:
 var canvas:=CanvasLayer.new();canvas.layer=34;owner.add_child(canvas)
 var label:Label=load("res://scripts/lol2/interaction_hint_label.gd").new()
 label.position=at;canvas.add_child(label)
 return label
func _process(_delta:float)->void:
 if get_tree().paused:text=""
