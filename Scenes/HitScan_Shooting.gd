extends Camera3D

# Preload the bullet decal scene so we can instantiate it quickly when needed
@onready var b_decal = preload("res://Scenes/bullet_decal.tscn")

# Reference to the node that will parent all decals
# Change the path if dumping grounds for decals changes
@onready var decal_dump = get_tree().current_scene.get_node("DecalDump")

# Maximum number of bullet hole decals allowed at the same time
const MAX_DECALS: int = 30

# Array that keeps track of every active decal in the order they were created
# Oldest decals are at index 0 → newest at the end
var active_decals: Array[Node] = []

# How far the ray should travel when checking for hits (in units)
var ray_range: float = 2000.0

# User input handler
func _input(event: InputEvent) -> void:
	# Only react when the "Shoot" action is pressed (Currently Left Click)
	if event.is_action_pressed("Shoot"):
		get_camera_collision()

# Main function: shoots a ray from the center of the screen and places a decal where it hits
func get_camera_collision() -> void:
	# Get the center of the current viewport
	var center: Vector2 = get_viewport().get_size() / 2.0
	
	# Convert that 2D screen point into a 3D world ray origin and direction
	var ray_origin: Vector3 = project_ray_origin(center)
	var ray_direction: Vector3 = project_ray_normal(center)
	var ray_end: Vector3 = ray_origin + ray_direction * ray_range
	
	# Create raycast parameters
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# Get direct access to the physics world and cast the ray
	var space_state = get_world_3d().direct_space_state
	var intersection: Dictionary = space_state.intersect_ray(query)
	
	# If nothing was hit (ray went into empty space / sky)
	if intersection.is_empty():
		print("Air")
		return  # Exit early — no decal needed
	
	# ────────────────────────────────────────────────────────────────
	# We hit something → time to create and place a decal
	# ────────────────────────────────────────────────────────────────
	
	# Instantiate a new copy of the bullet decal scene
	var decal: Node = b_decal.instantiate()
	
	# Store hit information for ez access
	var hit_pos: Vector3 = intersection.position
	var hit_normal: Vector3 = intersection.normal
	
	# Add the decal as a child of DecalDump
	decal_dump.add_child(decal)
	
	# Move decal exactly to the hit point
	decal.global_position = hit_pos
	
	# Rotate decal so it faces along the surface normal
	# (Vector3.UP is used as "up" direction to avoid flipping)
	decal.look_at(hit_pos + hit_normal, Vector3.UP)
	
	# ────────────────────────────────────────────────────────────────
	# Manage decal limit (keep only the most recent MAX_DECALS)
	# ────────────────────────────────────────────────────────────────
	
	# If we already have the maximum allowed decals
	if active_decals.size() >= MAX_DECALS:
		# Get and remove the oldest decal from the beginning of the array
		var oldest: Node = active_decals.pop_front()
		
		# Safety check: make sure it still exists before trying to delete
		if is_instance_valid(oldest):
			oldest.queue_free()  # Marks it for deletion at the end of the frame
	
	# Add our brand-new decal to the end of the tracking array
	active_decals.append(decal)
	
	# Optional debug output — shows current number of managed decals
	# print("Active decals now: ", active_decals.size())
	# print("Hit object: ", intersection.collider.name)
	# print(intersection)
