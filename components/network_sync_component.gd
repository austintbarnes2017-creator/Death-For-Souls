extends Node
class_name NetworkSyncComponent

## Acts as the bridge for multiplayer synchronization.
## This node should contain or manage the MultiplayerSynchronizer.

@export var player: CharacterBody3D
@export var sync_node: MultiplayerSynchronizer

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	
	# Defer authority setup so it runs AFTER NetworkManager sets multiplayer_authority
	call_deferred("setup_authority")

## Returns true if this peer controls this player character locally
func is_local_player() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true # Default to local authority in solo or pre-handshake
	return is_multiplayer_authority()

func setup_authority() -> void:
	# For server-authoritative movement/state, the synchronizer MUST be owned by the server (ID 1).
	# Previously, setting it to the player_id allowed idle clients to overwrite server calculations.
	sync_node.set_multiplayer_authority(1)
	
	var auth_id = sync_node.get_multiplayer_authority()
	var my_id = multiplayer.get_unique_id()
	print("NetworkSyncComponent: Authority forced to ", auth_id, " (Server) for node '", player.name, "'. Local Peer: ", my_id)
	
	# Configure the MultiplayerSynchronizer to actually sync position/rotation
	_configure_synchronizer()
	
	# Find the FollowCam (SpringArm3D) and its child Camera3D
	var follow_cam = player.find_child("FollowCam", true, false)
	var camera_3d: Camera3D = null
	if follow_cam:
		# FollowCam exports a camera_3d property
		if "camera_3d" in follow_cam and follow_cam.camera_3d is Camera3D:
			camera_3d = follow_cam.camera_3d
		else:
			# Fallback: search for Camera3D child
			for child in follow_cam.get_children():
				if child is Camera3D:
					camera_3d = child
					break
	
	# ALWAYS enable physics process so remote proxies can interpolate/run animation logic
	player.set_physics_process(true)
	
	if is_local_player():
		print("NetworkSyncComponent: [LOCAL] Enabling input and camera for ", player.name)
		player.set_process_unhandled_input(true)
		player.set_process_input(true)
		
		# Activate camera for local player
		if camera_3d:
			camera_3d.current = true
			print("NetworkSyncComponent: Camera activated for local player ", player.name)
		
		# Enable FollowCam processing (mouse/joystick)
		if follow_cam:
			follow_cam.set_process(true)
			follow_cam.set_physics_process(true)
			follow_cam.set_process_input(true)
	else:
		print("NetworkSyncComponent: [REMOTE] Disabling input and camera for ", player.name)
		player.set_process_unhandled_input(false)
		player.set_process_input(false)
		
		# Ensure remote camera is NOT current
		if camera_3d:
			camera_3d.current = false
		
		# Disable FollowCam processing entirely for remote players
		if follow_cam:
			follow_cam.set_process(false)
			follow_cam.set_physics_process(false)
			follow_cam.set_process_input(false)



## Configure the MultiplayerSynchronizer to replicate animation-driving state
## in ADDITION to the editor-configured properties (server_state, guarding, health).
func _configure_synchronizer() -> void:
	if not sync_node: return
	
	var total = 0
	if sync_node.replication_config:
		total = sync_node.replication_config.get_properties().size()
	
	print("NetworkSyncComponent: Using editor-configured sync for ", player.name, " (Total: ", total, ")")
