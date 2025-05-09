extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal kicked(msg)
signal msg_received(msg)

const PORT = 8000
const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS = 20-1 # subtract 1 because the host doesn't count
var last_server_ip = ""

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}


# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info:Dictionary = {"name": ""}

var players_loaded = 0

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer


func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return [-1, error]
	multiplayer.multiplayer_peer = peer
	player_info["id"] = 1
	players[1] = player_info
	player_connected.emit(1, player_info)
	
	return [0, _upnp_setup()]


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()


# When the server decides to start the game from a UI scene,
# do MultiMaster.load_game.rpc(filepath)
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		print("Players loaded: ", players_loaded, " / ", players.size())
		if players_loaded == players.size():
			get_tree().get_first_node_in_group("world root").start_game()
			players_loaded = 0


# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	print("Player Connected ", id)
	player_info["id"] = multiplayer.get_unique_id()
	_register_player.rpc_id(id, player_info)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	print("Player Disconnected ", id)
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	print("Connected to server")


func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	print("Connection failed")


func _on_server_disconnected():
	print("Server disconnected :(")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()


func _upnp_setup():
	var msg
	
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		msg = "[color=yellow]UPNP Discover Failed! Error %s[/color]\nRunning in LAN mode instead" % discover_result
		print(msg)
		return msg
	
	if !(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
		msg = "[color=yellow]UPNP Invalid Gateway[/color]\nRunning in LAN mode instead"
		print(msg)
		return msg
	
	var map_result = upnp.add_port_mapping(PORT)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		msg = "[color=yellow]UPNP Port Mapping Faiuled! Error %s[/color]\nRunning in LAN mode instead" % map_result
		print(msg)
		return msg
	
	msg = "[color=green]Success! Join Address: %s[/color]" % upnp.query_external_address()
	print(msg)
	return msg


@rpc("any_peer", "reliable")
func get_kicked(msg:String):
	remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://menus/lobby/lobby.tscn")
	await get_tree().create_timer(0.01).timeout
	kicked.emit(msg)


@rpc("any_peer", "reliable")
func get_msg(msg:String):
	msg_received.emit(msg)
