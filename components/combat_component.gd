extends Node
class_name CombatComponent

## Handles combat-related states, timers, and logic.

@export var player: CharacterBody3D
@export var anim_state_tree: AnimationTree

# Combat parameters
@export var parry_window: float = 0.3
@export var attack_dash_duration: float = 0.3

# Runtime state
@export var guarding: bool = false
var parry_active: bool = false
var can_be_hurt: bool = true
var is_dead: bool = false

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	
	# Force sync initial state
	if player:
		player.guarding = guarding
	
	if player.has_signal("death_started"):
		is_dead = false

func start_guard() -> void:
	guarding = true
	player.guarding = true
	parry_active = true
	player.current_state = 3 # state.DYNAMIC_ACTION
	await get_tree().create_timer(parry_window).timeout
	parry_active = false

func end_guard() -> void:
	guarding = false
	player.guarding = false
	parry_active = false
	player.current_state = 1 # state.FREE

func hit(_who: Node3D, _by_what: EquipmentResource) -> void:

	if not can_be_hurt:
		return
		
	if parry_active:
		parry()
		if _who.has_method("parried"):
			_who.parried()
	elif guarding:
		block()
	else:
		player.damage_taken.emit(_by_what)
		hurt()

func block() -> void:
	player.current_state = 2 # state.STATIC_ACTION
	player.block_started.emit()
	var anim_len = player.anim_length if "anim_length" in player else 0.5
	await get_tree().create_timer(anim_len).timeout
	if player.current_state == 2: # state.STATIC_ACTION
		player.current_state = 3 # state.DYNAMIC_ACTION

func parry() -> void:
	player.current_state = 2 # state.STATIC_ACTION
	can_be_hurt = false
	player.parry_started.emit()
	var anim_len = player.anim_length if "anim_length" in player else 0.5
	await get_tree().create_timer(anim_len).timeout
	if player.current_state == 2: # state.STATIC_ACTION
		player.current_state = 1 # state.FREE
	can_be_hurt = true

func hurt() -> void:
	player.current_state = 2 # state.STATIC_ACTION
	can_be_hurt = false
	player.hurt_started.emit()
	var anim_len = player.anim_length if "anim_length" in player else 0.5
	await get_tree().create_timer(anim_len).timeout
	if not is_dead:
		if player.current_state == 2: # state.STATIC_ACTION
			player.current_state = 1 # state.FREE
		can_be_hurt = true

func death() -> void:
	player.current_state = 2 # state.STATIC_ACTION
	can_be_hurt = false
	is_dead = true
	player.death_started.emit()
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()
