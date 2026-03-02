extends Control

# Nodes
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var input_error: Label = $VBoxContainer/InputError

# Allows for a localhost connection without typing "localhost" into the ServerIPLine text box, can be expanded for any other debug needs
@export var debug_mode: bool = false

var server_ip = ""

func _ready() -> void:
	input_error.visible = false

# Start hosting a multiplayer session and remove the start screen
func _on_host_button_pressed() -> void:
	MultiplayerManager.become_host()

# Only attempt to join if the user has entered an IP
func _on_join_button_pressed() -> void:
	if not server_ip.is_empty() :
		MultiplayerManager.join_server(server_ip)
		if MultiplayerManager.error != OK:
			input_error.visible = true
			animation_player.play("text_fade", 0.5)
		else:
			get_tree().change_scene_to_file("res://Scenes/role_select.tscn")
	#This is only for local testing
	elif debug_mode:
		MultiplayerManager.join_server("localhost")
		if MultiplayerManager.error != OK:
			input_error.visible = true
			animation_player.play("text_fade",-1, 0.5)
		else:
			pass


func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_server_ip_line_text_changed(new_text: String) -> void:
	server_ip = new_text
