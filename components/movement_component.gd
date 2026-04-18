extends Node
class_name MovementComponent

## Component to handle all character locomotion logic.
## This node should be a child of the CharacterBody3D it controls.

@export var player: CharacterBody3D
@export var anim_state_tree: AnimationTree

# Movement parameters
@export var default_speed: float = 5.0
@export var walk_speed: float = 2.0
@export var sprint_speed: float = 7.0
@export var dodge_speed: float = 10.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

# Runtime state (synced or managed locally)
var input_dir: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO
var current_speed: float = 5.0
var strafing: bool = false
var strafe_cross_product: float = 0.0
var move_dot_product: float = 0.0

# Dependencies
@onready var current_camera: Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
    if not player:
        player = get_parent() as CharacterBody3D
    
    # Apply initial gravity setting from ProjectSettings if not explicitly set
    if gravity == 9.8:
        gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

## Calculate movement direction relative to camera
func calc_direction() -> Vector3:
    if not current_camera:
        current_camera = get_viewport().get_camera_3d()
    
    var forward_vector = Vector3(0, 0, 1).rotated(Vector3.UP, current_camera.global_rotation.y)
    var horizontal_vector = Vector3(1, 0, 0).rotated(Vector3.UP, current_camera.global_rotation.y)
    return (forward_vector * input_dir.y + horizontal_vector * input_dir.x)

## Standard free-roam movement
func free_movement(delta: float) -> void:
    var new_direction = calc_direction()
    
    var rate: float = 0.5 if player.is_on_floor() else 0.1
    
    if new_direction:
        player.velocity.x = move_toward(player.velocity.x, new_direction.x * current_speed, rate)
        player.velocity.z = move_toward(player.velocity.z, new_direction.z * current_speed, rate)
    else:
        player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
        player.velocity.z = move_toward(player.velocity.z, 0, 0.5)
    
    player.move_and_slide()

## Dash/Dodge movement (fixed direction burst)
func dash_movement(delta: float) -> void:
    var rate: float = 0.1
    player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, rate)
    player.velocity.z = move_toward(player.velocity.z, direction.z * current_speed, rate)
    player.move_and_slide()

## Player rotation logic
func rotate_player(_state: int, is_dodge: bool = false) -> void:
    var freelook: bool = not strafing or is_dodge
    
    var current_rotation = player.global_transform.basis.get_rotation_quaternion()
    var target_rotation: Quaternion
    
    if freelook:
        if input_dir:
            var new_direction = calc_direction().normalized()
            target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), 0.2)
            player.global_transform.basis = Basis(target_rotation)
    else:
        # Strafe rotation (facing orientation_target from Hub)
        # Note: Hub needs to provide orientation_target
        pass

## Apply gravity to player velocity
func apply_gravity(delta: float, is_flying: bool) -> void:
    if not is_flying and not player.is_on_floor():
        player.velocity.y -= gravity * delta

func jump() -> void:
    if player.is_on_floor():
        player.velocity.y = jump_velocity
