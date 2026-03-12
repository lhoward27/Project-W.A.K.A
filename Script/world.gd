extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state_machine = animation_tree["parameters/playback"]
@onready var access_light_mesh: MeshInstance3D = $Maze/Door/Keypad/AccessLight
@onready var access_spotlight: SpotLight3D = $Maze/Door/Keypad/AccessLight/SpotLight3D
@onready var access_spotlight_outer: SpotLight3D = $Maze/Door/Keypad2/AccessLight/SpotLight3D



var access_light_material
var access_light_color = Color("ff0000"):
	set(color):
		access_spotlight.light_color = color
		access_spotlight_outer.light_color = color

var is_open = false
var players_sensed = []

func _ready() -> void:
	$Players/MultiplayerSpawner.spawn_function = MultiplayerManager._spawn_player
	access_light_material = access_light_mesh.get_active_material(0)
	access_light_mesh.set_surface_override_material(0, access_light_material)
	_set_keypad_color("red")

func _on_door_body_entered(body: Node3D) -> void:
	players_sensed.append(body)
	if not is_open:
		animation_state_machine.travel("Door Open")
		_set_keypad_color("green")
		is_open = true

func _on_door_body_exited(body: Node3D) -> void:
	players_sensed.erase(body)
	if is_open and players_sensed.is_empty():
		animation_state_machine.travel("Door Close")
		_set_keypad_color("red")
		is_open = false

func _set_keypad_color(color):
	if color == "red":
		access_light_material.emission = Color(1.686, 0.0, 0.0)
		access_light_color = Color("ff0000")
	elif color == "green":
		access_light_material.emission = Color(0.0, 1.686, 0.0)
		access_light_color = Color("00ff00")
