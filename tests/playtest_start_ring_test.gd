extends SceneTree
const Ring=preload("res://scripts/lol2/playtest_start_ring.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var ring=Ring.new()
 assert(ring.preceding(0,0,false).is_empty())
 var document:Dictionary={"nested":{"value":0}}
 var held:Dictionary={"keys":["W"]}
 for i in range(12):
  document.nested.value=i
  ring.remember(document,i*15.0,held,Time.get_ticks_usec())
 document.nested.value=999;held.keys.clear()
 assert(ring.rows.size()==9 and ring.rows[0].t==45.0,"Bounded ring must retain the preceding sample, not just 120 seconds of rounded time")
 var sample:Dictionary=ring.preceding(46.9,31.9,false)
 assert(sample.t==45 and sample.coverage=="full")
 assert(JSON.parse_string(sample.json).nested.value==3 and sample.held.keys==["W"],"Live document and held-state mutation must not rewrite a prior snapshot")
 assert(ring.preceding(44,0,false).is_empty(),"A future or end snapshot cannot replace an absent preceding document")
 assert(ring.preceding(46.9,46,false).is_empty(),"No start whose prefix inputs have already expired")
 var early:Dictionary=ring.preceding(0,0,true)
 assert(early.t==45 and early.coverage=="clipped_to_first_saveable_snapshot","Short-session coverage must explicitly name the real first timestamp")
 # A look bucket ending exactly at capture is represented by the saved
 # camera, while the later bucket belongs to replay; held W seeds its press.
 var events:Array=[{"t":44.9,"kind":"key"},{"t":45.0,"kind":"look"},{"t":45.1,"kind":"look"}]
 assert(events.filter(func(e):return float(e.t)>float(sample.t)).size()==1)
 assert(ring.costs().samples==12 and ring.costs().max_bytes>0)
 ring.clear();assert(ring.rows.is_empty() and ring.costs().samples==0)
 # Native wheel input is a press-only impulse, not a held mouse button.
 var recorder:Node=root.get_node("PlaytestFeedback").recorder
 recorder.set_recording(true)
 await process_frame
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
 Input.parse_input_event(wheel);Input.flush_buffered_events()
 await process_frame
 assert(not recorder.held_buttons.has(str(MOUSE_BUTTON_WHEEL_DOWN)),"Press-only wheel must not seed a held wheel")
 assert(recorder.events.any(func(e):return e.kind=="mouse" and e.button==MOUSE_BUTTON_WHEEL_DOWN and e.pressed),"Wheel impulse remains in replay history")
 print("PASS start ring: bounded9, actual preceding time, immutable document/held inputs, no end-save fallback, retained-prefix and short-session coverage, look boundary")
 quit()
