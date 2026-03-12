extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_open = false
var players_sensed = []

func _ready() -> void:
	$Players/MultiplayerSpawner.spawn_function = MultiplayerManager._spawn_player

func _on_door_body_entered(body: Node3D) -> void:
	players_sensed.append(body)
	if not is_open:
		animation_player.play("Door Open")
		is_open = true

func _on_door_body_exited(body: Node3D) -> void:
	players_sensed.erase(body)
	if is_open and players_sensed.is_empty():
		animation_player.play("Door Close")
		is_open = false
