extends CanvasLayer

@export var player:CharacterBody3D
@export var lobbyPath:String = "res://menus/lobby/lobby.tscn"
@export var audio_slider:HSlider
@export var sense:SpinBox
@export var exit:Button

var master_bus = AudioServer.get_bus_index("Master")
var sense_mult = 5000

func _ready():
	visible = false
	audio_slider.value = AudioServer.get_bus_volume_db(master_bus)
	sense.set_value_no_signal(player.sense * sense_mult)
	if !MultiMaster.is_host:
		exit.text = "Leave Lobby"
	

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
	MultiMaster.remove_multiplayer_peer()
	get_tree().quit()

func _on_exit_pressed() -> void:
	if MultiMaster.is_host:
		MultiMaster.load_game.rpc(lobbyPath)
	else:
		MultiMaster.remove_multiplayer_peer()
		get_tree().change_scene_to_file(lobbyPath)


func _on_audio_value_changed(value: float) -> void:
	if fmod(value, 3) == 0:
		audio_slider.get_child(0).play()
	
	AudioServer.set_bus_volume_db(master_bus, value)
	
	
	if value == -30:
		AudioServer.set_bus_mute(master_bus, true)
	else:
		AudioServer.set_bus_mute(master_bus, false)


func _on_sense_value_changed(value: float) -> void:
	audio_slider.get_child(0).play()
	
	player.sense = value/sense_mult
