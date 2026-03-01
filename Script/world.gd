# World
extends Node3D

# 2d Nodes
@onready var start_screen: Control = $StartScreen
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var input_error: Label = $StartScreen/VBoxContainer/InputError

# Allows for a localhost connection without typing "localhost" into the ServerIPLine text box, can be expanded for any other debug needs
@export var debug_mode: bool = false

var server_ip = ""

func _ready() -> void:
	input_error.visible = false

# Start hosting a multiplayer session and remove the start screen
func _on_host_button_pressed() -> void:
	MultiplayerManager.become_host()
	start_screen.queue_free()

# Only attempt to join if the user has entered an IP
func _on_join_button_pressed() -> void:
	if not server_ip.is_empty() :
		MultiplayerManager.join_server(server_ip)
		if MultiplayerManager.error != OK:
			input_error.visible = true
			animation_player.play("text_fade", 0.5)
		else:
			start_screen.queue_free()
	#This is only for local testing
	elif debug_mode:
		MultiplayerManager.join_server("localhost")
		if MultiplayerManager.error != OK:
			input_error.visible = true
			animation_player.play("text_fade",-1, 0.5)
		else:
			start_screen.queue_free()


func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_server_ip_line_text_changed(new_text: String) -> void:
	server_ip = new_text
