extends Node3D

func _ready() -> void:
	$Players/MultiplayerSpawner.spawn_function = MultiplayerManager._spawn_player
