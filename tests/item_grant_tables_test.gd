extends SceneTree
## Metadata/source contract. No player, input or earned-walk claim.
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Definitions=preload("res://scripts/lol2/item_definitions.gd")
const Tables=preload("res://scripts/lol2/item_grant_tables.gd")
const COUNTS={"L1_DC":106,"L3_DH":56,"L4_HJ":70,"L5_HC":18,"L7_DH":19,"L8_SJ":61,"L9_DR":35,"L10_DC":61,"L12_CM":36,"L13_RC":22,"L14_HT":25,"L16_CA":292,"L17_HC":26,"L19_BC":30,"L20_BB":19}
func read(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func _initialize():
 var facts:=read("res://tests/fixtures/item_grant_catalog_facts.json")
 var ids:=Items.all_ids();var expected:Array=[]
 for id:String in ids:
  var row:Dictionary=Items.row(id)
  expected.append({"id":id,"area":id.get_slice(":",1),"definition":int(row.definition),"identity":int(row.get("identity",0))})
 assert(facts.items==JSON.parse_string(JSON.stringify(expected)),"Catalog facts are current, including specials and charged variants")
 var literal:=RegEx.new();assert(literal.compile('"(act2:[^"]+)"')==OK)
 for hit in literal.search_all(FileAccess.get_file_as_string("res://scripts/lol2/act2_items_catalog.gd")):
  var id:String=hit.get_string(1)
  if Items.valid(id):assert(id in ids,"Every valid literal catalog special is enumerated: "+id)
 # Independent finite-domain probes use admission, not the enumerator's ranges.
 for prefix:String in ["act2:L14_HT:hopper_corpse","act2:L16_CA:pad_lichen","act2:L16_CA:lichen","act2:L10_DC:silverleaf"]:
  for number in 65536:
   var id:=prefix+str(number)
   if Items.valid(id):assert(id in ids,"Valid indexed special missing from facts: "+id)
 var total:=0;var owners:=0
 for area:String in COUNTS:
  var source:=read("res://scripts/lol2/native_scripts/"+area+".json")
  var table:=Tables.table(area);assert(not table.is_empty() and table.area==area)
  assert(table.native_sha256==FileAccess.get_sha256("res://scripts/lol2/native_scripts/"+area+".json"),"Table names the actual staged native source")
  var callers:Dictionary={}
  for object:Dictionary in source.objects:
   for event:Dictionary in object.events:
    if not event.has("group") or not event.has("stream"):continue
    var key:=str(int(event.stream))+"/"+str(int(event.group))
    var bytes:PackedByteArray=str(event.raw_hex).hex_decode()
    var trigger:int=int(bytes[6]) if str(object.ref).begins_with("region:") and bytes.size()>6 else int(event.kind)
    if not callers.has(key):callers[key]=[]
    callers[key].append({"object":str(object.ref),"event":trigger,"record_kind":int(event.kind)})
  for rows:Array in callers.values():
   rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
    if a.object!=b.object:return str(a.object)<str(b.object)
    if a.event!=b.event:return int(a.event)<int(b.event)
    return int(a.record_kind)<int(b.record_kind))
  var count:=0
  for group:Dictionary in source.groups:
   for command:Dictionary in group.commands:
    if int(command.opcode)!=3 or int(command.kind)!=1:continue
    count+=1
    var bytes:PackedByteArray=str(command.raw_hex).hex_decode();var offset:=int(command.file_offset)
    var row:=Tables.command(area,offset)
    assert(not row.is_empty() and int(row.file_offset)==offset)
    assert(int(row.group)==int(group.group) and int(row.stream)==int(group.stream))
    assert(int(row.target)==int(command.target) and int(row.identity)==bytes.decode_u32(4) and int(row.arg)==int(bytes[8]),"Exact original command fields")
    assert(int(row.definition)==Definitions.by_identity(bytes.decode_u32(4)),"Every original identity resolves independently")
    var linked:Array=callers.get(str(int(group.stream))+"/"+str(int(group.group)),[])
    assert(row.callers==JSON.parse_string(JSON.stringify(linked)),"Every direct object/event caller matches decoded input")
    assert(row.object==(linked[0].object if linked.size()==1 else "") and int(row.event)==(int(linked[0].event) if linked.size()==1 else -1))
    assert(row.id==Tables.id_of(area,offset) and row.action in ["log","owner"],"No live native gift switched on")
    assert(not Tables.for_id(row.id).is_empty(),"Table identities remain loadable independently of current grant admission")
    var rivals:Dictionary={}
    for other:Dictionary in facts.items:
     if other.area==area and int(other.definition)==int(row.definition):rivals[other.id]=true
    for other:Dictionary in table.commands.values():
     if other.id!=row.id and int(other.definition)==int(row.definition):rivals[other.id]=true
    var wanted:Array=rivals.keys();wanted.sort();assert(row.same_definition==wanted,"All placement/special/charged/native rivals enumerated")
    if row.action=="owner":
     owners+=1;assert(FileAccess.file_exists("res://"+str(row.owner)) and not str(row.evidence).is_empty())
    assert(str(row.arg_grade).begins_with("UNKNOWN"),"No meaning assigned to original argument bytes")
  assert(count==int(COUNTS[area]) and table.commands.size()==count,"Independent regenerated native count: "+area)
  total+=count
 assert(total==876 and owners>0)
 print("PASS fifteen independent native counts/876 commands, identities/offsets/callers, complete same-definition rivals, finite catalog coverage; all shipped rows log or owner")
 quit()
