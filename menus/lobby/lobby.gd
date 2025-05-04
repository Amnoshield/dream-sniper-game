extends Control

@export var levelPath:String
@export_category("UI")
@export var joinCode:LineEdit
@export var playerName:LineEdit
@export var chat:RichTextLabel

func _on_host_pressed() -> void:
	var error = MultiMaster.create_game()
	if error:
		chat.text +=  "Error starting host.\n"
		return
	else:
		chat.text += "Started hosting.\n"

func _on_join_pressed() -> void:
	var error = MultiMaster.join_game(joinCode.text)
	if error:
		chat.text += "Error joining lobby.\n"
	else:
		chat.text += "Lobby joined.\n"
		MultiMaster.player_info["name"] = playerName.text

func _on_start_pressed() -> void:
	MultiMaster.load_game.rpc(levelPath)
