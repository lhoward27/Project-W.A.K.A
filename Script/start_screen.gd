extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var input_error: Label = $VBoxContainer/InputError

# Allows for a localhost connection without typing "localhost" into the ServerIPLine text box, can be expanded for any other debug needs
@export var debug_mode: bool = false

var server_ip = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input_error.visible = false
	MultiplayerManager.rejection_received.connect(_on_join_request_rejected)

func _on_join_request_rejected(reason: String):
	input_error.text = reason
	input_error.visible = true
	animation_player.play("text_fade", 0.5, 0.5)

# Start hosting a multiplayer session and remove the start screen
func _on_host_button_pressed() -> void:
	MultiplayerManager.become_host()

# Only attempt to join if the user has entered an IP
func _on_join_button_pressed() -> void:
	if not server_ip.is_empty() :
		MultiplayerManager.join_server(server_ip)
		if MultiplayerManager.error != OK:
			_on_join_request_rejected("Connection Failed: Invalid IP Address...")
		else:
			pass
	#This is only for local testing
	elif debug_mode:
		MultiplayerManager.join_server("localhost")
		if MultiplayerManager.error != OK:
			_on_join_request_rejected("Connection Failed: Invalid IP Address...")
		else:
			pass

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_server_ip_line_text_changed(new_text: String) -> void:
	server_ip = new_text
