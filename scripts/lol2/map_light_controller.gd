extends Node
## Optional visibility ability. This is a modern light, not recovered spell logic.
@export var materials: Array[ShaderMaterial] = []
@export var enabled := false:
	set(value):
		enabled = value
		for material in materials:
			if material != null: material.set_shader_parameter("magic_light", enabled)

func _ready() -> void:
	enabled = enabled

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
		enabled = not enabled
		get_viewport().set_input_as_handled()
