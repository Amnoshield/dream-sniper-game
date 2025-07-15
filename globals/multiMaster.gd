extends Node


# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal player_info_updated(id, player_info)
signal server_disconnected
signal kicked(msg)
signal msg_received(msg)
signal noray_connected
signal nat_punchthrough_failed
signal relay_failed

signal death(killer_id:int, victim_id:int, method:String)


const default_noray_address := "tomfol.io"
const default_noray_port := 8890
var noray_address := "tomfol.io" # if this doesn't work use "104.237.145.37"
var noray_port := 8890
const MAX_CONNECTIONS = 20-1 # subtract 1 because the host doesn't count
var last_server_ip = ""

var external_oid = ""
var is_host = false

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}


# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
@onready var player_info:Dictionary = {"name": "", "color":Color(randf(),randf(),randf())}

var players_loaded = 0


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	Noray.on_connect_to_host.connect(on_noray_connected)
	Noray.on_connect_nat.connect(handle_nat_connection)
	Noray.on_connect_relay.connect(handle_relay_connection)
	
	Noray.connect_to_host(noray_address, noray_port)


func change_noray_server(address:String, port:int):
	Noray.disconnect_from_host()
	Noray.connect_to_host(address, port)


func on_noray_connected():
	print("Connected to Noray server")
	
	Noray.register_host()
	await Noray.on_pid
	await Noray.register_remote()
	noray_connected.emit()


func join(oid):
	Noray.connect_nat(oid)
	external_oid = oid


func host():
	print("Hosting")
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(Noray.local_port, MAX_CONNECTIONS)
	multiplayer.multiplayer_peer = peer
	is_host = true
	
	player_info["id"] = 1
	players[1] = player_info
	player_connected.emit(1, player_info)


func handle_nat_connection(address, port):
	var err = await connect_to_server(address, port)
	
	if err != OK && !is_host:
		print("NAT failed, using relay")
		nat_punchthrough_failed.emit()
		Noray.connect_relay(external_oid)
		err = OK
	
	return err


func handle_relay_connection(address, port):
	var err = await connect_to_server(address, port)
	
	if err != OK && !is_host:
		print("Relay failed, disconecting")
		relay_failed.emit()
	
	return err


func connect_to_server(address, port):
	var err = OK
	
	if !is_host:
		var udp = PacketPeerUDP.new()
		udp.bind(Noray.local_port)
		udp.set_dest_address(address, port)
		
		err = await PacketHandshake.over_packet_peer(udp)
		udp.close()
		
		if err != OK:
			if err != ERR_BUSY:
				print("Handshake failed")
				return err
		else:
			print("Handshake success")
		
		var peer = ENetMultiplayerPeer.new()
		err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
		
		if err != OK:
			return err
		
		multiplayer.multiplayer_peer = peer
		
		return OK
	else:
		err = await PacketHandshake.over_enet(multiplayer.multiplayer_peer.host, address, port)
	
	return err


func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false


# When the server decides to start the game from a UI scene,
# do MultiMaster.load_game.rpc(filepath)
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)


# Every peer will call this when they have loaded the game scene.
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if is_host:
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

@rpc("any_peer", "call_local", "reliable")
func update_player_info(new_player_info:Dictionary):
	var player_id = multiplayer.get_remote_sender_id()
	players[player_id] = new_player_info
	player_info_updated.emit(player_id, new_player_info)


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


@rpc("any_peer", "reliable")
func get_kicked(msg:String):
	remove_multiplayer_peer()
	get_tree().change_scene_to_file("res://menus/lobby/lobby.tscn")
	await get_tree().create_timer(0.01).timeout
	kicked.emit(msg)


@rpc("any_peer", "reliable")
func get_msg(msg:String):
	msg_received.emit(msg)

@rpc("any_peer", "call_local", "reliable")
func add_death_to_scoreboard(killer_id:int, victim_id:int, method:String):
	death.emit(killer_id, victim_id, method)
