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
        # Lift player slightly when entering fly mode
        player.translate(Vector3(0, 2, 0))
    
    # Notify Hub/Movement that gravity should be disabled
    # signal fly_mode_toggled(active)

func handle_movement(delta: float) -> void:
    if not active: return
    
    # Vertical movement (Space for Up, Shift/Q for Down)
    if Input.is_action_pressed("jump"):
        player.translate(Vector3(0, fly_speed * delta, 0))
    if Input.is_action_pressed("dodge_dash"):
        player.translate(Vector3(0, -fly_speed * delta, 0))
    
    # Directional movement relative to character rotation
    var forward_dir = -player.global_transform.basis.z
    var right_dir = player.global_transform.basis.x
    
    if Input.is_action_pressed("move_forward"):
        player.translate(forward_dir * fly_speed * delta)
    if Input.is_action_pressed("move_backward"):
        player.translate(-forward_dir * fly_speed * delta)
    if Input.is_action_pressed("move_left"):
        player.translate(-right_dir * fly_speed * delta)
    if Input.is_action_pressed("move_right"):
        player.translate(right_dir * fly_speed * delta)
