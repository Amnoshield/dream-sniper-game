extends CanvasLayer


@export var scores:Dictionary #Stores player IDs and scores
@export var text_label:RichTextLabel


func _ready() -> void:
	visible = false
	if multiplayer.get_unique_id() != $"..".name.to_int(): return #don't continue if you are not the current player
	
	MultiMaster.death.connect(add_death)
	for id in MultiMaster.players.keys():
		var player = MultiMaster.players[id]
		scores[id] = {"kills":0, "deaths":0, "name":player.name, "color":to_hex(player.color)}


@rpc("any_peer", "call_local", "reliable")
func add_death(killer:int, victim:int):
	if scores.has(killer):
		scores[killer].kills += 1
	else:
		scores[killer] = {"kills":1, "deaths":0}
		push_warning("player not found, adding them to the score board")
	
	if scores.has(victim):
		scores[victim].deaths += 1
	else:
		scores[victim] = {"kills":0, "deaths":1}
		push_warning("player not found, adding them to the score board")


func update():
	text_label.text = "%10s | %5s | %6s | %4s\n"% ["Players", "Kills", "Deaths", "Diff"]
	
	var score_keys = scores.keys()
	var sort_func = func(a, b):
		return scores[a].kills-scores[a].deaths > scores[b].kills-scores[b].deaths
	score_keys.sort_custom(sort_func) #Sort by best k-d
	
	for id in score_keys:
		#var player :Dictionary = MultiMaster.players[id]
		var player_color :String = scores[id].color
		var player_name :String = scores[id].name
		var player_kills :int = scores[id].kills
		var player_deaths :int = scores[id].deaths
		
		var line := "[color=#%s]%10s[/color] | %5s | %6s | %4s\n"%[
			player_color, player_name, player_kills, player_deaths, player_kills-player_deaths]
		
		text_label.text += line


func to_hex(color:Color):
	var full_hex:String = "%x"% color.to_rgba32()
	var fixed_hex = ("%6s"% full_hex.trim_suffix("ff")).replace(" ", "0")
	return fixed_hex


func show_scores():
	update()
	visible = true


func hide_scores():
	visible = false
