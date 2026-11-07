extends "res://tests/l10_oil_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var scene=await load_oil()
 if scene==null:quit(1);return
 var spells=scene.starting_magic
 scene.camera.look_at(scene.player.position+Vector3(0,100,100),Vector3.UP)
 spells.select_spell("spark")
 for i in 180:await physics_frame
 var mana: int=spells.magic_state().player.mana
 var key:=InputEventKey.new();key.keycode=KEY_Q;key.pressed=true;key.ctrl_pressed=true
 Input.parse_input_event(key);Input.flush_buffered_events()
 check(spells.magic_state().player.mana==mana-3,"Ctrl+Q production input casts level3")
 check(not spells.cast(3) and spells.magic_state().player.mana==mana-3,"cooldown refuses duplicate level3 without debit")
 paused=true
 check(not spells.cast(3) and spells.magic_state().player.mana==mana-3,"paused level3 refused without debit")
 paused=false
 for i in 180:await physics_frame
 scene.interface_hud.set_cursor(true)
 mana=spells.magic_state().player.mana
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.ctrl_pressed=true
 scene.interface_hud._magic_input(click)
 check(spells.magic_state().player.mana==mana-3,"HUD Ctrl-click casts level3 through interface request")
 scene.interface_hud.set_cursor(false);spells.interface_request=true
 for i in 180:await physics_frame
 spells.select_spell("heal");mana=spells.magic_state().player.mana
 check(not spells.cast(3) and spells.magic_state().player.mana==mana,"level3 refuses Healing without debit")
 check(not spells.cast(2) and spells.magic_state().player.mana==mana,"unsupported charge refused without debit")
 var path:="res://tmp/l10_level3_input_check_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"real input branch save/reload")
 check(not scene.get_node("L10Oil").burned(),"misses never ignite oil")
 var input:=Save.read_save("res://tmp/l10_oil_earned_save.json","lol2-restoration-map-L10_DC")
 for bad in [{"version":1,"burned":1},{"version":2,"burned":true},{"version":1,"burned":true,"extra":0}]:
  var packet: Dictionary=input.state.duplicate(true);packet.quests.l10_oil=bad
  check(not Save.validate(packet,"lol2-restoration-map-L10_DC").is_empty(),"malformed oil packet rejected")
 var impossible: Dictionary=input.state.duplicate(true);impossible.quests.l10_barrel.phase=0;impossible.quests.l10_barrel.distance=0;impossible.quests.l10_oil={"version":1,"burned":true}
 check(not Save.validate(impossible,"lol2-restoration-map-L10_DC").is_empty(),"burn requires prior spill")
 scene.queue_free();await process_frame
 if failures==0:print("PASS headless Ctrl+Q/HUD Ctrl-click level3, cooldown/pause/spell/charge guards, real miss/debit/save; malformed oil and unearned burn rejected; separate input branch never merged")
 quit(0 if failures==0 else 1)
