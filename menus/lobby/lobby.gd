extends Control

@export var levelPath:String

@export_category("UI")
@export var joinCode:LineEdit
@export var playerName:LineEdit
@export var chat_box:RichTextLabel
@export var player_container:FlowContainer
@export var player_template:Label

@export_category("Buttons")
@export var start:Button
@export var join:Button
@export var host:Button
@export var leave:Button


func _ready():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MultiMaster.player_connected.connect(player_joined)
	MultiMaster.player_disconnected.connect(player_left)
	MultiMaster.kicked.connect(kicked)
	MultiMaster.msg_received.connect(chat)
	
	
	if !MultiMaster.player_info["name"].is_empty():
		MultiMaster.player_info["name"] = MultiMaster.player_info["name"].rstrip("⭐")
		playerName.text = MultiMaster.player_info["name"]
	if !MultiMaster.last_server_ip.is_empty():
		joinCode.text = MultiMaster.last_server_ip
	
	
	if MultiMaster.players.size() > 1 or (multiplayer.is_server() and MultiMaster.players.size()==1):
		if multiplayer.is_server():
			start.disabled = false
		else:
			start.disabled = true
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
	playerName.text = playerName.text.strip_edges()
	if playerName.text.ends_with("⭐"):
		chat("[color=red]Username can't end with \"⭐\"[/color]")
		return
	elif playerName.text.is_empty():
		chat("[color=red]Username required[/color]")
		return
	
	chat("[color=green]Creating lobby ...[/color]")
	await get_tree().create_timer(0.01).timeout
	playerName.text.strip_edges()
	MultiMaster.player_info["name"] = playerName.text+"⭐"
	var error = MultiMaster.create_game()
	if error[0] == -1:
		chat("[color=red]Error starting host: %s.[/color]" % error[1])
		return
	else:
		start.disabled = false
		leave.disabled = false
		host.disabled = true
		join.disabled = true
		playerName.editable = false
		
		chat("%s" % error[1])
		chat("[color=green]Started hosting.[/color]")

func _on_join_pressed() -> void:
	playerName.text = playerName.text.strip_edges()
	if playerName.text.ends_with("⭐"):
		chat("[color=red]Username can't end with \"⭐\"[/color]")
		return
	elif playerName.text.is_empty():
		chat("[color=red]Username required[/color]")
		return
	
	MultiMaster.last_server_ip = joinCode.text
	var error = MultiMaster.join_game(joinCode.text)
	if error:
		chat("[color=red]Problem joining lobby. Error %s[/color]" % error)
	else:
		chat("[color=green]Lobby joined.[/color]")
		MultiMaster.player_info["name"] = playerName.text
		start.disabled = true
		leave.disabled = false
		host.disabled = true
		join.disabled = true
		playerName.editable = false
		joinCode.editable = false

func _on_start_pressed() -> void:
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
	chat("Left lobby")

func chat(text:String):
	chat_box.text += text+'\n'

func player_joined(id, info):
	print("Player joined")
	chat("Player %s joined" % info.name)
	var new_player:Label = player_template.duplicate()
	new_player.name = str(id)
	new_player.text = info.name
	player_container.add_child(new_player)
	new_player.show()

func player_left(id):
	if id == 1:
		chat("[color=yellow]Host left. Lobby closing ...[/color]")
		leave_lobby()
	else:
		for child in player_container.get_children():
			if child.name == str(id):
				child.queue_free()
