extends "res://scripts/lol2/scripted_creature_population.gd"
## Shared saved-audio lifecycle; area wrappers provide only source/configuration.
const AudioState=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
var creature_audio: Node3D
var audio_contract: Dictionary={}
func setup(walkthrough: Node3D, saved: Variant=null) -> String:
	var value=JSON.parse_string(FileAccess.get_file_as_string(str(config.get("audio_contract",""))))
	if not value is Dictionary: return "Missing creature cue contract."
	audio_contract=value
	var error:=super.setup(walkthrough,saved)
	if not error.is_empty(): return error
	creature_audio=preload("res://scripts/lol2/scripted_creature_audio.gd").new()
	add_child(creature_audio)
	return creature_audio.setup(self,audio_contract,str(config.get("audio_manifest","")))
func restore(saved: Variant) -> String:
	var error:=State.validate(saved,src)
	if not error.is_empty(): return error
	if saved.has("audio"):
		error=AudioState.validate(saved.audio,src.actors,audio_contract)
		if not error.is_empty(): return error
	var restored: Dictionary=saved.duplicate(true)
	if restored.has("audio"): restored.audio=AudioState.canonical(restored.audio)
	error=super.restore(restored)
	if error.is_empty() and creature_audio!=null:
		creature_audio.sync(0.0,true)
		present()
	return error
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	var running:=world_active()
	super.advance(delta)
	if creature_audio!=null:
		if running: creature_audio.sync(delta)
		else: creature_audio.pause()
func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	var accepted:=super.receive_damage(id,amount,melee,effect)
	if accepted and creature_audio!=null: creature_audio.sync(0.0)
	return accepted
