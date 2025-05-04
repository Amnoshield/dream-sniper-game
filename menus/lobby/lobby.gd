extends Control

@export var levelPath:String
@export_category("UI")
@export var joinCode:LineEdit
@export var playerName:LineEdit
@export var chat:RichTextLabel

func _on_host_pressed() -> void:
	var error = Lobby.create_game()
	if error:
		chat.text +=  "Error starting host.\n"
		return
	else:
		chat.text += "Started hosting.\n"

func _on_join_pressed() -> void:
	var error = Lobby.join_game(joinCode.text)
	if error:
		chat.text += "Error joining lobby.\n"
	else:
		chat.text += "Lobby joined.\n"
		Lobby.player_info["name"] = playerName.text


func _on_start_pressed() -> void:
	Lobby.load_game.rpc(levelPath)
