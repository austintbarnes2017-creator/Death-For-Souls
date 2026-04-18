extends Node
class_name CombatComponent

## Handles combat-related states, timers, and logic.

@export var player: CharacterBody3D
@export var anim_state_tree: AnimationTree

# Combat parameters
@export var parry_window: float = 0.3
@export var attack_dash_duration: float = 0.3

# Runtime state
var guarding: bool = false
var parry_active: bool = false
var can_be_hurt: bool = true

# Signals
signal attack_triggered
signal parry_started
signal block_started

func start_guard() -> void:
    guarding = true
    parry_active = true
    # Start parry window timer
    await get_tree().create_timer(parry_window).timeout
    parry_active = false

func end_guard() -> void:
    guarding = false
    parry_active = false

func handle_hit(who: Node3D, by_what: Node) -> String:
    if not can_be_hurt: return "INVULNERABLE"
    
    if parry_active:
        parry_started.emit()
        if who.has_method("parried"):
            who.parried()
        return "PARRIED"
    elif guarding:
        block_started.emit()
        return "BLOCKED"
    
    return "HURT"
