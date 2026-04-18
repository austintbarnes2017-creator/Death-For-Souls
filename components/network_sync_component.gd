extends Node
class_name NetworkSyncComponent

## Acts as the bridge for multiplayer synchronization.
## This node should contain or manage the MultiplayerSynchronizer.

@export var player: CharacterBody3D
@export var sync_node: MultiplayerSynchronizer

func _ready() -> void:
    if not player:
        player = get_parent() as CharacterBody3D
    
    # Authority Guard: Disable logic on non-authoritative peers
    # Note: In a server-authoritative model, only the server processes physics.
    setup_authority()

func setup_authority() -> void:
    if not is_multiplayer_authority():
        # Clients typically disable physics and manual movement
        # but might keep prediction logic if implemented via Netfox.
        player.set_physics_process(false)
        player.set_process_unhandled_input(false)
    else:
        # Server or local authority
        player.set_physics_process(true)

## Bind properties to the synchronizer dynamically if needed
func register_sync_properties() -> void:
    if not sync_node: return
    # Properties are usually set in the .tscn inspector, 
    # but can be verified here.
    pass
