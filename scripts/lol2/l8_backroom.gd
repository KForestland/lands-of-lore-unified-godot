extends Node
## Original doorway voices in source order; modern audio-only presentation.
signal completed
const ROOT := "res://assets/lol2/generated/l8_backroom/"
const KEY := "l8_backroom"
const SEQUENCES := [[225,226,227,228,229,230,231,232,233,234,235],[236],[237]]
var host: Node
var voice: AudioStreamPlayer
var manifest: Dictionary = {}
var loaded_line := -1
static func initial()->Dictionary:return {"version":1,"completed":0,"active":false,"index":0,"elapsed":0.0}
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=5 or value.get("version")!=1 or not value.get("active") is bool:return "Invalid backroom state."
 for key in ["completed","index","elapsed"]:
  if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])) or float(value[key])<0:return "Invalid backroom progress."
 if value.completed!=int(value.completed) or value.index!=int(value.index) or value.completed>3:return "Invalid backroom index."
 if value.active:
  if value.completed>=3 or value.index>=SEQUENCES[int(value.completed)].size():return "Invalid active backroom sequence."
 elif value.index!=0 or value.elapsed!=0:return "Inactive backroom has pending playback."
 return ""
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 name="L8Backroom"
 process_mode=Node.PROCESS_MODE_ALWAYS
 voice=AudioStreamPlayer.new();add_child(voice)
 if FileAccess.file_exists(ROOT+"manifest.json"):
  var data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
  for row in data.clips:manifest[int(row.line)]=row
func available()->bool:
 for sequence in SEQUENCES:
  for line in sequence:
   if not manifest.has(line) or not FileAccess.file_exists(ROOT+manifest[line].wav):return false
 return true
func start()->Dictionary:
 if not host.quest_state.get("l8_journey",{}).get("admitted",false):return {"ok":false,"reason":"Enter the village first."}
 if not available():return {"ok":false,"reason":"This conversation is unavailable."}
 var current:=state()
 if current.active:return {"ok":false,"reason":"The conversation is still playing."}
 if current.completed==3:return {"ok":false,"reason":"There is nothing more to hear here."}
 var next:=current.duplicate(true)
 next.active=true
 host.quest_state[KEY]=next
 play_current()
 return {"ok":true}
func play_current():
 if not state().active:
  voice.stop();loaded_line=-1;return
 var line:int=SEQUENCES[int(state().completed)][int(state().index)]
 if not manifest.has(line):return
 if loaded_line!=line:
  voice.stream=AudioStreamWAV.load_from_file(ROOT+manifest[line].wav)
  loaded_line=line;voice.play(float(state().elapsed))
 elif absf(voice.get_playback_position()-float(state().elapsed))>0.5:voice.play(float(state().elapsed))
func advance_line():
 var next:=state().duplicate(true)
 if not next.active:return
 next.index+=1;next.elapsed=0.0
 if next.index>=SEQUENCES[int(next.completed)].size():
  next.active=false;next.completed+=1;next.index=0
 host.quest_state[KEY]=next
 play_current()
 if not next.active:completed.emit()
func skip_line()->bool:
 if not state().active:return false
 advance_line();return true
func _process(delta: float):
 if not state().active:
  if loaded_line!=-1:play_current()
  return
 if not available():return
 play_current()
 var next:=state().duplicate(true)
 next.elapsed+=delta
 host.quest_state[KEY]=next
 if next.elapsed>=float(manifest[loaded_line].duration):advance_line()
