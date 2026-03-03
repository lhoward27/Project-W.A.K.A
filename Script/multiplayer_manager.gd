extends Node

const SERVER_PORT = 25567

# The player scene that will be instantiated for every connected peer
var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")

# Tracks active player nodes by their unique Peer ID: { id: Node }
var players = {}
var error
var player_count = 0
var players_ready = false
var ready_client_count = 0

#func _ready() -> void:
	#_get_spawn_node().spawn_function = _spawn_player

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
	error = server_peer.create_server(SERVER_PORT)
	if error != OK:
		print("Failed to start server: ", error)
		return
	
	multiplayer.multiplayer_peer = server_peer
	
	# Connect signals to handle players joining and leaving dynamically
	multiplayer.peer_connected.connect(_new_peer_data)
	multiplayer.peer_disconnected.connect(_remove_player_from_game)
	
	get_tree().change_scene_to_file("res://Scenes/role_select.tscn")
	
	_new_peer_data(1)
	#await get_tree().process_frame
	#await get_tree().process_frame
	##_get_spawn_node().spawn_function = _spawn_player
	#
	## Add the host themselves to the game (Host ID is always 1)
	#_add_player_to_game(1)

# Initializes the game as a Client and connects to a host
func join_server(server_ip):
	print("Player is joining")
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	var client_peer = ENetMultiplayerPeer.new()
	error = client_peer.create_client(server_ip, SERVER_PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
	multiplayer.multiplayer_peer = client_peer
	get_tree().change_scene_to_file("res://Scenes/role_select.tscn")
	


func _new_peer_data(id: int):
	players[id] = {
		"player_id": id,
		"name": str(id),
		"role_properties": {}
	}
	if id != 1:
		_sync_role_counts.rpc_id(id, role_counts)

# Instantiates a player scene and adds it to the world
func _add_player_to_game(id: int, role: Dictionary):
	if not players.has(id):
		_new_peer_data(id)
	players[id]["role_properties"] = role


func _start_game():
	if players_ready:
		_change_scene.rpc()

func _do_spawn():
	#var spawn_node = _get_spawn_node()
	#while spawn_node ==  null:
		#await get_tree().process_frame
		#spawn_node = _get_spawn_node()
	print("spawning")
	
	_get_spawn_node().spawn_function = _spawn_player
	for player in players:
		_get_spawn_node().spawn({
			"id": players[player]["player_id"],
			"role": players[player]["role_properties"]
			})
		print("Player %s joined the game" % players[player].player_id)

func _spawn_player(data):
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.player_id = data.id
	player_to_add.name = str(data.id)
	player_to_add.set_multiplayer_authority(data.id)
	player_to_add.role_properties = data.role
	return player_to_add

# Find the node where player instances will be added
func _get_spawn_node():
	var scene = get_tree().current_scene
	if scene == null: return null
	var players_node = scene.get_node_or_null("Players")
	if players_node == null: return null
	return players_node.get_node_or_null("MultiplayerSpawner")
	#return get_tree().current_scene.get_node("Players").get_node("MultiplayerSpawner")

func _remove_player_from_game(id: int):
	if not multiplayer.is_server(): return
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


var role_counts = {"assault": 0, "medic": 0, "defender": 0, "trapper": 0, "waka": 0, "ready": 0}

@rpc("any_peer", "call_local")
func _update_role_count(role: String, count: int):
	role_counts[role] += count
	role_count_changed.emit(role, role_counts[role])
	if role_counts["ready"] == 2:
		players_ready = true
signal role_count_changed(role, count)

@rpc("authority")
func _sync_role_counts(counts: Dictionary):
	role_counts = counts
	for role in role_counts:
		role_count_changed.emit(role, role_counts[role])

@rpc("call_local")
func _change_scene():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame

@rpc("any_peer")
func _on_client_ready():
	print("readying")
	ready_client_count += 1
	print(ready_client_count)
	if ready_client_count == 2:
		_do_spawn()
