extends RefCounted
## One legacy capability rule and table for normal loads and immutable F2 pins.
## Never changes source save bytes, mana, selected spell, health or story state.
const Book=preload("res://scripts/lol2/player_spell_book.gd")
const TABLE:="res://scripts/lol2/player_spell_teaching.json"
static var cached:Dictionary={}
static func table()->Dictionary:
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string(TABLE))
 return cached
static func at(root:Variant,path:String)->Variant:
 var value:Variant=root
 for key in path.split("."):
  if value is Dictionary:value=value.get(key)
  elif value is Array and key.is_valid_int() and int(key)>=0 and int(key)<value.size():value=value[int(key)]
  else:return null
 return value
static func migrate(saved:Dictionary,quests:Dictionary,area:String,carried:Array=[],spent:Array=[])->Dictionary:
 if saved.has("spellbook"):return saved # New games and explicit learned sets are authoritative.
 var next:=saved.duplicate(true)
 var book:=Book.initial()
 var evidence:={"quests":quests}
 var items:Array=carried.duplicate();items.append_array(spent)
 var history:Variant=quests.get("act2_items",{}).get("collected",[])
 if history is Array:items.append_array(history)
 for lesson:Dictionary in table().lessons:
  var known:bool=area in lesson.past_teaching_areas
  for proof:Dictionary in lesson.proofs:
   if at(evidence,proof.path)==proof.value:known=true
  for item:String in lesson.items:
   if item in items:known=true
  if known:book=Book.learn(book,str(lesson.group))
 next.spellbook=book
 return next

## F2 is an explicit playtest capability adapter, including for future pins that
## already contain a partial book. Normal modern loads still never infer spells.
static func prepare_start(packet:Dictionary,area:String)->Dictionary:
 var result:=packet.duplicate(true)
 var quests:Dictionary=result.get("quests",{})
 var inventory:Dictionary=result.inventory
 var saved:Dictionary=quests.get("player_magic_reward_state",inventory.get("magic",{}))
 if saved.is_empty():saved=preload("res://scripts/lol2/player_magic_state.gd").initial()
 var old:=saved.duplicate(true);old.erase("spellbook")
 var inferred:=migrate(old,quests,area,inventory.get("collected",[]),inventory.get("item_effects",{}).get("spent",[]))
 var book:Dictionary=saved.get("spellbook",Book.initial()).duplicate(true)
 for id:String in inferred.spellbook.learned:
  if id not in book.learned:book.learned.append(id)
 var taught:=saved.duplicate(true);taught.spellbook=Book.canonical(book)
 if inventory.has("magic"):inventory.magic=taught.duplicate(true)
 if quests.has("player_magic_reward_state") or not inventory.has("magic"):quests.player_magic_reward_state=taught
 result.quests=quests
 return result

## Named mandatory/side-quest locks only. The owner's query is the existing
## read-only admission, never its action. Skip learned required casts before any ray
## query; no per-frame acquisition after the one saved lesson.
static func required_cast(row:Dictionary,form:int)->String:
 if row.has("cast"):return str(row.cast)
 if row.has("echo_cast"):return str(row.echo_cast)
 if row.group=="dampen":return "curse1"
 return "curse2" if form==2 else "curse3"
static func live_candidates(host:Node,book:Dictionary)->Array:
 var result:Array=[]
 for row:Dictionary in table().get("live_lessons",[]):
  if str(host.get("area_id"))!=str(row.area):continue
  # A partial modern book may know the required charge already. Do not
  # teach unrelated charges or emit a new lesson merely to complete a group.
  if required_cast(row,int(host.get("player_form"))) in book.learned:continue
  if row.has("forms") and int(host.get("player_form")) not in row.forms.map(func(value):return int(value)):continue
  var owner:Node=host.get_node_or_null(str(row.owner))
  if owner==null or not owner.has_method(str(row.query)):continue
  var eligible:bool=bool(owner.call(str(row.query),str(row.cast))) if row.has("cast") else bool(owner.call(str(row.query)))
  if eligible:result.append(row)
 return result

static func echo_candidates(host:Node,book:Dictionary)->Array:
 var result:Array=[]
 for row:Dictionary in table().get("live_lessons",[]):
  if str(host.get("area_id"))!=str(row.area):continue
  if row.has("forms") and int(host.get("player_form")) not in row.forms.map(func(value):return int(value)):continue
  var id:String=required_cast(row,int(host.get("player_form")))
  if id not in book.learned:continue
  if not row.has("cast") and row.group in ["dampen","control"]:
   var curse:Node=host.get("curse")
   if curse==null or not curse.accepts_player_spell(id):continue
  var owner:Node=host.get_node_or_null(str(row.owner))
  if owner==null:continue
  var eligible:bool=bool(owner.call(str(row.query),str(row.cast))) if row.has("cast") else bool(owner.call(str(row.query)))
  if not eligible:continue
  if row.has("echo_cast") and not owner.accepts_player_spell(str(row.echo_cast)):continue
  result.append(row)
 return result
