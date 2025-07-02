extends Control

@export var level_info:JSON
var current_level_idx := -1

@export_category("UI")
@export var joinCode:LineEdit
@export var playerName:LineEdit
@export var chat_box:RichTextLabel
@export var player_container:FlowContainer
@export var player_template:Label
@export var player_counter:Label
@export var level_select:OptionButton
@export var color_picker:ColorPickerButton

@export_category("Buttons")
@export var start:Button
@export var join:Button
@export var host:Button
@export var leave:Button


func _ready():
	level_select_setup()
	
	color_picker.color = MultiMaster.player_info.color
	
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joinCode.text = MultiMaster.last_server_ip
	
	MultiMaster.player_connected.connect(player_joined)
	MultiMaster.player_disconnected.connect(player_left)
	MultiMaster.player_info_updated.connect(_on_player_info_update)
	MultiMaster.kicked.connect(kicked)
	MultiMaster.msg_received.connect(chat)
	multiplayer.connection_failed.connect(connection_failed)
	
	Noray.on_disconnect_from_host.connect(_disconnect_from_noray)
	
	update_player_counter()
	
	if !MultiMaster.player_info["name"].is_empty():
		playerName.text = MultiMaster.player_info["name"].rstrip("⭐")
	
	if MultiMaster.players.size() > 1 or (MultiMaster.is_host and MultiMaster.players.size()==1):
		if MultiMaster.is_host:
			start.disabled = false
			level_select.disabled = false
			level_select.flat = false
		else:
			start.disabled = true
			level_select.disabled = true
			level_select.flat = true
		leave.disabled = false
		host.disabled = true
		join.disabled = true
		playerName.editable = false
		joinCode.editable = false
		
		for player in MultiMaster.players.keys():
			player_joined(player, MultiMaster.players[player])
	elif MultiMaster.players.size() == 1:
		leave_lobby()
	else:
		start.disabled = true
		leave.disabled = true
		host.disabled = false
		join.disabled = false
		playerName.editable = true
		joinCode.editable = true

func kicked(msg:String):
	chat(msg)

func _on_host_pressed() -> void:
	var username = check_name(playerName.text)
	if !username:
		return
	
	chat("[color=green]Creating lobby ...[/color]")
	await get_tree().create_timer(0.01).timeout
	playerName.text.strip_edges()
	MultiMaster.player_info["name"] = playerName.text+"⭐"
	MultiMaster.host()
	
	start.disabled = false
	leave.disabled = false
	host.disabled = true
	join.disabled = true
	playerName.editable = false
	level_select.disabled = false
	level_select.flat = false
	
	chat("Lobby code: %s" % Noray.oid)
	chat("[color=green]Started hosting.[/color]")

func _on_join_pressed() -> void:
	var username = check_name(playerName.text)
	if !username:
		return
	
	if joinCode.text.is_empty():
		chat("[color=red]Lobby code required[/color]")
		return
	
	MultiMaster.last_server_ip = joinCode.text
	MultiMaster.join(joinCode.text)
	
	chat("Joining lobby, this may take a minute ...")
	MultiMaster.player_info["name"] = playerName.text
	start.disabled = true
	leave.disabled = false
	host.disabled = true
	join.disabled = true
	playerName.editable = false
	joinCode.editable = false

func _on_start_pressed() -> void:
	if current_level_idx == -1:
		chat("[color=red]No Level Selected[/color]")
		return
	
	var levelPath = level_select.get_item_metadata(current_level_idx)
	MultiMaster.load_game.rpc(levelPath)

func _on_quit_game_pressed() -> void:
	get_tree().quit()

func _on_leave_pressed() -> void:
	leave_lobby()

func leave_lobby():
	MultiMaster.remove_multiplayer_peer()
	for child in player_container.get_children():
		if child.name != "default":
			child.queue_free()
	
	start.disabled = true
	leave.disabled = true
	host.disabled = false
	join.disabled = false
	playerName.editable = true
	joinCode.editable = true
	
	level_select.disabled = true
	level_select.flat = true
	level_select.select(-1)
	current_level_idx = -1
	
	chat("Left lobby")
	update_player_counter()

func chat(text:String):
	chat_box.text += text+'\n'

func player_joined(id, info):
	print("Player joined")
	chat("Player %s joined" % info.name)
	var new_player:Label = player_template.duplicate()
	new_player.name = str(id)
	new_player.text = info.name
	new_player.modulate = Color(info.color)
	player_container.add_child(new_player)
	new_player.show()
	update_player_counter()
	
	if id != multiplayer.get_unique_id() and MultiMaster.is_host:
		_update_selected_level.rpc_id(id, current_level_idx)

func player_left(id):
	if id == 1:
		chat("[color=yellow]Host left. Lobby closing ...[/color]")
		leave_lobby()
	else:
		for child in player_container.get_children():
			if child.name == str(id):
				child.queue_free()
	
	update_player_counter()

func connection_failed():
	chat("[color=yellow]Connection to server failed ☹️[/color]")
	leave_lobby()

func update_player_counter():
	print("updating player counter")
	player_counter.text = str(MultiMaster.players.size())+"/"+str(MultiMaster.MAX_CONNECTIONS+1)

func check_name(username:String):
	username = username.strip_edges()
	if username.ends_with("⭐"):
		chat("[color=red]Username can't end with \"⭐\"[/color]")
		return false
	elif username.is_empty():
		chat("[color=red]Username required[/color]")
		return false
	elif username.length() > 10:
		chat("[color=red]Username can't be longer than 10 characters[/color]")
		return false
	
	return username

func level_select_setup():
	level_select.clear()
	
	var counter := 0
	for level in level_info.data:
		level_select.add_item(level.name)
		level_select.set_item_metadata(counter, level.path)
		counter+= 1
	
	level_select.select(-1)

func _on_select_level_item_selected(index: int) -> void:
	if !MultiMaster.is_host: return
	current_level_idx = index
	_update_selected_level.rpc(index)

@rpc("call_remote", "reliable")
func _update_selected_level(level_select_idx):
	level_select.select(level_select_idx)

func _disconnect_from_noray():
	chat("[color=red]Disconnected from Noray server[/color]")


func _on_player_info_update(id:int, info):
	var players = player_container.get_children().filter(func(player_l:Label): return player_l.name == str(id))
	if players.size() > 1:
		chat("[color=red]Error updating player info, duplicate id \"%s\"[/color]"%id)
		return
	elif players.size() < 1:
		chat("[color=red]Error updating player info, id \"%s\" not found[/color]"%id)
		return
	var player :Label = players[0]
	player.modulate = Color(info.color)
	print("updated player color")


func _on_color_picker_popup_closed() -> void:
	MultiMaster.player_info.color = color_picker.color
	#print(to_hex(color_picker.color))
	if MultiMaster.players.size() > 0:
		MultiMaster.update_player_info.rpc(MultiMaster.player_info)

#func to_hex(color:Color):
	#var full_hex:String = "%x"% color.to_rgba32()
	#var fixed_hex = ("%6s"% full_hex.trim_suffix("ff")).replace(" ", "0")
	#return fixed_hex
