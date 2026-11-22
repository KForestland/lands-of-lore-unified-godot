extends "res://tests/helpers/g15_world_spell_input.gd"
## Shared-dispatch component: learned API + inert receiver are explicit test
## fixtures. Real keys/clicks exercise UI/admission; no quest-cast claim.
class Receiver extends Node:
	var accepts := false
	var received := []
	func accepts_player_spell(_id: String) -> bool: return accepts
	func receive_player_spell(id: String) -> bool: received.append(id); return true
func _initialize():main.call_deferred()
func modern_button(school:String)->Button:
	var word:String=scene.starting_magic.SpellBook.NAMES[school]
	for candidate in scene.starting_magic.panel.find_children("*","Button",true,false):
		if candidate.text.begins_with(word):return candidate
	return null
func main():
	use_guard=false
	if not await boot_map("L13_RC"): return
	var magic=scene.starting_magic
	# Freeze only this component's regen/cooldown clock for exact debit assertions.
	magic.set_process(false)
	var receiver := Receiver.new();scene.add_child(receiver)
	var hud=scene.interface_hud
	# Presentation-only fixture exposes the normally hidden modern panel while
	# real Tab/Blue opens the classic panel. No world or resource state changes.
	magic.panel.show()
	await tap(KEY_TAB)
	await button(MOUSE_BUTTON_LEFT,hud.blue_button.get_global_transform_with_canvas()*(hud.blue_button.size*0.5))
	if not require(hud.spell_bar.visible,"Real Blue click opens classic spell bar"):return
	for school in ["spark","heal"]:
		if not require(modern_button(school)!=null and modern_button(school).is_visible_in_tree() and hud.spell_buttons[school].is_visible_in_tree(),"Starting school remains visible on both panels: "+school):return
	for school in ["curse","mists","prism","summon"]:
		if not require(modern_button(school)!=null and not modern_button(school).is_visible_in_tree() and not hud.spell_buttons[school].is_visible_in_tree(),"Unlearned school hidden on both actual panels: "+school):return
	await picture("r117_unlearned_panels")
	for key in [KEY_3,KEY_4,KEY_5,KEY_6]:
		var unlearned_before: Dictionary=magic.magic_state().duplicate(true)
		await tap(key)
		if not require(magic.magic_state()==unlearned_before and magic.notice_text()=="That spell is not learned","Unlearned number key refuses without selection/debit"):return
	await tap(KEY_TAB);magic.panel.hide()
	if not require(magic.learn_spell_group("dampen"),"Explicit learning API fixture"):return
	await tap(KEY_3)
	if not require(magic.magic_state().spell=="curse" and modern_button("curse").visible and hud.spell_buttons.curse.visible,"Learning reveals/selects Curse on both panels"):return
	var mana_before: int=magic.magic_state().player.mana
	if not require(magic.use_stored_spell("mists")=={"used":true,"learned":true} and magic.magic_state().spell=="curse" and magic.magic_state().player.mana==mana_before,"Stored API first use learns without a cast, debit or changing selection"):return
	if not require(magic.use_stored_spell("mists").used==false and receiver.received.is_empty() and magic.magic_state().player.mana==mana_before,"Later stored use shares target refusal and leaves consumption to the inventory owner"):return
	var before: Dictionary=magic.magic_state().duplicate(true)
	await tap(KEY_Q)
	if not require(magic.magic_state()==before and receiver.received.is_empty(),"Absent target refuses without effects or debit"):return
	receiver.accepts=true
	await tap(KEY_Q)
	if not require(receiver.received==["curse1"] and magic.magic_state().player.mana==int(before.player.mana)-1,"Real Q routes learned named cast to component receiver at fixed cost"):return
	var spent: Dictionary=magic.magic_state().duplicate(true)
	await tap(KEY_Q)
	if not require(magic.magic_state()==spent and receiver.received.size()==1 and magic.notice_text()=="Wait a moment before casting again","Ordinary cooldown refuses repeated key"):return
	var prior_notice_time:float=magic.notice_time
	await tap(KEY_TAB)
	await button(MOUSE_BUTTON_LEFT,hud.magic_button.get_global_transform_with_canvas()*(hud.magic_button.size*0.5))
	if not require(hud.hint.text=="Wait a moment before casting again" and magic.notice_time==prior_notice_time,"Real GUI cooldown refusal is visible even with identical text/timer on the held component clock"):return
	await tap(KEY_TAB)
	magic.set_process(true);await frames(40);magic.set_process(false)
	if not require(magic.learn_spell_group("prism"),"Explicit Prism learning fixture"):return
	scene.item_effects.state().ancient_charges=1
	await tap(KEY_5)
	mana_before=magic.magic_state().player.mana
	await tap(KEY_Q,false,true)
	if not require(receiver.received.back()=="prism5" and scene.item_effects.state().ancient_charges==0 and magic.magic_state().player.mana==mana_before,"RealShiftQ keeps the existing one-charge Ancient Stone free-cast rule"):return
	# Paused and cursor admission stay with the existing world owner.
	await tap(KEY_6)
	if not require(magic.magic_state().spell=="prism" and magic.notice_text()=="That spell is not learned","Unlearned key6 cannot replace learned Prism selection"):return
	await picture("g15_shared_prism")
	if not await disk_cycle("g15_shared_spellbook"):return
	magic=scene.starting_magic;magic.set_process(false)
	if not require(magic.magic_state().spell=="prism" and magic.magic_state().spellbook.learned==["curse1","mists1","mists3","prism5"],"RealF5/F9 persists new selected school and learned casts"):return
	await tap(KEY_TAB)
	await frames(3)
	hud=scene.interface_hud
	if not require(not modern_button("summon").visible and not hud.spell_buttons.summon.visible,"RealF9 keeps unlearned Summon hidden on both panels"):return
	await button(MOUSE_BUTTON_RIGHT,hud.magic_button.get_global_transform_with_canvas()*(hud.magic_button.size*0.5))
	if not require(magic.magic_state().spell=="spark","Real HUD right-click cycles past hidden Summon back to Spark"):return
	print("PASS G15 shared real-key selection/refusals/component dispatch/cooldown, rendered school label, actualF5/F9, real HUD cycle; fixture learning/receiver disclosed, no eight-quest-casts claim")
	quit()
