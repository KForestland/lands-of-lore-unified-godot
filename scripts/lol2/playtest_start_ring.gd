extends RefCounted
## Immutable diagnostic start documents, never player slots. Times are actual
## monotonic capture times; no pose reconstruction or approximate fallback.
const COUNT := 9
const INTERVAL := 15.0
const SLOW_INTERVAL := 60.0
const FRAME_BUDGET_US := 5000
var rows:Array=[]
var count:=0
var total_us:=0
var maximum_us:=0
var minimum_us:=0
var maximum_bytes:=0
var capture_main_max_us:=0
var capture_main_total_us:=0
var worker_max_us:=0
var finish_main_max_us:=0
func clear()->void:
 rows.clear();count=0;total_us=0;maximum_us=0;minimum_us=0;maximum_bytes=0
 capture_main_max_us=0;capture_main_total_us=0;worker_max_us=0;finish_main_max_us=0
func remember(document:Dictionary,t:float,held:Dictionary,started_us:int)->void:
 var encoded:=JSON.stringify(document,"",true,true)
 remember_encoded({"json":encoded,"cost_us":Time.get_ticks_usec()-started_us,"bytes":encoded.to_utf8_buffer().size(),"captured_json_sha256":encoded.sha256_text()},t,held)
func remember_encoded(result:Dictionary,t:float,held:Dictionary)->void:
 var row:Dictionary=result.duplicate()
 row["t"]=t;row["held"]=held.duplicate(true)
 rows.append(row)
 while rows.size()>COUNT:rows.pop_front()
 var cost:int=int(result.cost_us)
 count+=1;total_us+=cost;maximum_us=maxi(maximum_us,cost)
 minimum_us=cost if count==1 else mini(minimum_us,cost)
 maximum_bytes=maxi(maximum_bytes,int(result.bytes))
 capture_main_total_us+=int(result.get("capture_main_us",0))
 capture_main_max_us=maxi(capture_main_max_us,int(result.get("capture_main_us",0)))
 worker_max_us=maxi(worker_max_us,int(result.get("worker_us",0)))
func costs()->Dictionary:
 return {"samples":count,"mean_us":float(total_us)/maxi(1,count),"min_us":minimum_us,"max_us":maximum_us,"max_bytes":maximum_bytes,"retained":rows.size(),"capture_main_max_us":capture_main_max_us,"capture_main_mean_us":float(capture_main_total_us)/maxi(1,count),"worker_max_us":worker_max_us,"finish_main_max_us":finish_main_max_us}
func preceding(requested:float,retained_from:float,short_window:bool)->Dictionary:
 var chosen:Dictionary={}
 for row:Dictionary in rows:
  if float(row.t)<retained_from:continue
  if float(row.t)<=requested and (chosen.is_empty() or float(row.t)>float(chosen.t)):chosen=row
 if not chosen.is_empty():
  var result:=chosen.duplicate(true);result["coverage"]="full";return result
 # An early report can begin only at the first genuine saveable state. Name
 # the missing prefix explicitly; never pretend this covers the full window.
 if short_window:
  for row:Dictionary in rows:
   if float(row.t)>=retained_from:
    var result:=row.duplicate(true);result["coverage"]="clipped_to_first_saveable_snapshot";return result
 return {}
