extends Node
class_name FlyComponent

## Handles administrative "Fly Mode" movement.
## This operates by directly translating the player, bypassing move_and_slide.

@export var player: CharacterBody3D
@export var fly_speed: float = 10.0

var active: bool = false

func toggle() -> void:
	active = !active
	if active:
		# Lift player slightly when entering fly mode to indicate activation
		player.translate(Vector3(0, 0.5, 0))
		print("Fly Mode: ENABLED")
	else:
		print("Fly Mode: DISABLED")

func disable() -> void:
	if active:
		active = false
		print("Fly Mode: FORCED DISABLED")

func handle_movement(delta: float) -> void:
	if not active: 
		return
	
	# Vertical movement (Space for Up, Shift/Q for Down)
	if Input.is_action_pressed("jump"): # Spacebar
		player.translate(Vector3(0, fly_speed * delta, 0))
	if Input.is_action_pressed("dodge_dash"): # Q key
		player.translate(Vector3(0, -fly_speed * delta, 0))
	
	# Directional movement relative to character rotation
	# Note: This uses translate which moves in local space by default, 
	# but we want world-space identity if possible for consistent flight.
	# However, translating global_transform.basis.z is intuitive.
	
	var forward_dir = -player.global_transform.basis.z
	var right_dir = player.global_transform.basis.x
	
	var move_vec = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		move_vec += forward_dir
	if Input.is_action_pressed("move_backward"):
		move_vec -= forward_dir
	if Input.is_action_pressed("move_left"):
		move_vec -= right_dir
	if Input.is_action_pressed("move_right"):
		move_vec += right_dir
		
	if move_vec != Vector3.ZERO:
		player.translate(move_vec.normalized() * fly_speed * delta)
