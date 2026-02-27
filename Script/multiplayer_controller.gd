extends CharacterBody3D

# Player nodes
@onready var neck: Node3D = $Neck
@onready var head: Node3D = $Neck/Head
@onready var standing_cs: CollisionShape3D = $Standing_CS
@onready var crouching_cs: CollisionShape3D = $Crouching_CS
@onready var ray_cast_3d: RayCast3D = $RayCast3D # Used to check for ceiling when uncrouching
@onready var camera_3d: Camera3D = $Neck/Head/Eyes/Camera3D
@onready var eyes: Node3D = $Neck/Head/Eyes
@onready var head_mesh: MeshInstance3D = $littleguyywithlb/Armature/Skeleton3D/head
@onready var pause_menu: Control = $PauseMenu
@onready var ik_target: Node3D = $IK_Target
@onready var right_arm_ik: SkeletonIK3D = $littleguyywithlb/Armature/Skeleton3D/RightArm_IK
@onready var skeleton: Skeleton3D = $littleguyywithlb/Armature/Skeleton3D
@onready var player_synchronizer: MultiplayerSynchronizer = $PlayerSynchronizer
<<<<<<< Updated upstream
@onready var light_bulb: MeshInstance3D = $Littleguy/Armature/Skeleton3D/RightHandAttachment/Flashlight/SpotLight3D/LightBulb
=======
@onready var flashlight: SpotLight3D = $littleguyywithlb/Armature/Skeleton3D/RightHandAttachment/Flashlight/SpotLight3D
@onready var light_bulb: MeshInstance3D = $littleguyywithlb/Armature/Skeleton3D/RightHandAttachment/Flashlight/SpotLight3D/LightBulb
@onready var animation_player: AnimationPlayer = $Littleguy/AnimationPlayer

>>>>>>> Stashed changes

# Speed Vars
var current_speed = 5.0
@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 3.0
@export var mouse_sens = 0.4
var lerp_speed = 25
var crouch_lerp_speed = 10
var free_look_lerp_speed = 10
var slide_free_look_lerp_speed = 10
var head_bobbing_lerp_speed = 10

# Movement Vars
const jump_velocity = 6.5
var direction = Vector3()
var crouching_depth = -0.5
var free_look_tilt_amount = 10

#States
var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

#Slide vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10

# Headbobbing Vars
const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.1
const head_bobbing_walking_intensity = 0.05
const head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# Gravity Vars
var gravity = 20
var fall_gravity = 30
var is_rising = false

# Arm aiming vars
@export var arm_reach_distance: float = .4
var is_ik_initialized = false
var shoulder_bone_id
<<<<<<< Updated upstream
=======
var ik_update_counter = 0
const IK_UPDATE_INTERVAL = 2
>>>>>>> Stashed changes

var is_paused = false

# Multiplayer sync inputs
var keyboard_input_state = {
	"Left": false,
	"Right": false,
	"Forward": false,
	"Backward": false,
}
var actions_to_sync = ["Left", "Right", "Forward", "Backward"]

@export var player_id := 1:
	set(id):
		player_id = id

