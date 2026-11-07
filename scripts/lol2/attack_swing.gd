extends Control
## On-screen attack feedback for the shared HUD (modern presentation adapter; combat rules unchanged).
## swing(): the equipped weapon icon (or the unarmed hand, HUD shape 6) sweeps across the lower view on every
## world attack click. splash(): a short red flash over the Attack ring when a melee strike owner reports a hit
## through combat_feedback.landed() (the original shows a hit splash on that ring). heal_flash(): a short golden
## pulse over the view for a successful Healing cast. When the original classic_interface pack is staged, the Attack
## ring plays intrface.shp shapes 138-143 on every swing and the Magic ring shapes 132-137 on every cast.

const Feedback := preload("res://scripts/lol2/combat_feedback.gd")
var icon: TextureRect
var ring_flash: TextureRect
var screen_flash: ColorRect
var swing_tween: Tween
var pending_hits := -1
var pending_frames := 0
const INTERFACE := "res://assets/lol2/generated/classic_interface/"
var attack_frames: Array[Texture2D] = []
var magic_frames: Array[Texture2D] = []
var attack_anim: TextureRect
var magic_anim: TextureRect

static func _frames(first: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for index in range(first, first + 6):
		var path := INTERFACE + "shape_%03d.png" % index
		if not FileAccess.file_exists(path): return []
		frames.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	return frames

func _ring_anim(parent: Control, rect: Rect2) -> TextureRect:
	var anim := TextureRect.new()
	anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	anim.stretch_mode = TextureRect.STRETCH_SCALE
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.position = rect.position; anim.size = rect.size
	anim.visible = false
	parent.add_child(anim)
	return anim

func _play(anim: TextureRect, frames: Array[Texture2D], seconds := 0.36) -> void:
	if anim == null or frames.is_empty(): return
	anim.visible = true
	var tween := anim.create_tween()
	for texture in frames:
		tween.tween_callback(func(): anim.texture = texture)
		tween.tween_interval(seconds / frames.size())
	tween.tween_callback(func(): anim.visible = false)

func cast_flash() -> void:
	_play(magic_anim, magic_frames)

func setup(ring_texture: Texture2D, ring_rect: Rect2, ring_parent: Control, magic_rect := Rect2()) -> void:
	attack_frames = _frames(138)
	magic_frames = _frames(132)
	attack_anim = _ring_anim(ring_parent, ring_rect)
	if magic_rect.size != Vector2.ZERO: magic_anim = _ring_anim(ring_parent, magic_rect)
	name = "AttackSwing"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash = ColorRect.new()
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.color = Color(1.0, 0.85, 0.35, 0.0)
	add_child(screen_flash)
	icon = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(150, 150)
	icon.pivot_offset = icon.size * 0.5
	icon.visible = false
	add_child(icon)
	ring_flash = TextureRect.new()
	ring_flash.name = "AttackRingSplash"
	ring_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_flash.texture = ring_texture
	ring_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring_flash.stretch_mode = TextureRect.STRETCH_SCALE
	ring_flash.position = ring_rect.position
	ring_flash.size = ring_rect.size
	ring_flash.modulate = Color(1.0, 0.1, 0.05, 0.0)
	ring_parent.add_child(ring_flash)

func swing(texture: Texture2D) -> void:
	var view := get_viewport_rect().size
	icon.texture = texture
	icon.visible = true
	icon.modulate.a = 1.0
	var start := Vector2(view.x * 0.70, view.y * 0.80) - icon.size * 0.5
	var finish := Vector2(view.x * 0.46, view.y * 0.58) - icon.size * 0.5
	icon.position = start
	icon.rotation_degrees = 35.0
	if swing_tween != null and swing_tween.is_valid(): swing_tween.kill()
	swing_tween = create_tween()
	swing_tween.set_parallel(true)
	swing_tween.tween_property(icon, "position", finish, 0.12).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(icon, "rotation_degrees", -40.0, 0.12)
	swing_tween.chain().tween_property(icon, "modulate:a", 0.0, 0.12)
	swing_tween.chain().tween_callback(func(): icon.visible = false)
	_play(attack_anim, attack_frames)
	# The world strike owners handle this same click after the HUD; look for their landed report shortly after.
	pending_hits = Feedback.landed_hits
	pending_frames = 3

func splash() -> void:
	ring_flash.modulate.a = 0.85
	create_tween().tween_property(ring_flash, "modulate:a", 0.0, 0.45)

func heal_flash() -> void:
	screen_flash.color = Color(1.0, 0.85, 0.35, 0.28)
	create_tween().tween_property(screen_flash, "color:a", 0.0, 0.6)

func _process(_delta: float) -> void:
	if pending_frames <= 0: return
	if Feedback.landed_hits != pending_hits:
		pending_frames = 0
		splash()
		return
	pending_frames -= 1
