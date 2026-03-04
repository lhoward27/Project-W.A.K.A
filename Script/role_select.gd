extends Control

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

var role_chosen: String
var role_properties: String

func _ready() -> void:
	# Connect to MultiplayerManager signals for role count updates and countdown sync
	MultiplayerManager.role_count_changed.connect(_on_role_count_changed)
	MultiplayerManager.timer_changed.connect(_countdown)
	
	# Set this node's multiplayer authority to the local peer so only they control it
	set_multiplayer_authority(multiplayer.get_unique_id())
	
	# Hide the UI for peers who don't own this node
	if not is_multiplayer_authority():
		self.visible = false
		

# Returns a dictionary of properties for the chosen role
func _set_player_properties():
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
		"defender": return {
			"role": "medic",
			"body_material": 0,
			"head_material": 4,
			"role_group": "survivors",
			"player_spawn_index": 2
			}
		"trapper": return {
			"role": "medic",
			"body_material": 0,
			"head_material": 5,
			"role_group": "survivors",
			"player_spawn_index": 3
			}
		"waka": return {
			"role": "medic",
			"body_material": 1,
			"head_material": 6,
			"role_group": "waka",
			"player_spawn_index": randi_range(0,3)
			}


func _on_start_screen_button_pressed() -> void:
	MultiplayerManager.rpc("_remove_player_request")
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_assault_button_toggled(_toggled_on: bool) -> void:
	_update_role_selection("assault")

func _on_medic_button_toggled(_toggled_on: bool) -> void:
	_update_role_selection("medic")

func _on_defender_button_toggled(_toggled_on: bool) -> void:
	_update_role_selection("defender")
func _on_trapper_button_toggled(_toggled_on: bool) -> void:
	_update_role_selection("trapper")

func _on_waka_select_button_toggled(_toggled_on: bool) -> void:
	_update_role_selection("waka")

func _on_ready_up_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	var count
	if not role_chosen.is_empty():
		if toggled_on:
			count = 1
			ready_up_button.text = "Ready"
		else:
			ready_up_button.text = "Ready Up"
			count = -1
		
		# Send role data to server only
		MultiplayerManager.rpc_id(1, "_add_player_data", multiplayer.get_unique_id(), _set_player_properties())
		
		# Broadcast ready count change to all peers
		MultiplayerManager.rpc("_update_role_count", "ready", count)
	else:
		ready_up_button.button_pressed = false

func _update_role_selection(role: String):
	if not is_multiplayer_authority(): return
	var count
	# Prevent switching roles if a role is already selected — must deselect first
	if role_chosen == role:
		ready_up_button.button_pressed = false
		role_chosen = ""
		count = -1
		MultiplayerManager.rpc("_update_role_count", role, count)
		return
	# Only allow selecting a role if none is currently chosen
	if role_chosen.is_empty():
		role_chosen = role
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
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		ready_up_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		ready_up_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
		
# Update the visual counter and color for a role button based on current count
func _update_role_counter(count, button, label):
	label.text = str(count)
	var new_stylebox_normal = button.get_theme_stylebox("normal").duplicate()
	if count > 1:
		new_stylebox_normal.bg_color = Color("6e0a09")
	elif count == 1:
		new_stylebox_normal.bg_color = Color("0d5021")
	else:
		new_stylebox_normal.bg_color = Color("1c1c1c99")
	button.add_theme_stylebox_override("normal", new_stylebox_normal)
	button.add_theme_stylebox_override("pressed", new_stylebox_normal)

# Show or hide countdown label and tick down each second based on server signal
var countdown_id = 0

func _countdown(counting, duration):
	countdown_id += 1
	var local_id = countdown_id
	await  get_tree().process_frame
	
	$CountdownLabel/CountdownNumber.text = str(duration)
	
	if not counting:
		$CountdownLabel.visible = false
		return
	
	$CountdownLabel.visible = true
	
	# Wait one second per tick and decrement the displayed countdown
	while duration > 0:
		await get_tree().create_timer(1).timeout
		if local_id != countdown_id: return
		duration -= 1
		$CountdownLabel/CountdownNumber.text = str(duration)
		
