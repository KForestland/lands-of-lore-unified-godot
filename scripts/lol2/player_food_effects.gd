extends RefCounted
## Guide-defined item effects, hosted by PlayerItemController. Native scheduling
## is not inferred: Mandrake5s and Gorgonite60s use the guide's durations.
const MAX_SLEEP:=5.0
static func sleeping(host:Object)->bool:
 var effects=host.get("item_effects")
 return is_instance_valid(effects) and float(effects.state().get("mandrake_sleep",0.0))>0.0
static func apply(controller:Node,id:String)->bool:
 var host:Node=controller.host
 var kind:String=controller.Catalog.use_kind(id)
 if not controller.can_consume(id) or host.starting_magic.health()<=0:return false
 match kind:
  "mandrake":
   if not controller.consume_item(id):return false
   var saved:Dictionary=host.starting_magic.magic_state().duplicate(true)
   saved.player.mana=mini(int(saved.player.maximum),int(saved.player.mana)+20)
   host.starting_magic.commit(saved)
   host.starting_magic.set_health(mini(controller.PlayerHealth.limit_for(host),host.starting_magic.health()+40))
   controller.state().mandrake_sleep=MAX_SLEEP
   host.save_feedback("Mandrake restores health and mana. You fall asleep for five seconds.")
  "war_cluster":
   if controller.state().has("war_cluster"):
    host.save_feedback("A War Cluster is already active.");return false
   if not controller.consume_item(id):return false
   controller.state().war_cluster={"remaining":60.0,"bonus":6}
   host.starting_magic.set_health(host.starting_magic.health()+6)
   host.save_feedback("War Cluster:20% borrowed health for one minute.")
  "gorgonite":
   # Refuse before consumption when the existing form owner cannot admit it.
   if host.curse.state.phase in [1,3] or not host.curse.requests_enabled():return false
   if not controller.consume_item(id):return false
   if int(host.curse._draw(0,99))<5:host.curse.request_timed_form(1,60.0)
   host.save_feedback("You eat the Gorgonite nodule.")
  "inert_food":
   if not controller.consume_item(id):return false
   host.save_feedback("You eat the failed mixture. It has no useful effect.")
  "mind_cluster":
   var Atlas=load("res://scripts/lol2/atlas_explored.gd")
   var area:String=Atlas.area_of(host)
   if area.is_empty():return false
   if not controller.consume_item(id):return false
   var explored:Dictionary=Atlas.stored(host)
   explored.areas[area]={"full":true,"regions":[]}
   host.atlas_explored=explored
   host.save_feedback("The Mind Cluster reveals this area's map.")
  _:return false
 return true
