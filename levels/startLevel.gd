extends Node3D

@export var playerScene:PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var spawn_points = get_tree().get_nodes_in_group("PlayerSpawnPoint")
	for player in Lobby.players:
		var currentPlayer = playerScene.instantiate()
		#currentPlayer.multSync.set_multiplayer_authority(Lobby.players[player].id)
		currentPlayer.name = str(Lobby.players[player].id)
		add_child(currentPlayer)
		var spawn = spawn_points[randi_range(0, spawn_points.size()-1)]
		currentPlayer.global_position = spawn.global_position
