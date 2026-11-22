extends RefCounted
## Brady printed41: Lamplight eggs give low-light vision for one minute.
## Presentation adapter: the existing native shade row63, not an emitted light.
static func use(controller:Node,id:String)->bool:
 if controller.Catalog.definition(id)!=114 or not controller.can_consume(id) or controller.host.starting_magic.health()<=0:return false
 if float(controller.state().get("low_light",0.0))>0:
  controller.host.save_feedback("Low-light vision is already active.");return false
 if not controller.consume_item(id):return false
 controller.state().low_light=60.0
 render(controller)
 controller.host.save_feedback("Lamplight eggs: low-light vision for one minute.")
 return true
static func render(controller:Node):
 var active:bool=float(controller.state().get("low_light",0.0))>0
 Engine.set_meta("lol2_item_low_light",active)
 RenderingServer.global_shader_parameter_set("lol2_item_low_light",active)
static func clear():
 Engine.set_meta("lol2_item_low_light",false)
 RenderingServer.global_shader_parameter_set("lol2_item_low_light",false)
