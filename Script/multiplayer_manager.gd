extends Node

const SERVER_PORT = 25567

# The player scene that will be instantiated for every connected peer
var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")

# Tracks active player nodes by their unique Peer ID: { id: Node }
var players = {}
var error
var player_count = 0


var host_mode_enabled = false

# Initializes the game as a Server (Host)
func become_host():
	print("Starting host")
	
	# Cleanup configs from old host sessions
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_cleanup()
	
	# Initialize the ENet network peer as a server
	var server_peer = ENetMultiplayerPeer.new()
	#server_peer.create_server(SERVER_PORT)
	error = server_peer.create_server(SERVER_PORT)
	if error != OK:
		print("Failed to start server: ", error)
		return
	
	multiplayer.multiplayer_peer = server_peer
	
	# Connect signals to handle players joining and leaving dynamically
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_remove_player_from_game)
	
	# Add the host themselves to the game (Host ID is always 1)
	_add_player_to_game(1)

# Initializes the game as a Client and connects to a host
func join_server(server_ip):
	print("Player is joining")
	
	#if multiplayer.multiplayer_peer:
		#multiplayer.multiplayer_peer.close()
		#multiplayer.multiplayer_peer = null
		#print("i clean")
	
	var client_peer = ENetMultiplayerPeer.new()
	error = client_peer.create_client(server_ip, SERVER_PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
	else:
		multiplayer.multiplayer_peer = client_peer

# Instantiates a player scene and adds it to the world
func _add_player_to_game(id: int):
	print("Player %s joined the game" % id)
	
	var player_to_add = multiplayer_scene.instantiate()
	
	# Set the player_id so the character script knows who has authority
	player_to_add.player_id = id
	# Set node name to ID for easy searching via get_node()
	player_to_add.name = str(id)
	
	# Track the node in our dictionary
	players[id] = player_to_add
	
	# Add to the scene tree. 'true' for 'force_readable_name' helps with debugging.
	_get_spawn_node().add_child(player_to_add, true)
	prints(player_count, "server")
	player_count += 1
	

func _remove_player_from_game(id: int):
	print("Player %s left the game" % id)
	if not players.has(id):
		return
	
	# Free the node and cleanup
	players[id].queue_free()
	if players.has(id):
		players.erase(id)


# Allows a peer to request their own removal from the server's tracking
@rpc("any_peer", "call_local")
func _remove_player_request():
	if not multiplayer.is_server(): return
	
	# Identify which peer sent the request
	var id = multiplayer.get_remote_sender_id()
	
	if id == 0: # 0 indicates a local call rather than a remote one
		return
		
	if players.has(id):
		# Ensure the node is still valid before trying to free it
		if is_instance_valid(players[id]):
			if id == 1:
				_cleanup()
			players[id].queue_free()
			players.erase(id)
		print("Player %s left the game via request" % id)

# Cleans up a player node when they disconnect
func _cleanup():
	if multiplayer.peer_connected.is_connected(_add_player_to_game):
		multiplayer.peer_connected.disconnect(_add_player_to_game)
	if multiplayer.peer_disconnected.is_connected(_remove_player_from_game):
		multiplayer.peer_disconnected.disconnect(_remove_player_from_game)

# Find the node where player instances will be added
func _get_spawn_node():
	return get_tree().current_scene.get_node("Players")
