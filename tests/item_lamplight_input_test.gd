extends "res://tests/item_consumables_input_test.gd"
const EGG:="act2:L13_RC:item70"
const EXTRA:="act2:L13_RC:item71"
func brightness()->float:
 await RenderingServer.frame_post_draw
 var image:Image=root.get_texture().get_image()
 var total:=0.0;var count:=0
 for y in range(120,300,8):
  for x in range(320,960,8):
   var c:Color=image.get_pixel(x,y);total+=c.get_luminance();count+=1
 return total/float(count)
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([EGG,EXTRA]):return
 var dark:float=await brightness();await picture("lamplight_before")
 if not await use_food(EGG):return
 var timer:float=scene.item_effects.state().low_light
 if not require(EGG not in scene.carried_collected and timer>59 and timer<=60 and Engine.get_meta("lol2_item_low_light",false),"Actual eggs consume once and start guide60s"):return
 var lit:float=await brightness();await picture("lamplight_after")
 print("LAMPLIGHT_BRIGHTNESS before=",dark," after=",lit)
 if not require(lit>dark+0.01,"Actual rendered world becomes brighter with existing full-bright row"):return
 if not await use_food(EXTRA):return
 if not require(EXTRA in scene.carried_collected and is_instance_valid(scene.inventory),"Active vision refuses extra eggs without loss"):return
 var held:float=scene.item_effects.state().low_light
 await ticks(90)
 if not require(scene.item_effects.state().low_light==held,"Paused inventory does not use play time"):return
 await tap(KEY_ESCAPE)
 if not await disk_cycle("lamplight_active"):return
 if not require(scene.item_effects.state().low_light>0 and scene.item_effects.state().spent.count(EGG)==1 and Engine.get_meta("lol2_item_low_light",false),"F5/F9 retains spent source and visible effect"):return
 for tick in 4000:
  await physics_frame
  if scene.item_effects.state().low_light==0:break
 if not require(scene.item_effects.state().low_light==0 and not Engine.get_meta("lol2_item_low_light",true) and scene.resets==0,"Ordinary play expires sight and restores default rendering without recovery"):return
 print("PASS Lamplight actual I/right, rendered brighter world, no duplicate consumption, pause/play clock, F5/F9 and ordinary60s expiry; disclosed grant/NPC fixtures")
 quit()
