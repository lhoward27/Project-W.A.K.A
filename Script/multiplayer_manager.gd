extends Node

const SERVER_PORT = 25567

# The player scene that will be instantiated for every connected peer
var multiplayer_scene = preload("res://Scenes/multiplayer_player.tscn")

# Tracks active player nodes by their unique Peer ID: { id: Node }
var players = {}
var error
var has_timer_started = false
var timer = Timer.new()
var timer_created = false
var players_to_start = 1
var game_started = false

# Initializes the game as a Server (Host)
func become_host():
	print("Starting host")
	
	# Initialize the ENet network peer as a server
	var server_peer = ENetMultiplayerPeer.new()
	error = server_peer.create_server(SERVER_PORT)
	if error != OK:
		print("Failed to start server: ", error)
		return
	
	# Fires before peer_connected, spawner never sees rejected players
	var scene_mp = multiplayer as SceneMultiplayer
	scene_mp.auth_callback = _auth_peer
	scene_mp.auth_timeout = 3.0
	scene_mp.peer_authenticating.connect(_on_new_peer_authenticating)
	
	multiplayer.multiplayer_peer = server_peer
	
	# Connect signals to handle players joining and leaving dynamically
	multiplayer.peer_connected.connect(_new_peer_data)
	multiplayer.peer_disconnected.connect(_remove_player_from_game)
	
	get_tree().change_scene_to_file("res://Scenes/role_select.tscn")
	
	_new_peer_data(1)

