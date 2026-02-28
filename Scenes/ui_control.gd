extends Control
@onready var assault_button: Button = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/AssaultButton
@onready var medic_button: Button = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/MedicButton
@onready var defender_button: Button = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/DefenderButton
@onready var trapper_button: Button = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/TrapperButton
@onready var waka_select_button: Button = $RoleSelect/RoleSelectButtons/WAKASelectButton
@onready var ready_up_button: Button = $RoleSelect/RoleSelectButtons/ReadyUpButton
@onready var assault_button_label: Label = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/AssaultButton/CurrentSelected
@onready var medic_button_label: Label = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/MedicButton/CurrentSelected
@onready var defender_button_label: Label = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/DefenderButton/CurrentSelected
@onready var trapper_button_label: Label = $RoleSelect/RoleSelectButtons/SurvivorSelectButtons/TrapperButton/CurrentSelected
@onready var waka_button_label: Label = $RoleSelect/RoleSelectButtons/WAKASelectButton/CurrentSelected
@onready var ready_button_label: Label = $RoleSelect/RoleSelectButtons/ReadyUpButton/CurrentSelected
@onready var pause_menu: Control = $PauseMenu

var current_count = 0
@export var role_count: Dictionary
var pressed = false
var is_paused = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MultiplayerManager.role_count_changed.connect(_on_role_count_changed)
	
	if not is_multiplayer_authority():
		$RoleSelect.visible = false
		
	if is_multiplayer_authority():
		pause_menu.visible = false
	

#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel"):
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#pause_menu.visible = true
		#is_paused = true

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_resume_button_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.visible = false
	is_paused = false

func _on_start_screen_button_pressed() -> void:
	MultiplayerManager.rpc("_remove_player_request")
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_role_count_changed(role, count):
	if role == "assault":
		assault_button_label.text = str(count)
		var new_stylebox_normal = assault_button.get_theme_stylebox("normal").duplicate()
		if count > 1:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 1:
			new_stylebox_normal.bg_color = Color("0d5021")
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		assault_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		assault_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
	if role == "medic":
		medic_button_label.text = str(count)
		var new_stylebox_normal = medic_button.get_theme_stylebox("normal").duplicate()
		if count > 1:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 1:
			new_stylebox_normal.bg_color = Color("0d5021")
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		medic_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		medic_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
	if role == "defender":
		defender_button_label.text = str(count)
		var new_stylebox_normal = defender_button.get_theme_stylebox("normal").duplicate()
		if count > 1:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 1:
			new_stylebox_normal.bg_color = Color("0d5021")
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		defender_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		defender_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
	if role == "trapper":
		trapper_button_label.text = str(count)
		var new_stylebox_normal = trapper_button.get_theme_stylebox("normal").duplicate()
		if count > 1:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 1:
			new_stylebox_normal.bg_color = Color("0d5021")
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		trapper_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		trapper_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
	if role == "waka":
		waka_button_label.text = str(count)
		var new_stylebox_normal = waka_select_button.get_theme_stylebox("normal").duplicate()
		if count > 1:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 1:
			new_stylebox_normal.bg_color = Color("0d5021")
		else:
			new_stylebox_normal.bg_color = Color("1c1c1c99")
		waka_select_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		waka_select_button.add_theme_stylebox_override("pressed", new_stylebox_normal)
	if role == "ready":
		ready_button_label.text = str(count)
		var new_stylebox_normal = ready_up_button.get_theme_stylebox("normal").duplicate()
		if count < 5:
			new_stylebox_normal.bg_color = Color("6e0a09")
		elif count == 5:
			new_stylebox_normal.bg_color = Color("0d5021")
		#else:
			#new_stylebox_normal.bg_color = Color("1c1c1c99")
		ready_up_button.add_theme_stylebox_override("normal", new_stylebox_normal)
		ready_up_button.add_theme_stylebox_override("pressed", new_stylebox_normal)

func _on_assault_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "assault", count)

func _on_medic_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "medic", count)

func _on_defender_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "defender", count)

func _on_trapper_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "trapper", count)

func _on_waka_select_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "waka", count)

func _on_ready_up_button_toggled(toggled_on: bool) -> void:
	if not is_multiplayer_authority(): return
	if toggled_on:
		ready_up_button.text = "Ready"
	else:
		ready_up_button.text = "Unready"
	var count = 1 if toggled_on else -1
	MultiplayerManager.rpc("_update_role_count", "ready", count)
