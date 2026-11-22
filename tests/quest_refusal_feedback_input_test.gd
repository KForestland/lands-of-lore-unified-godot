extends SceneTree
## Isolated actual input into the real wrappers; injected failed rule result,
## not a campaign/earned claim and no production ownership bypass.
class Host extends Node3D:
 var inventory:Node=null
 var notices:Array=[]
 func save_feedback(text:String)->void:notices.append(text)
class Pyre extends "res://scripts/lol2/l9_pyre.gd":
 func _ready()->void:pass
 func _process(_d:float)->void:pass
 func _physics_process(_d:float)->void:pass
 func active()->bool:return true
 func state()->Dictionary:return {"phase":3,"slots":{}}
 func reachable(_point:Vector3)->bool:return true
 func urn(_action:String,_item:String="")->Dictionary:return {"ok":false,"reason":"Keep the urn for the priest."}
class Chamber extends "res://scripts/lol2/l14_chamber_voices.gd":
 func _ready()->void:pass
 func _process(_d:float)->void:pass
 func offer()->Dictionary:return {"ok":false,"reason":"That item action could not be completed."}
func key(code:Key,down:bool)->void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
 Input.parse_input_event(event);Input.flush_buffered_events()
func _initialize()->void:run.call_deferred()
func run()->void:
 assert(DisplayServer.get_name()!="headless")
 var host:=Host.new();root.add_child(host);current_scene=host
 var pyre:=Pyre.new();pyre.host=host;host.add_child(pyre)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 await process_frame
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 assert(host.notices==["Keep the urn for the priest."],"A failed aimed Pyre E must display exactly its rule refusal")
 pyre.queue_free();await process_frame;host.notices.clear()
 var chamber:=Chamber.new();chamber.host=host;chamber.inside=true;host.add_child(chamber)
 chamber.panel=Control.new();chamber.add_child(chamber.panel)
 chamber.note=Label.new();chamber.panel.add_child(chamber.note)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 key(KEY_E,true);await process_frame;key(KEY_E,false);await process_frame
 assert(host.notices==["That item action could not be completed."] and chamber.note.text==host.notices[0],"Direct Chamber E displays the failed admission over its room")
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(300,150)
 Input.parse_input_event(click);Input.flush_buffered_events();await process_frame
 click=click.duplicate();click.pressed=false;Input.parse_input_event(click);Input.flush_buffered_events();await process_frame
 assert(host.notices.size()==2 and chamber.note.text==host.notices[1],"Direct Chamber click uses the same refusal display")
 print("PASS injected admission refusal through actual Pyre E and Chamber E/click; one plain visible line per event")
 quit()
