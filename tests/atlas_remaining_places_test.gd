extends SceneTree
## Contract for the remaining nine data tables: native anchors, only learned Journal notes, correct incomplete/done states.
const Places=preload("res://scripts/lol2/atlas_places.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const Visibility=preload("res://scripts/lol2/region_visibility.gd")
const AREAS=["L1_DC","L3_DH","L5_HC","L9_DR","L10_DC","L16_CA","L17_HC","L19_BC","L20_BB"]
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;push_error(label)
func done_packet(row: Dictionary) -> Dictionary:
 var out: Dictionary={};var node: Dictionary=out
 var path: Array=row.done
 for i in path.size()-1:
  node[path[i]]={};node=node[path[i]]
 if row.has("contains"):node[path[-1]]=[row.contains]
 elif row.has("minimum_count"):node[path[-1]]=[74,75,76]
 elif row.has("values"):node[path[-1]]=row.values[0]
 else:node[path[-1]]=true
 return out
func run() -> void:
 var count:=0;var pins:=0
 for area in AREAS:
  var seen: Dictionary={};var rows: Array=Places.places(area)
  check(rows.size()>=4,area+" has places and ways out")
  check(Places.area_title(area,"")!="",area+" readable title")
  var nav: Array=Visibility.load_regions(area)
  check(not nav.is_empty(),area+" native navigation staged")
  var exits:=0
  for row in rows:
   count+=1
   check(not seen.has(row.id),area+" unique place "+row.id);seen[row.id]=true
   check(row.name!="" and row.source!="" and row.reveal>0,area+" named/evidenced reveal "+row.id)
   if row.kind=="exit":exits+=1;check(row.get("to","")!="",area+" exit destination "+row.id)
   var at:=Vector2(row.x,row.z);var nearest:=INF
   for region in nav:
    var polygon:=PackedVector2Array()
    for p in region[0]:polygon.append(Vector2(p[0],p[1]))
    if polygon.size()<3:continue
    if Geometry2D.is_point_in_polygon(at,polygon):nearest=0;break
    for i in polygon.size():nearest=minf(nearest,Geometry2D.get_closest_point_to_segment(at,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(at))
   check(nearest<=float(row.reveal),area+" place reachable by its reveal radius: "+row.id+" distance"+str(nearest))
  check(exits>0,area+" names at least one real way out")
  check(Places.active_plot(area,[],{}).is_empty(),area+" no undiscovered plot markers")
  for row in ([] if area=="L16_CA" else Places.plot(area)):
   pins+=1
   check(Journal.hints().has(row.note),area+" uses a real Journal note "+row.note)
   check(not Places.place(area,row.place).is_empty(),area+" marker anchor "+row.place)
   var notes: Array=[row.note]
   check(Places.active_plot(area,notes,{}).size()==1,area+" learned note marks unfinished objective "+row.note)
   var done:=done_packet(row);var before:=JSON.stringify(done)
   check(Places.active_plot(area,notes,done).is_empty(),area+" completed objective clears "+row.note)
   check(JSON.stringify(done)==before,area+" reading does not mutate saved owner state")
 check(Places.active_plot("L17_HC",["l17_cavern_exit"],{"l17_cavern_run":{"exit_region":-1}}).size()==1,"unreached -1 exit must not clear a plot marker")
 check(Places.active_plot("L19_BC",["l19_sewer_cross"],{"l19_sewer_forms":{"switches":[74,76]}}).size()==1,"two switches leave the sewer marker")
 check(Places.active_plot("L3_DH",["long_arm_before_passage"],{"museum_key_locks":{"loaded":[87]}}).size()==1,"another loaded lock does not clear the axe warning")
 check(Places.active_plot("L3_DH",["pilot_spark_before_plate"],{"museum_torches":{"pilot_state":0}}).size()==1,"unwoken torch niche leaves the marker")
 if failures==0:print("PASS remaining Atlas data: ",count," native-anchored places/exits, ",pins," learned-note markers; partial/complete/unknown states, no writes")
 quit(0 if failures==0 else 1)
