extends RefCounted
## L13 read-only adapters; geometry, cast receivers and actions stay with owners.
const Combat=preload("res://scripts/lol2/player_combat.gd")
const JOURNAL_HINTS:=[
 {"when":"l13_action_egg_globe","flag":"l13_egg_door","hint":"The globe is dark. Cast Spark at it (1, then Q).","enhanced_guard":"Owner15Nov, same hint in both editions"},
 {"when":"l13_action_egg_fixture","flag":"l13_eggs","hint":"The central fixture can be broken with Spark (1, then Q).","enhanced_guard":"Owner15Nov, same hint in both editions"},
 {"when":"l13_action_eye_first","flag":"l13_eggs","hint":"The eye switch must be opened first.","enhanced_guard":"Owner15Nov, existing prerequisite"},
 {"when":"l13_action_lift","flag":"l13_elevator","hint":"The elevator brain responds to Spark (1, then Q).","enhanced_guard":"Owner15Nov, existing E also retained"},
 {"when":"l13_action_spire","flag":"l13_spires","hint":"The spire is dark. Cast Spark at it.","enhanced_guard":"Owner15Nov, same hint in both editions"},
 {"when":"l13_action_web_living","flag":"l13_prison","hint":"Something still lives here.","enhanced_guard":"Owner15Nov, same actor21-39 gate"},
 {"when":"l13_action_web_pass","flag":"l13_belial","hint":"E - pass the web","enhanced_guard":"Owner15Nov, same entry action"}]
const FIXTURE_FIRST:="Something still lives here. The Ruloi on the high ledges stay up until the egg basin drains: break the light fixture above the eggs with Spark (1, then Q)."
## The maidens' refusal (the original's all-Ruloi condition, prop:253 / local 18): how many live, and what holds them.
static func maidens_line(host:Node3D)->String:
 var actors:Dictionary=host.act2_creatures.state.actors
 var living:=0
 for n in range(21,40):
  if float(actors.get(str(n),{}).get("health",0))>0:living+=1
 if living==0:return ""
 var line:="The maidens stay until every Ruloi is dead: %d still live." % living
 var basin:Node=host.get_node_or_null("L13Eggs")
 if basin!=null and not basin.state().vent_broken and others_alive(host):line+=" "+FIXTURE_FIRST.trim_prefix("Something still lives here. ")
 if float(actors.get("22",{}).get("health",0))>0:line+=" One waits above the lift."
 return line
## A living Ruloi 21-39 other than 22 (22 comes down at the lift without the basin; act2_creatures LEDGE_GLIDE).
static func others_alive(host:Node3D)->bool:
 var actors:Dictionary=host.act2_creatures.state.actors
 for n in range(21,40):
  if n!=22 and float(actors.get(str(n),{}).get("health",0))>0:return true
 return false
func row(kind:String,id:int=-1,delegate:bool=false)->Dictionary:
 var key:String={"egg":"egg_globe","vent":"egg_fixture","eye":"eye_first","lift":"lift","spire":"spire","web_wait":"web_living","web_pass":"web_pass"}[kind]
 var journal:String="l13_action_"+key
 for entry:Dictionary in JOURNAL_HINTS:
  if entry.when==journal:return {"key":kind+":"+str(id),"kind":kind,"id":id,"journal":journal,"message":entry.hint,"delegate_e":delegate}
 return {}
func pick(host:Node3D)->Dictionary:
 var web:Node=host.get_node_or_null("L13Belial")
 if web!=null and web.near_web():
  var r:=row("web_pass",-1,web.can_enter())
  # Lead 2026-11-15 (Grok 14:31Z): Ruloi 22 waits on its ledge above the lift; the line says where.
  return r
 var hit:Dictionary=Combat.aim_ray(host,384.0,3)
 if hit.is_empty():return {}
 var egg:Node=host.get_node_or_null("L13EggDoor")
 if egg!=null and not egg.state().opened and (hit.collider==egg.receiver or hit.collider==egg.face_body):return row("egg")
 var basin:Node=host.get_node_or_null("L13Eggs")
 if basin!=null and not basin.state().vent_broken and hit.collider==basin.receiver:return row("vent" if basin.state().eye_open else "eye")
 var lift:Node=host.get_node_or_null("L13Elevator")
 if lift!=null and lift.state().motion.remaining==0 and hit.collider==lift.brain_receiver:return row("lift",-1,lift.reachable())
 var spires:Node=host.get_node_or_null("L13Spires")
 if spires!=null:
  for id in spires.receivers:
   if hit.collider==spires.receivers[id] and str(id) not in spires.state().lit:return row("spire",int(id))
 return {}
func completed(host:Node3D,entry:Dictionary)->bool:
 match str(entry.kind):
  "egg":return host.get_node("L13EggDoor").state().opened
  "vent":return host.get_node("L13Eggs").state().vent_broken
  "eye":return host.get_node("L13Eggs").state().eye_open
  "lift":return host.get_node("L13Elevator").state().motion.remaining!=0
  "spire":return str(entry.id) in host.get_node("L13Spires").state().lit
  "web_wait":return host.get_node("L13Prison").all_ruloi_dead()
  "web_pass":return host.get_node("L13Belial").state().entered
 return true
