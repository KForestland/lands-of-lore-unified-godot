extends Node
## Underwater look on the player (owner 2026-11-07). When the camera is below a liquid_drowning
## surface: a blue-green screen tint, exponential fog, and a low-pass on the Master bus.
## Open banks stay open in the world. The rising veil stays on drowning_overlay.gd.
const TINT := Color(0.05, 0.32, 0.34, 0.42)
const FOG := Color(0.03, 0.20, 0.24)
const FOG_DENSITY := 0.05
const CUTOFF_HZ := 700.0
const MUFFLE_NAME := "PlayerWaterMuffle"

var liquid: Node
var tint: ColorRect
var effect: AudioEffectLowPassFilter
var underwater := false
var fog_ready := false
var saved_fog_enabled := false
var saved_fog_density := 0.0
var saved_fog_color := Color(0, 0, 0)
var saved_fog_aerial := 0.0
var saved_fog_mode: Environment.FogMode = Environment.FOG_MODE_EXPONENTIAL
var environment: Environment

func setup(host: Node3D, source: Node) -> void:
	liquid = source
	name = "PlayerWaterView"
	var layer := CanvasLayer.new()
	layer.layer = 21
	layer.name = "UnderwaterTintLayer"
	add_child(layer)
	tint = ColorRect.new()
	tint.name = "UnderwaterTint"
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = TINT
	tint.visible = false
	layer.add_child(tint)
	for child in host.get_children():
		if child is WorldEnvironment:
			environment = (child as WorldEnvironment).environment
			break

func _process(_delta: float) -> void:
	var below := _camera_below()
	if below == underwater:
		return
	underwater = below
	_apply(below)

func _camera_below() -> bool:
	if liquid == null or not is_instance_valid(liquid): return false
	if not liquid.has_method("column_at"): return false
	var host: Node = liquid.get("host")
	if host == null: return false
	var camera := host.get("camera") as Camera3D
	if camera == null: return false
	var region: Dictionary = liquid.column_at(camera.global_position)
	if region.is_empty(): return false
	return camera.global_position.y < float(region.surface) - 0.05

func _apply(on: bool) -> void:
	if tint != null: tint.visible = on
	_fog(on)
	_muffle(on)

func _fog(on: bool) -> void:
	if environment == null: return
	if on:
		if not fog_ready:
			saved_fog_enabled = environment.fog_enabled
			saved_fog_density = environment.fog_density
			saved_fog_color = environment.fog_light_color
			saved_fog_aerial = environment.fog_aerial_perspective
			saved_fog_mode = environment.fog_mode
			fog_ready = true
		environment.fog_enabled = true
		environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		environment.fog_density = FOG_DENSITY
		environment.fog_light_color = FOG
		environment.fog_aerial_perspective = 0.6
	elif fog_ready:
		environment.fog_enabled = saved_fog_enabled
		environment.fog_density = saved_fog_density
		environment.fog_light_color = saved_fog_color
		environment.fog_aerial_perspective = saved_fog_aerial
		environment.fog_mode = saved_fog_mode
		fog_ready = false

func _muffle(on: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0: return
	if on:
		if effect != null and is_instance_valid(effect): return
		effect = AudioEffectLowPassFilter.new()
		effect.resource_name = MUFFLE_NAME
		effect.cutoff_hz = CUTOFF_HZ
		effect.resonance = 0.15
		AudioServer.add_bus_effect(bus, effect)
	else:
		_remove_effect(bus)

func _remove_effect(bus: int) -> void:
	if effect == null: return
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, i) == effect:
			AudioServer.remove_bus_effect(bus, i)
	effect = null

func muffled() -> bool:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0 or effect == null: return false
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx == effect and fx is AudioEffectLowPassFilter:
			return is_equal_approx((fx as AudioEffectLowPassFilter).cutoff_hz, CUTOFF_HZ)
	return false

func _exit_tree() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0: _remove_effect(bus)
	if fog_ready: _fog(false)
