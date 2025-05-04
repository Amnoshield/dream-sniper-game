extends CanvasLayer

@export var player:CharacterBody3D
@export var lobbyPath:String = "res://menus/lobby/lobby.tscn"

func _unhandled_key_input(event: InputEvent) -> void:
	if player.multSync.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if event.is_action_pressed("pause"):
		call_deferred("unpause")

func pause():
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unpause():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_continue_pressed() -> void:
	unpause()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_exit_pressed() -> void:
	
	MultiMaster.remove_multiplayer_peer()
	get_tree().change_scene_to_file(lobbyPath)
