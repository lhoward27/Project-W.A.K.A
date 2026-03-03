extends Control

# Player nodes
@onready var assault_button_label: Label = $RoleSelectButtons/SurvivorSelectButtons/AssaultButton/CurrentSelected
@onready var medic_button_label: Label = $RoleSelectButtons/SurvivorSelectButtons/MedicButton/CurrentSelected
@onready var defender_button_label: Label = $RoleSelectButtons/SurvivorSelectButtons/DefenderButton/CurrentSelected
@onready var trapper_button_label: Label = $RoleSelectButtons/SurvivorSelectButtons/TrapperButton/CurrentSelected
@onready var waka_button_label: Label = $RoleSelectButtons/WAKASelectButton/CurrentSelected
@onready var ready_button_label: Label = $RoleSelectButtons/ReadyUpButton/CurrentSelected
@onready var assault_button: Button = $RoleSelectButtons/SurvivorSelectButtons/AssaultButton
@onready var medic_button: Button = $RoleSelectButtons/SurvivorSelectButtons/MedicButton
@onready var defender_button: Button = $RoleSelectButtons/SurvivorSelectButtons/DefenderButton
@onready var trapper_button: Button = $RoleSelectButtons/SurvivorSelectButtons/TrapperButton
@onready var waka_select_button: Button = $RoleSelectButtons/WAKASelectButton
@onready var ready_up_button: Button = $RoleSelectButtons/ReadyUpButton



@export var player_materials = [
preload("uid://van6okct3p66"),  #blue player material
preload("uid://fwb3q3xqa28w"),  #red player material
preload("uid://cmex25x32muqy"), #green head material
preload("uid://cc1v0vsokxj40"), #light blue head material
preload("uid://b4cpqxwmwox0a"), #orange head material
preload("uid://cqgryetal08l"),   #yellow head material
preload("uid://fwb3q3xqa28w")  #red player material
]

var current_count = 0
@export var role_count: Dictionary
var pressed = false
var is_paused = false
var role_chosen = 0
var role_properties
var role_overfilled = false

var timer = Timer.new()
var has_timer_started = false

var role_name = 0
@export var player_spawn_index := 0
@export var player_id := 1:
	set(id):
		player_id = id

#@export var material_index: int = 0:
	#set(value):
		#if material_index == value:
			#return
		#material_index = value
		#if is_node_ready():
			#if value <= 1:
				#_apply_material_change(body_mesh)
			#else:
				#_apply_material_change(head_mesh)

func _ready() -> void:
	MultiplayerManager.role_count_changed.connect(_on_role_count_changed)
	#if not is_multiplayer_authority():
		#self.visible = false

func _process(_delta: float) -> void:
	#if is_multiplayer_authority():
	if has_timer_started:
		$CountdownLabel/CountdownNumber.text = str(timer.time_left)[0]

func _set_player_properties():
	#if not is_multiplayer_authority(): return
	match role_properties:
		"assault": return {
			"role": "asault",
			"body_material": 0,
			"head_material": 2,
			"role_group": "survivors",
			"player_spawn_index": 0
			}
		"medic": return {
			"role": "medic",
			"body_material": 0,
			"head_material": 3,
			"role_group": "survivors",
			"player_spawn_index": 1
			}
		"defender":
			rpc("_sync_material_change", 0)
			rpc("_sync_material_change", 4)
			role_name = "survivors"
			player_spawn_index = 2
		"trapper":
			rpc("_sync_material_change", 0)
			rpc("_sync_material_change", 5)
			role_name = "survivors"
			player_spawn_index = 3
		"waka":
			rpc("_sync_material_change", 1)
			rpc("_sync_material_change", 6)
			role_name = "waka"
			player_spawn_index = randi_range(0,3)


