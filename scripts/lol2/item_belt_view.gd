extends Control
## The shared HUD owns visibility. Input and item transactions stay with the belt.
const Belt=preload("res://scripts/lol2/item_belt_state.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
var controller:Node
var interactive:=false
var cards:Array[Panel]=[]
var icons:Array[TextureRect]=[]
var counts:Array[Label]=[]
var title:Label
var footer:Label
var cache:Dictionary={}
var fingerprint:=""
var motion:Tween
var session_remaining:=60.0
var caption_remaining:=4.0
var legend_remaining:=6.0
func _ready():
 if not Engine.has_meta("lol2_belt_session_start"):Engine.set_meta("lol2_belt_session_start",Time.get_ticks_msec())
 session_remaining=maxf(0.0,60.0-float(Time.get_ticks_msec()-int(Engine.get_meta("lol2_belt_session_start")))/1000.0)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 offset_left=-164;offset_right=164;offset_top=-138;offset_bottom=-8
 title=Label.new();title.position=Vector2(-100,0);title.size=Vector2(528,24);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",18);title.add_theme_color_override("font_color",Color("f2d798"));title.add_theme_color_override("font_shadow_color",Color.BLACK);add_child(title)
 for index in 5:
  var card:=Panel.new();card.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(card);cards.append(card)
  if interactive:
   card.mouse_filter=Control.MOUSE_FILTER_STOP
   card.set_drag_forwarding(Callable(),func(_at,data):return data is Dictionary and Belt.valid_id(data.get("inventory_item")) and data.get("inventory_item") in controller.carried(),func(_at,data):controller.put_on_belt(str(data.inventory_item),index))
  var icon:=TextureRect.new();icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  card.add_child(icon);icons.append(icon)
  var count:=Label.new();count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.add_theme_color_override("font_shadow_color",Color.BLACK);count.add_theme_font_size_override("font_size",15);card.add_child(count);counts.append(count)
 footer=Label.new();footer.text="Drag here · Right-click: Put on belt" if interactive else "Wheel / [ ]  ·  E target  ·  F self";footer.position=Vector2(-50,111);footer.size=Vector2(428,19);footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;footer.add_theme_font_size_override("font_size",14);footer.add_theme_color_override("font_color",Color("d1bd91"));footer.add_theme_color_override("font_shadow_color",Color.BLACK);add_child(footer)
func _process(delta):
 if not interactive:
  var factor:float=clampf(get_viewport_rect().size.x/1280.0,0.7,1.15)
  pivot_offset=Vector2(164,130);scale=Vector2.ONE*factor
 elif is_instance_valid(controller.host.get("interface_hud")):visible=controller.host.interface_hud.visible
 session_remaining=maxf(0.0,session_remaining-delta);caption_remaining=maxf(0.0,caption_remaining-delta);legend_remaining=maxf(0.0,legend_remaining-delta)
 title.modulate.a=clampf(caption_remaining,0.0,1.0);footer.modulate.a=clampf(maxf(session_remaining,legend_remaining),0.0,1.0)
 if not is_instance_valid(controller):
  var hud:Node=get_parent()
  if hud.get("walkthrough")!=null:controller=hud.walkthrough.get("item_effects")
 if not is_instance_valid(controller):return
 if not interactive:
  var hud:Node=get_parent()
  visible=not is_instance_valid(controller.host.get("inventory")) and not (is_instance_valid(hud.get("sheet")) and hud.sheet.visible)
 var value:Dictionary=controller.belt_state()
 var owned:Array=controller.carried()
 var key:=str(value)+str(owned)+str(controller.smart_item)+str(controller.smart_missing)+str(controller.state().get("fire_crystals",{}))
 if key==fingerprint:
  if not interactive and (not controller.smart_item.is_empty() or not controller.smart_missing.is_empty()):title.modulate.a=1.0
  return
 fingerprint=key;caption_remaining=4.0;legend_remaining=6.0
 if is_instance_valid(motion):motion.kill()
 motion=create_tween().set_parallel(true)
 for index in 5:
  var relative:int=posmod(index-int(value.active)+2,5)
  var lengths:=[48.0,64.0,80.0,64.0,48.0]
  var x:=[0.0,56.0,124.0,212.0,280.0]
  var side:float=lengths[relative]
  motion.tween_property(cards[index],"position",Vector2(x[relative],104-side),0.13)
  motion.tween_property(cards[index],"size",Vector2(side,side),0.13)
  cards[index].z_index=2 if relative==2 else 1
  var style:=StyleBoxFlat.new();style.bg_color=Color(0.065,0.047,0.03,0.92);style.border_color=Color("ffe49a") if relative==2 and not controller.smart_item.is_empty() else Color("d7b568") if relative==2 else Color("746043");style.set_border_width_all(3 if relative==2 else 2);style.set_corner_radius_all(4);style.shadow_color=Color(1.0,0.74,0.18,0.65) if relative==2 and not interactive and not controller.smart_item.is_empty() else Color(0,0,0,0.6);style.shadow_size=8 if relative==2 and not interactive and not controller.smart_item.is_empty() else 4
  cards[index].add_theme_stylebox_override("panel",style)
  icons[index].position=Vector2(7,7);icons[index].size=Vector2(side-14,side-14)
  counts[index].position=Vector2(2,side-23);counts[index].size=Vector2(side-7,19)
  var id:String=Belt.resolve(value,index,owned)
  icons[index].texture=null;counts[index].text=""
  if not id.is_empty():
   var path:String=Catalog.inventory_icon(id)
   if not cache.has(path) and FileAccess.file_exists(path):cache[path]=ImageTexture.create_from_image(Image.load_from_file(path))
   icons[index].texture=cache.get(path)
   var quantity:int=owned.filter(func(item):return Belt.same_identity(item,id)).size()
   counts[index].text=str(controller.crystal_charges(id))+"c" if Catalog.use_kind(id)=="fire_crystal" else str(quantity)
 var active:String=Belt.resolve(value,int(value.active),owned)
 title.text=Belt.label(active) if not active.is_empty() else "Item belt"
 if not interactive and not controller.smart_item.is_empty():title.text="E — use "+Belt.label(controller.smart_item)
 elif not interactive and not controller.smart_missing.is_empty():title.text=controller.smart_missing
 if not interactive and (not controller.smart_item.is_empty() or not controller.smart_missing.is_empty()):title.modulate.a=1.0
