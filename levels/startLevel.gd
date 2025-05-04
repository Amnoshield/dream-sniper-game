extends Node3D

@export var playerScene:PackedScene
@export var lobbyPath:String = "res://menus/lobby/lobby.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MultiMaster.player_disconnected.connect(player_left)
	MultiMaster.server_disconnected.connect(back_to_menu)
	
	var spawn_points = get_tree().get_nodes_in_group("PlayerSpawnPoint")
	for player in MultiMaster.players:
		var currentPlayer = playerScene.instantiate()
		#currentPlayer.multSync.set_multiplayer_authority(MultiMaster.players[player].id)
		currentPlayer.name = str(MultiMaster.players[player].id)
		add_child(currentPlayer)
		var spawn = spawn_points[randi_range(0, spawn_points.size()-1)]
		currentPlayer.global_position = spawn.global_position
	
	MultiMaster.player_loaded.rpc_id(1) # Tell the server that this peer has loaded.

func start_game():
	# All peers are ready to receive RPCs in this scene.
	print("All players loaded! Start the game.")

func player_left(id):
	for child in get_children():
		if child.name == str(id):
			child.queue_free()

func back_to_menu():
	get_tree().change_scene_to_file(lobbyPath)