func _enter_tree() -> void:
	# Set authority based on node name (usually the peer ID in multiplayer)
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	var spawn_points_node = get_tree().current_scene.get_node("SpawnPoints")
	var spawn_points = spawn_points_node.get_children()
	print(spawn_points[1].global_position)
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_3d.current = true
		head_mesh.visible = false # Hide own head to prevent clipping into camera
		pause_menu.visible = false
		self.global_position = spawn_points[MultiplayerManager.player_count].global_position
	print(MultiplayerManager.player_count)

	
	# Initialize IK for arm aiming
	right_arm_ik.start()
	shoulder_bone_id = skeleton.find_bone("shoulder.L.001")
	if shoulder_bone_id != -1:
		is_ik_initialized = true
	else:
		push_warning("IK Bone not found")
		
	# Disable input processing for puppets (other players)
	if not is_multiplayer_authority():
		player_synchronizer.synchronized.connect(_update_ik_pose)
		set_process_unhandled_input(false)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		_update_ik_pose()
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	
	# Standardize server-side input check
	if multiplayer.is_server():
		input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	
	if velocity.y < 0:
		is_rising = true
	else:
		is_rising = false
		
	if not is_on_floor():
		gravity = 20 if is_rising else fall_gravity
	else:
		gravity = 20
		
	velocity.y -= gravity * delta
	
	# Jump Logic
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		sliding = false # Jumping cancels a slide
	
	
	# Crouch and Slide
	if Input.is_action_pressed("Crouch") || sliding:
		current_speed = crouching_speed
		head.position.y = lerp(head.position.y, crouching_depth, delta * crouch_lerp_speed)
		standing_cs.disabled = true
		crouching_cs.disabled = false
		
		# Trigger Slide if sprinting
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			free_looking = true # Auto-enable freelook during slides
		
		walking = false
		sprinting = false
		crouching = true
		
	# Standing Up (Check for ceiling collision before standing)
	elif !ray_cast_3d.is_colliding():
		standing_cs.disabled = false
		crouching_cs.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)
		
		if Input.is_action_pressed("Sprint"):
			current_speed = sprinting_speed
			walking = false
			sprinting = true
			crouching = false
		else:
			current_speed = walking_speed
			walking = true
			sprinting = false
			crouching = false
	
	# --- CAMERA EFFECTS ---
	
	# Free Look Logic
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true
		if sliding:
			# Tilt camera during slide
			camera_3d.rotation.z = lerp(camera_3d.rotation.z,-deg_to_rad(7.0), delta * slide_free_look_lerp_speed)	
		else:
			# Tilt based on neck rotation
			camera_3d.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt_amount)
	else:
		free_looking = false
		# Reset rotations when not freelooking
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * free_look_lerp_speed)
		camera_3d.rotation.z = lerp(neck.rotation.z, 0.0, delta * free_look_lerp_speed)

	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
		# Manual cancel
		if slide_timer <= slide_timer_max * 0.65 && Input.is_action_just_pressed("Player Controls"):
			sliding = false
	
	# Handle Headbobbing
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) + 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity/2.0), delta * head_bobbing_lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * head_bobbing_lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * head_bobbing_lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * head_bobbing_lerp_speed)
	
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed)
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		if sliding:
			# Slow down as the slide timer runs out
			velocity.x = direction.x * (slide_timer + 0.1) * slide_speed
			velocity.z = direction.z * (slide_timer + 0.1) * slide_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# Handle animation
	if walking && input_dir != Vector2.ZERO:
		$Littleguy/AnimationPlayer.play("Walk",-1, 2)
	if sprinting && input_dir != Vector2.ZERO:
		$Littleguy/AnimationPlayer.play("Walk",-1, 3.4)
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:	 
	if not is_multiplayer_authority(): return
		  
	# Mouse looking logic
	if event is InputEventMouseMotion and not is_paused:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y,deg_to_rad(-120), deg_to_rad(120))
		else:
			# Rotate body for horizontal, head for vertical
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
			head.rotation.x = clamp(head.rotation.x,deg_to_rad(-45), deg_to_rad(65))
			update_camera_rotation.rpc_id(1, rotation.y, head.rotation.x)
	
	# Sync input state to server
	for action in actions_to_sync:
		if event.is_action_pressed(action) or event.is_action_released(action):
			var is_pressed = Input.is_action_pressed(action)
			update_single_action_rpc.rpc_id(1, action, is_pressed)
	
	# Toggle Flashlight
	if event.is_action_pressed("Flashlight"):
		if flashlight.light_energy > 0:
			light_bulb.visible = false
			flashlight.light_energy = 0
		else:
			light_bulb.visible = true
			flashlight.light_energy = 1

	# Pause Menu
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.visible = true
		is_paused = true

# Updates the arm IK to point toward where the camera is looking
func _update_ik_pose():
	if not is_ik_initialized:
		return
		
	var space_state = get_world_3d().direct_space_state
	var cam_transform = camera_3d.global_transform
	
	# Raycast from camera to find looking-at point
	var ray_query = PhysicsRayQueryParameters3D.create(cam_transform.origin, cam_transform.origin + -cam_transform.basis.z * 1000)
	var result = space_state.intersect_ray(ray_query)
	var target_pos: Vector3
	
	if result:
		target_pos = result.position
	else:
		target_pos = cam_transform.origin + -cam_transform.basis.z * 1000
		
	# Calculate arm direction from shoulder to target
	var shoulder_transform: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(shoulder_bone_id)
	var shoulder_pos: Vector3 = shoulder_transform.origin
	var aim_direction = (target_pos - shoulder_pos).normalized()
	var hand_target_pos = shoulder_pos + aim_direction * arm_reach_distance
	
	if not free_looking:
		ik_target.global_transform = Transform3D(cam_transform.basis, hand_target_pos)

@rpc("any_peer", "call_local")
func update_camera_rotation(body_rotation, camera_rotation):
	rotation.y = body_rotation
	head.rotation.x = camera_rotation

@rpc("any_peer", "call_local", "reliable")
func update_single_action_rpc(action, is_pressed):
	if action in keyboard_input_state:
		keyboard_input_state[action] = is_pressed

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_resume_button_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.visible = false
	is_paused = false

func _on_start_screen_button_pressed() -> void:
	MultiplayerManager.rpc("_remove_player_request")
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
