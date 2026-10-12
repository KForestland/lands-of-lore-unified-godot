extends "res://scripts/lol2/museum_interface.gd"
## The shared area HUD in the Cave (docs/classic-hud.md). The cave's text label is hidden in normal play. Its dynamic
## prompts become the hint line (fallen > loot > curse warning) and its status moves to the Character page.

func character_text() -> String:
	var text := super.character_text()
	var extra: Array = walkthrough.hud_status_lines() if walkthrough.has_method("hud_status_lines") else []
	return text + ("\n" + "\n".join(extra) if not extra.is_empty() else "")

var cave_hint := false
func _process(delta: float) -> void:
	super._process(delta)
	if save_notice_remaining > 0 or cursor_active:
		cave_hint = false
		return
	var prompt: String = walkthrough.hud_prompt() if walkthrough.has_method("hud_prompt") else ""
	if not prompt.is_empty(): hint.text = prompt
	elif cave_hint: hint.text = "Tab — Interface · M — Atlas" + (" · F5/F9 — Save/Load" if saves_enabled else "")
	cave_hint = not prompt.is_empty()
