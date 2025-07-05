extends Panel


@export var template:RichTextLabel
@export var container:VBoxContainer


func _ready():
	MultiMaster.death.connect(add_death)


#func _process(_delta: float) -> void:
	#update_size()


func add_death(killer_id:int, victim_id:int, _method:String):
	var text = ""
	if killer_id != 0:
		var killer = MultiMaster.players[killer_id]
		var killer_color := to_hex(killer.color)
		var killer_name :String = killer.name
		text += "[color=%s]%s[/color] killed " %[killer_color, killer_name]
	
	var victim = MultiMaster.players[victim_id]
	var victim_color := to_hex(victim.color)
	var victim_name :String = victim.name
	text += "[color=%s]%s[/color]" %[victim_color, victim_name]
	
	var new_kill = template.duplicate()
	container.add_child(new_kill)
	new_kill.start(text)
	new_kill.visible = true
	update_size()

func update_size():
	var size_y = 0
	for child:RichTextLabel in container.get_children():
		if child.visible:
			size_y += child.size.y
	
	size.y = size_y
	container.size.y = size_y


func to_hex(color:Color) -> String:
	var full_hex:String = "%x"% color.to_rgba32()
	var fixed_hex = ("%6s"% full_hex.trim_suffix("ff")).replace(" ", "0")
	return fixed_hex
