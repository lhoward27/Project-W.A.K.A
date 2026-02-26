extends Node

const SERVER_PORT = 25567

# The player scene that will be instantiated for every connected peer
var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")

# Tracks active player nodes by their unique Peer ID: { id: Node }
var players = {}
var error

var _players_spawn_node # Reference to the node where players will be added (e.g., "$Level/Players")
var host_mode_enabled = false

# Initializes the game as a Server (Host)
func become_host():
	print("Starting host")
	
	# Find the designated container for player instances in the current scene
	_players_spawn_node = get_tree().current_scene.get_node("Players")
	
	host_mode_enabled = true
	
	# Initialize the ENet network peer as a server
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	# Assign the peer to the MultiplayerAPI
	multiplayer.multiplayer_peer = server_peer
	
	# Connect signals to handle players joining and leaving dynamically
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_remove_player_from_game)
	
	# Remove the placeholder local player before spawning the networked version
	_remove_single_player()
	
	# Add the host themselves to the game (Host ID is always 1)
	_add_player_to_game(1)

# Initializes the game as a Client and connects to a host
func join_server(server_ip):
	print("Player is joining")
	
	var client_peer = ENetMultiplayerPeer.new()
	error = client_peer.create_client(server_ip, SERVER_PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
	else:
		multiplayer.multiplayer_peer = client_peer
		# Remove the local placeholder player; the server will handle spawning our networked instance via the peer_connected signal. 
		_remove_single_player()

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
	_players_spawn_node.add_child(player_to_add, true)

# Cleans up a player node when they disconnect
func _remove_player_from_game(id: int):
	print("Player %s left the game" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	
	# Free the node and cleanup
	_players_spawn_node.get_node(str(id)).queue_free()
	if players.has(id):
		players.erase(id)

# Removes the default "Player" node present in the scene before multiplayer starts
func _remove_single_player():
	print("Remove single player placeholder")
	var player_to_remove = get_tree().current_scene.get_node("Player")
	if player_to_remove:
		player_to_remove.queue_free()


# Allows a peer to request their own removal from the server's tracking
@rpc("any_peer")
func _remove_player_request():
	# Identify which peer sent the request
	var id = multiplayer.get_remote_sender_id()
	
	if id == 0: # 0 indicates a local call rather than a remote one
		return
		
	if players.has(id):
		# Ensure the node is still valid before trying to free it
		if is_instance_valid(players[id]):
			players[id].queue_free()
		players.erase(id)
		print("Player %s left the game via request" % id)