# Initializes the game as a Client and connects to a host
func join_server(server_ip):
	print("Joining Server")
	
	var client_peer = ENetMultiplayerPeer.new()
	error = client_peer.create_client(server_ip, SERVER_PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
	
	# Client must also complete auth for server
	(multiplayer as SceneMultiplayer).auth_callback = _auth_peer
	
	multiplayer.multiplayer_peer = client_peer

func _on_new_peer_authenticating(id: int):
	(multiplayer as SceneMultiplayer).send_auth(id, PackedByteArray([1]))

# Data is being ignored, but needed to properly call function 
func _auth_peer(id: int, data: PackedByteArray):
	if multiplayer.is_server():
		# Rejecting new peer if the game has already been started, or game already has 5 players
		if game_started:
			(multiplayer as SceneMultiplayer).send_auth(id, "game_started".to_utf8_buffer())
			return
		elif players.size() == 5:
			(multiplayer as SceneMultiplayer).send_auth(id, "game_full".to_utf8_buffer())
			return
		else:
			# Send auth data to client, triggering client auth_callback
			(multiplayer as SceneMultiplayer).complete_auth(id)
	else:
		# If connection is rejected, emit reason why and update client ui to reflect
		if data.size() > 0:
			var message = data.get_string_from_utf8()
			if message == "game_started":
				rejection_received.emit("Connection Failed: Game has already started...")
				return
			elif message == "game_full":
				rejection_received.emit("Connection Failed: Player limit reached...")
				return
		# Client sends back to trigger server's _auth_peer, then completes
		# PackedByteArray contains a dummy payload to satisfy function
		(multiplayer as SceneMultiplayer).send_auth(id, PackedByteArray([1]))
		(multiplayer as SceneMultiplayer).complete_auth(id)
signal rejection_received(reason: String)

func _new_peer_data(id: int):
	print("Player %s is joining" % id)
	players[id] = {
		"player_id": id,
		"name": str(id),
		"role_properties": {},
		"player_health": 1
	}
	if id != 1:
		_sync_data.rpc_id(id, role_counts)

@rpc()
func _sync_data(counts: Dictionary):
	get_tree().change_scene_to_file("res://Scenes/role_select.tscn")
	
	# Only continue sync after role select scene has been fully loaded
	var role_scene = _check_scene_state()
	while role_scene == null:
		await get_tree().process_frame
		role_scene = _check_scene_state()
	
	role_counts = counts
	for role in role_counts:
		role_count_changed.emit(role, role_counts[role])

# Instantiates a player scene and adds it to the world
@rpc("any_peer", "call_local")
func _add_player_data(id: int, role: Dictionary):
	players[id]["role_properties"] = role

@rpc("any_peer", "call_local")
func _start_game():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	game_started = true
	# Check if multiplayer spawner has been fully loaded, only proceed when it has
	var spawn_node = _get_spawn_node()
	while spawn_node == null:
		await get_tree().process_frame
		spawn_node = _get_spawn_node()
	
	_get_spawn_node().spawn_function = _spawn_player
	if not multiplayer.is_server(): return
	
	for player in players:
		_get_spawn_node().spawn({
			"id": players[player]["player_id"],
			"role": players[player]["role_properties"],
			"health": players[player]["player_health"]
			})
		print("Spawning player %s" % players[player].player_id)

# Find the node where player instances will be added
func _get_spawn_node():
	var scene = get_tree().current_scene
	if scene == null: return null
	var players_node = scene.get_node_or_null("Players")
	if players_node == null: return null
	return players_node.get_node_or_null("MultiplayerSpawner")

func _spawn_player(data):
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.player_id = data.id
	player_to_add.name = str(data.id)
	player_to_add.set_multiplayer_authority(data.id)
	player_to_add.role_properties = data.role
	player_to_add.player_health = data.health
	players[data.id] = player_to_add
	return player_to_add

func _countdown(count):
	var duration = 1
	if not has_timer_started and not timer_created:
		add_child(timer)
		timer.one_shot = true
		timer_created = true
		if multiplayer.is_server():
			timer.connect("timeout", _start_game.rpc)
	if count == players_to_start:
		has_timer_started = true
		timer.start(duration)
		timer_changed.emit(true, duration)
	else:
		timer.stop()
		timer_changed.emit(false, 0)

signal timer_changed(started, duration)

var role_counts = {"assault": 0, "medic": 0, "defender": 0, "trapper": 0, "waka": 0, "ready": 0}

@rpc("any_peer", "call_local")
func _update_role_count(role: String, count: int):
	role_counts[role] += count
	role_count_changed.emit(role, role_counts[role])
	# Checks if any roles have two players selected, else does countdown to start game
	var role_counts_array = role_counts.values()
	role_counts_array.remove_at(-1)
	if not role_counts_array.has(2):
		_countdown(role_counts["ready"])
signal role_count_changed(role, count)

func _remove_player_from_game(id: int):
	if not multiplayer.is_server(): return
	print("Player %s left the game" % id)
	if not players.has(id):
		return
	
	if not is_instance_valid(players[id]):
		players.erase(id)
		return
	
	# Free the node and cleanup
	players[id].queue_free()
	if players.has(id):
		players.erase(id)

# Allows a peer to request their own removal from the server's tracking
@rpc("any_peer", "call_local")
func _remove_player_request(request):
	if not multiplayer.is_server(): return
	# Identify which peer sent the request
	var id = multiplayer.get_remote_sender_id()
	
	if id == 0: # 0 indicates a local call rather than a remote one
		return
		
	if players.has(id):
		if not is_instance_valid(players[id]):
			players.erase(id)
			return
		# Ensure the node is still valid before trying to free it
		if is_instance_valid(players[id]):
			# If host leaves game, disconnect all peers
			if id == 1:
				var players_array = players.keys()
				players_array.reverse()
				for player in players_array:
					print(players_array)
					print(player)
					if request == "quit":
						if player == 1:
							_cleanup(player, "quit")
						else:
							_cleanup.rpc(player, "leave")
					else:
						print("dont do this")
						_cleanup.rpc(player, "leave")
					
			else:
				print("why here")
				players[id].queue_free()
				players.erase(id)
				_cleanup.rpc_id(id, id)
				print("Player %s left the game via request" % id)

# Cleans up a player node when they disconnect
@rpc("call_local")
func _cleanup(id, request):

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if request == "quit":
		get_tree().quit()
	else:
		get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")
	
	# Only continue cleanup after start screen has been fully loaded
	var scene_loaded = _check_scene_state()
	while scene_loaded == null:
		await get_tree().process_frame
		scene_loaded = _check_scene_state()
	
	# Reset variables to default
	players = {}
	has_timer_started = false
	game_started = false
	for role in role_counts:
		role_counts[role] = 0
	
	multiplayer.multiplayer_peer = null
	
	print("Player %s was disconnected" % id)
	# Disconnect multiplayer signals from host if they leave
	if id == 1:
		if multiplayer.peer_connected.is_connected(_new_peer_data):
			multiplayer.peer_connected.disconnect(_new_peer_data)
		if multiplayer.peer_disconnected.is_connected(_remove_player_from_game):
			multiplayer.peer_disconnected.disconnect(_remove_player_from_game)
		if (multiplayer as SceneMultiplayer).peer_authenticating.is_connected(_on_new_peer_authenticating):
			(multiplayer as SceneMultiplayer).peer_authenticating.disconnect(_on_new_peer_authenticating)

func _check_scene_state():
	var scene = get_tree().current_scene
	if scene == null : return null
	return "scene loaded"
