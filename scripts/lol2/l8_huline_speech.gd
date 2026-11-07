extends Node3D
## Original actor-bound cues, with a modern one-shot near-actor E trigger.
const State=preload("res://scripts/lol2/l8_huline_speech_state.gd")
const ROOT:="res://assets/lol2/generated/l8_huline_speech/"
var host:Node3D
var voice:AudioStreamPlayer
var hint:Label
var streams:Dictionary={}
var loaded:=""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_huline_speech.gd").new();n.host=map;n.name="L8HulineSpeech";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func input_locked()->bool:return state().active!=""
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 voice=AudioStreamPlayer.new();add_child(voice)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"audio.json"))
 for cue in State.SAMPLES:
  var clip:Dictionary=manifest.clips[str(cue)]
  assert(clip.samples==State.SAMPLES[cue] and clip.rate==22050 and FileAccess.get_sha256(clip.path)==clip.wav_sha256,"Huline original speech media differs")
  streams[cue]=AudioStreamWAV.load_from_file(clip.path)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,430);canvas.add_child(hint)
func reachable(id:String)->bool:
 if not State.CUES.has(id):return false
 var pop=host.act2_creatures
 if not pop.state.actors[id].present or pop.state.actors[id].health<=0:return false
 if id=="23" and host.get_node("L8Tribe").state().phase!="complete":return false
 var delta:Vector3=pop.bodies[id].position+Vector3.UP*45-host.camera.global_position
 if delta.length()>160 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position+delta,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func target()->String:
 for id in State.CUES:
  if id not in state().heard and reachable(id):return id
 return ""
func start(id:String)->bool:
 if input_locked() or id in state().heard or host.player_form!=0 or not host.starting_magic.world_active() or not reachable(id):return false
 var s:=state().duplicate(true);s.active=id;s.elapsed=0.0;host.quest_state[State.KEY]=s;play_current();return true
func play_current():
 if not input_locked():voice.stop();loaded="";return
 if loaded!=state().active:
  loaded=state().active;voice.stream=streams[State.CUES[loaded]];voice.play(state().elapsed)
 elif absf(voice.get_playback_position()-float(state().elapsed))>0.5:voice.play(state().elapsed)
 voice.pitch_scale=Engine.time_scale;voice.stream_paused=not host.starting_magic.movie_world_active()
func finish():
 if not input_locked():return
 var s:=state().duplicate(true);s.heard.append(s.active);s.active="";s.elapsed=0.0;host.quest_state[State.KEY]=s;play_current()
func _process(delta):
 if input_locked():
  play_current()
  if host.starting_magic.movie_world_active():
   var s:=state().duplicate(true);s.elapsed=minf(State.duration(s.active),float(s.elapsed)+delta);host.quest_state[State.KEY]=s
   if s.elapsed>=State.duration(s.active):finish()
 else:
  if loaded!="":play_current()
 hint.text="Enter — Skip speech" if input_locked() else ("E — Listen" if host.player_form==0 and host.starting_magic.world_active() and target()!="" else "")
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo:return
 if input_locked():
  if event.keycode==KEY_ENTER and host.starting_magic.movie_world_active():finish();get_viewport().set_input_as_handled()
  return
 if event.keycode!=KEY_E or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return
 var id:=target()
 if id!="" and start(id):get_viewport().set_input_as_handled()
