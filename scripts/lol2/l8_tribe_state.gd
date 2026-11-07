extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY:="l8_tribe"
const TARGET:="tribe:initiation"
# Saved sparring stamina is separate from campaign HP; modern nonlethal adapter.
const PLAYER_STAMINA:=500
const DANIEL_STAMINA:=600
const DURATIONS:=[5.83328798185941, 0.6907936507936508, 3.7666213151927437, 2.966621315192744]
static func initial()->Dictionary:return {"version":1,"slots":{},"phase":"idle","index":0,"elapsed":0.0,"player":0,"daniel":0,"counter":0.0}
static func member(s:Dictionary)->bool:return s.get("phase","idle") in ["complete","departed"]
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=8 or s.get("version")!=1 or not s.get("slots") is Dictionary or s.get("phase") not in ["idle","intro","fight","complete","departed"]:return "Invalid tribe initiation."
 for key in ["index","elapsed","player","daniel","counter"]:
  if not (s.get(key) is int or s.get(key) is float) or not is_finite(s[key]) or s[key]<0:return "Invalid initiation number."
 for key in ["index","player","daniel"]:
  if s[key]!=floor(s[key]):return "Invalid initiation count."
 if s.player>PLAYER_STAMINA or s.daniel>DANIEL_STAMINA or s.counter>=1.2:return "Invalid sparring stamina or clock."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid initiation offering."
 if s.phase=="idle":
  if not s.slots.is_empty() or s.index!=0 or s.elapsed!=0 or s.player!=0 or s.daniel!=0 or s.counter!=0:return "Unstarted initiation changed."
  return ""
 if s.slots.size()!=1 or not s.slots.has(TARGET):return "Initiation needs one offering."
 var slot:Dictionary=s.slots[TARGET]
 if slot.size()!=3 or not slot.committed or slot.receipts!=[TARGET] or Items.definition(slot.occupied)!=117:return "Invalid initiation leaf receipt."
 var items:Dictionary=quests.get("act2_items",{})
 if slot.occupied in items.get("carried",[]) or slot.occupied not in items.get("collected",[]):return "Initiation leaf is duplicated or unearned."
 if not quests.get("l8_journey",{}).get("admitted",false) or not quests.get("l10_silverleaf",{}).get("grown",false):return "Initiation requires village admission and earned Silverleaf."
 if s.phase=="intro":
  if s.index>3 or s.elapsed>=DURATIONS[int(s.index)] or s.player!=PLAYER_STAMINA or s.daniel!=DANIEL_STAMINA or s.counter!=0:return "Invalid initiation speech."
 else:
  if s.index!=0 or s.elapsed!=0:return "Finished speech retains a clock."
  if s.phase=="fight" and (s.player==0 or s.daniel==0):return "Finished bout still active."
  if s.phase in ["complete","departed"] and ((s.player>0 and s.daniel>0) or (s.player==0 and s.daniel==0) or s.counter!=0):return "Incomplete bout claims membership."
 return ""
static func offer(s:Dictionary,inventory:Array,item:String)->Dictionary:
 if s.phase!="idle":return Kit.refuse("The initiation has already begun.")
 if Items.definition(item)!=117:return Kit.refuse("Offer a Silverleaf to begin the initiation.")
 var snap:=Kit.empty_snapshot(inventory,64);snap.slots=s.slots.duplicate(true)
 var recipe:={"target":TARGET,"accepts":[item],"retrievable":false,"forms":["human"]}
 var result:=Kit.offer(snap,recipe,item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,TARGET)
 if not result.ok:return result
 var next:=initial();next.slots=result.snapshot.slots;next.phase="intro";next.player=PLAYER_STAMINA;next.daniel=DANIEL_STAMINA
 return {"ok":true,"state":next,"inventory":result.snapshot.inventory}