func _on_start_screen_button_pressed() -> void:
	MultiplayerManager.rpc("_remove_player_request")
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_assault_button_toggled(_toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	_update_role_selection("assault", 1)

func _on_medic_button_toggled(_toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	_update_role_selection("medic", 2)

func _on_defender_button_toggled(_toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	_update_role_selection("defender", 3)

func _on_trapper_button_toggled(_toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	_update_role_selection("trapper", 4)

func _on_waka_select_button_toggled(_toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	_update_role_selection("waka", 5)

func _on_ready_up_button_toggled(toggled_on: bool) -> void:
	#if not is_multiplayer_authority(): return
	var count
	if role_chosen != 0:
		if toggled_on:
			count = 1
			ready_up_button.text = "Ready"
		else:
			ready_up_button.text = "Ready Up"
			count = -1
		MultiplayerManager.rpc("_update_role_count", "ready", count)
	else:
		ready_up_button.button_pressed = false

func _update_role_selection(role: String, role_index: int):
	var count
	if role_chosen == role_index:
		ready_up_button.button_pressed = false
		role_chosen = 0
		count = -1
		MultiplayerManager.rpc("_update_role_count", role, count)
		return
	if role_chosen == 0:
		role_chosen = role_index
		count = 1
		MultiplayerManager.rpc("_update_role_count", role, count)
		role_properties = role

func _on_role_count_changed(role, count):
	#if not is_multiplayer_authority(): return
	if role == "assault":
		_update_role_counter(count, assault_button, assault_button_label)
	if role == "medic":
		_update_role_counter(count, medic_button, medic_button_label)
	if role == "defender":
		_update_role_counter(count, defender_button, defender_button_label)
	if role == "trapper":
		_update_role_counter(count, trapper_button, trapper_button_label)
	if role == "waka":
		_update_role_counter(count, waka_select_button, waka_button_label)
	if role == "ready":
		ready_button_label.text = str(count)
		var new_stylebox_normal = ready_up_button.get_theme_stylebox("normal").duplicate()
		if count < 5:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 5:
			new_stylebox_normal.bg_color = Color("0d5021")
		if not role_overfilled && count > 1:
			_countdown(count)
		#else:
			#new_stylebox_normal.bg_color = Color("1c1c1c99")
		ready_up_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		ready_up_button.add_theme_stylebox_override("pressed", new_stylebox_normal)

func _countdown(count):
	#if not is_multiplayer_authority(): return
	if not has_timer_started:
		add_child(timer)
		timer.connect("timeout", _game_start)
		timer.one_shot = true
	if count == 2:
		has_timer_started = true
		timer.start(1)
		$CountdownLabel.visible = true
	else:
		timer.stop()
		$CountdownLabel.visible = false
#
func _update_role_counter(count, button, label):
	label.text = str(count)
	var new_stylebox_normal = button.get_theme_stylebox("normal").duplicate()
	if count > 1:
		new_stylebox_normal.bg_color = Color("6e0a09")
		role_overfilled = true
	elif count == 1:
		new_stylebox_normal.bg_color = Color("0d5021")
		role_overfilled = false
	else:
		new_stylebox_normal.bg_color = Color("1c1c1c99")
	button.add_theme_stylebox_override("normal", new_stylebox_normal)
	button.add_theme_stylebox_override("pressed", new_stylebox_normal)


#func _get_unique_id():
	#var key_array: Array = MultiplayerManager.players.keys()
	#if key_array.size() == 0:
		#return 1
	#else:
		#var last_key = key_array[-1]
		#return MultiplayerManager.players[last_key].player_id
	

func _game_start():
	MultiplayerManager._add_player_to_game(multiplayer.get_unique_id(), _set_player_properties())
	#if not is_multiplayer_authority(): return
	MultiplayerManager._start_game()
	#_set_player_properties()
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#var spawn_point_nodes = {
		#"survivors": get_tree().current_scene.get_node("SpawnPoints"),
		#"waka": get_tree().current_scene.get_node("WAKASpawnPoints")
	#}
	#var spawn_points = {
		#"survivors": spawn_point_nodes["survivors"].get_children(),
		#"waka": spawn_point_nodes["waka"].get_children()
	#}
	#var spawn_point_set = spawn_points[role_index]
	#self.global_position = spawn_point_set[player_spawn_index].global_position

#
#@rpc("any_peer","call_local", "reliable")
#func _sync_material_change(new_index: int):
	#material_index = new_index
	#if material_index <= 1:
		#_apply_material_change(body_mesh)
	#else:
		#_apply_material_change(head_mesh)
#
#
#func _apply_material_change(mesh):
	#mesh.set_surface_override_material(0, player_materials[material_index])
