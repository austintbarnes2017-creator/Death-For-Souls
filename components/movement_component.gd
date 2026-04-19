extends Node
class_name MovementComponent

## Component to handle all character locomotion logic.
## This node should be a child of the CharacterBody3D it controls.

@export var player: CharacterBody3D
@export var anim_state_tree: AnimationTree

# Locomotion Parameters
@export var default_speed: float = 4.0
@export var walk_speed: float = 1.0
@export var sprint_speed: float = 7.0
@export var dodge_speed: float = 10.0
@export var ladder_climb_speed: float = 1.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

var strafing: bool = false :
	set(val):
		strafing = val
		if player:
			player.strafing = val
var strafe_cross_product: float = 0.0
var move_dot_product: float = 0.0

# Networking & CSP State
var current_tick: int = 0
var input_history: Dictionary = {}   # Tick -> {"d": Vector3, "s": int, "sf": bool}
var state_history: Dictionary = {}   # Tick -> GlobalPosition
var last_input: Dictionary = {"d": Vector3.ZERO, "s": 1, "sf": false} # Default state: FREE
var reconciliation_threshold: float = 0.05

# Smoothing for remote proxies
var target_pos: Vector3 = Vector3.ZERO
var target_rot: Vector3 = Vector3.ZERO

# Input state (synced locally)
var input_dir: Vector2 = Vector2.ZERO
var current_speed: float = 4.0
var direction: Vector3 = Vector3.ZERO # Dash/Dodge direction

# Diagnostic state
var _has_received_sync: bool = false
func _net_trace(event: String, details: String = "") -> void:
	var my_id = multiplayer.get_unique_id()
	var role = "REMOTE"
	if player.network_sync:
		if player.network_sync.is_local_player():
			role = "OWNER"
		if multiplayer.is_server():
			role = "SERVER"
	
	var subject = player.name
	print("[%d] -> [%s] (%s) [%s] %s" % [my_id, subject, role, event.to_upper(), details])

@export var server_state: Dictionary = {"t": 0, "p": Vector3.ZERO, "v": Vector3.ZERO} :
	set(val):
		server_state = val
		if player and player.network_sync and not player.network_sync.is_local_player():
			# For remote proxies, we store the target and interpolate in handle_free_movement
			target_pos = server_state.p
			if "r" in server_state: target_rot = server_state.r
			player.velocity = server_state.v
			
			# Align proxy timeline with server
			current_tick = server_state.t
			player.tick = server_state.t
			
			# Unpack animation state
			if "id" in server_state: player.input_dir = server_state.id
			if "sf" in server_state: player.strafing = server_state.sf
			if "cp" in server_state: player.strafe_cross_product = server_state.cp
			if "dp" in server_state: player.move_dot_product = server_state.dp
			if "cs" in server_state: player.current_state = server_state.cs
			if "wt" in server_state: player.weapon_type = server_state.wt
			if "gt" in server_state: player.gadget_type = server_state.gt
			if "gu" in server_state: player.guarding = server_state.gu
		
		# Clock Sync: If local player, align our tick with server authoritative tick
		if player and player.network_sync and player.network_sync.is_local_player() and not multiplayer.is_server():
			if abs(current_tick - server_state.t) > 20: # If more than 0.3s out of sync
				_net_trace("CLOCK_SNAP", "Local %d -> Server %d" % [current_tick, server_state.t])
				current_tick = server_state.t
				NetworkManager.match_tick = server_state.t
				player.tick = server_state.t
		
		# Replication Auditor: Log first time data arrives for remote machine
		if not _has_received_sync and not player.network_sync.is_local_player() and server_state.p != Vector3.ZERO:
			_has_received_sync = true
			_net_trace("SYNC_CONNECTED", "First packet received at %s" % str(server_state.p.snapped(Vector3.ONE * 0.1)))

		# Throttled Heartbeat
		if current_tick % 120 == 0:
			var details = "Tick: %d | Pos: %s | WT: %s" % [current_tick, str(player.global_position.snapped(Vector3.ONE * 0.1)), player.weapon_type]
			_net_trace("HEARTBEAT", details)
		
		if player and player.network_sync and player.network_sync.is_local_player() and not multiplayer.is_server():
			# This is the local player on a client, reconcile
			_reconcile_server_state()

# Dependencies — lazy-init to avoid grabbing the freed placeholder camera
var current_camera: Camera3D :
	get:
		if not is_instance_valid(current_camera):
			current_camera = get_viewport().get_camera_3d()
		return current_camera

var sprint_timer : Timer
var dodge_timer : Timer

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	
	target_pos = player.global_position
	target_rot = player.global_rotation
	
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Dynamically create timers
	sprint_timer = Timer.new()
	sprint_timer.name = "SprintTimer"
	sprint_timer.one_shot = true
	add_child(sprint_timer)
	
	dodge_timer = Timer.new()
	dodge_timer.name = "DodgeTimer"
	dodge_timer.one_shot = true
	dodge_timer.timeout.connect(_on_dodge_timer_timeout)
	add_child(dodge_timer)

## Calculate movement direction relative to camera
func calc_direction() -> Vector3:
	if not current_camera:
		current_camera = get_viewport().get_camera_3d()
	
	var forward_vector = Vector3(0, 0, 1).rotated(Vector3.UP, current_camera.global_rotation.y)
	var horizontal_vector = Vector3(1, 0, 0).rotated(Vector3.UP, current_camera.global_rotation.y)
	return (forward_vector * input_dir.y + horizontal_vector * input_dir.x)

## Updates speed based on the HUB state
func update_speed(state: int) -> void:
	# Note: state matches CharacterBodySoulsBase.state enum
	match state:
		0: # SPAWN / STATIC_ACTION
			current_speed = 0.0
		1: # FREE
			current_speed = default_speed
		4: # DODGE
			current_speed = dodge_speed
		5: # SPRINT
			current_speed = sprint_speed
		6: # LADDER
			current_speed = ladder_climb_speed
		3: # DYNAMIC_ACTION
			current_speed = walk_speed

## Standard free-roam movement (Authoritative Refactor)
func handle_free_movement(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		# Offline mode fallback
		_process_local_movement(_delta)
		return

	if player.network_sync and player.network_sync.is_local_player():
		# This is the local player on their own machine (Predict)
		_process_client_prediction(_delta)
	elif multiplayer.is_server():
		# This is a client's proxy on the server (Authority)
		_process_server_authority(_delta)
	else:
		# This is a remote proxy on a client (Interpolate)
		player.global_position = player.global_position.lerp(target_pos, 0.2)
		player.global_rotation.y = lerp_angle(player.global_rotation.y, target_rot.y, 0.2)
	
	# SERVER ONLY: Always generate authoritative state for clients
	if multiplayer.is_server():
		_pack_server_state()

func _process_local_movement(_delta: float) -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.input_dir = input_dir
	_apply_movement_logic(_delta, input_dir)
	player.move_and_slide()

func _process_client_prediction(_delta: float) -> void:
	# 1. Capture raw input
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.input_dir = input_dir
	
	# 2. Calculate world-space direction (Camera-relative) LOCALLY
	# This ensures the server uses the EXACT vector the client intended
	var move_dir = calc_direction().normalized()
	
	# 3. Store for reconciliation
	input_history[current_tick] = move_dir
	state_history[current_tick] = player.global_position
	
	# 4. Predict locally
	_apply_movement_logic_deterministic(_delta, move_dir)
	player.move_and_slide()
	
	# 5. Send intended state to server
	if not multiplayer.is_server():
		rpc_id(1, "server_receive_input", current_tick, move_dir, player.current_state, player.strafing)

@rpc("any_peer", "call_remote", "unreliable")
func server_receive_input(tick: int, world_dir: Vector3, p_state: int, p_strafing: bool):
	if not multiplayer.is_server(): return
	input_history[tick] = {"d": world_dir, "s": p_state, "sf": p_strafing}

func _process_server_authority(_delta: float) -> void:
	# JITTER BUFFER: Look back 2 ticks
	var process_tick = current_tick - 2
	
	if input_history.has(process_tick):
		var input = input_history[process_tick]
		
		# LEGACY GUARD: Handle transition from Vector3 to Dictionary
		if input is Vector3:
			_apply_movement_logic_deterministic(_delta, input)
		else:
			last_input = input # Current input becomes the extrapolation base
			# Enforce the client's reported state during THIS tick
			player.current_state = input.s
			player.strafing = input.sf
			_apply_movement_logic_deterministic(_delta, input.d)
		
		player.move_and_slide()
		input_history.erase(process_tick)
	else:
		# EXTRAPOLATION: Repeat last known intended movement if packet is lost
		# This prevents the character from 'freezing/jumping' due to jitter.
		player.current_state = last_input.s
		player.strafing = last_input.sf
		_apply_movement_logic_deterministic(_delta, last_input.d)
		player.move_and_slide()

func _pack_server_state() -> void:
	# Calculate animation factors before packing
	var velocity_local = player.global_transform.basis.inverse() * player.velocity
	strafe_cross_product = velocity_local.x / current_speed if current_speed > 0 else 0.0
	move_dot_product = -velocity_local.z / current_speed if current_speed > 0 else 0.0
	
	# Pack Authoritative State
	server_state = {
		"t": current_tick,
		"p": player.global_position,
		"v": player.velocity,
		"r": player.global_rotation,
		"id": input_dir,
		"sf": strafing,
		"cp": strafe_cross_product,
		"dp": move_dot_product,
		"cs": player.current_state,
		"wt": player.weapon_type,
		"gt": player.gadget_type,
		"gu": player.guarding
	}

func _reconcile_server_state():
	var tick = server_state.t
	if not state_history.has(tick): return
	
	var predicted_pos = state_history[tick]
	var error = predicted_pos.distance_to(server_state.p)
	
	if error > reconciliation_threshold:
		# SOFT RECONCILIATION: Smoothly blend instead of snapping for small errors
		if error < 1.0:
			player.global_position = player.global_position.lerp(server_state.p, 0.5)
		else:
			# HARD SNAP: Teleport for large errors (anti-cheat/major desync)
			player.global_position = server_state.p
			_net_trace("PREDICTION_ERROR", "Error: %.3fm | Hard Snap to %s" % [error, str(server_state.p.snapped(Vector3.ONE * 0.1))])

		player.velocity = server_state.v
		
		# REPLAY missed inputs to catch up to present
		var replay_tick = tick + 1
		var physics_delta = 1.0 / Engine.physics_ticks_per_second
		
		while replay_tick < current_tick:
			if input_history.has(replay_tick):
				var input = input_history[replay_tick]
				
				# LEGACY GUARD: Handle transition from Vector3 to Dictionary
				if input is Vector3:
					_apply_movement_logic_deterministic(physics_delta, input)
				else:
					# Enforce state during replay parity
					player.current_state = input.s
					player.strafing = input.sf
					_apply_movement_logic_deterministic(physics_delta, input.d)
				
				player.move_and_slide()
				# Update history with corrected prediction
				state_history[replay_tick] = player.global_position
			replay_tick += 1
			
	# Cleanup history
	var buffer_ticks = state_history.keys()
	for t in buffer_ticks:
		if t <= tick:
			state_history.erase(t)
			input_history.erase(t)

func _apply_movement_logic(_delta: float, i_dir: Vector2) -> void:
	if not current_camera:
		current_camera = get_viewport().get_camera_3d()
		
	var forward_vector = Vector3(0, 0, 1).rotated(Vector3.UP, current_camera.global_rotation.y)
	var horizontal_vector = Vector3(1, 0, 0).rotated(Vector3.UP, current_camera.global_rotation.y)
	var new_direction = (forward_vector * i_dir.y + horizontal_vector * i_dir.x)
	
	var rate: float = 0.5 if player.is_on_floor() else 0.1
	
	if new_direction:
		player.velocity.x = move_toward(player.velocity.x, new_direction.x * current_speed, rate)
		player.velocity.z = move_toward(player.velocity.z, new_direction.z * current_speed, rate)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
		player.velocity.z = move_toward(player.velocity.z, 0, 0.5)

func _apply_movement_logic_deterministic(_delta: float, world_dir: Vector3) -> void:
	var rate: float = 0.5 if player.is_on_floor() else 0.1
	
	# Apply Gravity (Crucial for parity)
	if not player.is_on_floor() and player.current_state != 6: # state.LADDER
		player.velocity.y -= gravity * _delta
	
	if world_dir:
		player.velocity.x = move_toward(player.velocity.x, world_dir.x * current_speed, rate)
		player.velocity.z = move_toward(player.velocity.z, world_dir.z * current_speed, rate)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 0.5)
		player.velocity.z = move_toward(player.velocity.z, 0, 0.5)

## Dash/Dodge movement (fixed direction burst)
func handle_dash_movement(_delta: float) -> void:
	var rate: float = 0.1
	player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, rate)
	player.velocity.z = move_toward(player.velocity.z, direction.z * current_speed, rate)
	player.move_and_slide()

## Ladder movement
func handle_ladder_movement(_delta: float) -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.input_dir = input_dir
	player.velocity = (Vector3.DOWN * input_dir.y) * current_speed
	# Exiting ladder state handled by HUB via interact_loc/is_on_floor checks
	player.move_and_slide()

## Player rotation logic
func rotate_player(_state: int, is_dodge: bool, orientation_target: Node3D) -> void:
	var freelook: bool = not strafing or is_dodge
	
	var current_rotation = player.global_transform.basis.get_rotation_quaternion()
	var target_rotation: Quaternion
	
	if freelook:
		if input_dir:
			var new_direction = calc_direction().normalized()
			target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, atan2(new_direction.x, new_direction.z)), 0.2)
			player.global_transform.basis = Basis(target_rotation)
	else:
		if orientation_target:
			target_rotation = current_rotation.slerp(Quaternion(Vector3.UP, orientation_target.global_rotation.y + PI), 0.4)
			player.global_transform.basis = Basis(target_rotation)
			
			var forward_vector = player.global_transform.basis.z.normalized()
			var new_direction = calc_direction().normalized()
			strafe_cross_product = -forward_vector.cross(new_direction).y
			move_dot_product = forward_vector.dot(new_direction)
			
			# Sync back to Hub for Animation Tree
			player.strafe_cross_product = strafe_cross_product
			player.move_dot_product = move_dot_product

## Apply gravity
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor() and player.current_state != 6: # state.LADDER
		player.velocity.y -= gravity * delta

func jump() -> void:
	if player.is_on_floor():
		player.jump_started.emit()
		# Animation wait logic remains in Hub or handled via signals
		player.velocity.y = jump_velocity

func is_sprinting_timer_active() -> bool:
	return sprint_timer.time_left > 0 if sprint_timer else false

func dash(_new_direction : Vector3 = Vector3.FORWARD, _duration = .1): 
	current_speed = dodge_speed
	if _new_direction:
		direction = (player.global_position - player.to_global(_new_direction)).normalized()
	await get_tree().create_timer(_duration).timeout
	direction = Vector3.ZERO
	
func dodge_or_sprint():
	if sprint_timer.is_stopped():
		sprint_timer.start(.3)
		await sprint_timer.timeout
		if player.current_state == 1 and input_dir: # state.FREE
			player.current_state = 5 # state.SPRINT
			player.sprint_started.emit()
		
func end_sprint():
	if player.current_state == 5: # state.SPRINT
		player.current_state = 1 # state.FREE
		
func dodge(_camera: Camera3D): 
	player.current_state = 4 # state.DODGE
	if player.combat_component:
		player.combat_component.can_be_hurt = false
	sprint_timer.stop()
	
	if input_dir:
		direction = calc_direction()
		player.dodge_started.emit()
	else:
		var backward_dir = (player.global_position - player.to_global(Vector3.BACK)).normalized()
		player.velocity = backward_dir * (dodge_speed * .75)
		player.dodge_started.emit()
	
	# Wait for animation timing via signal hub logic
	dodge_timer.start(0.7) # Fixed fallback, actual length from hub anim_length

func _on_dodge_timer_timeout():
	player.dodge_ended.emit()
	current_speed = default_speed
	player.current_state = 1 # state.FREE
	if player.combat_component:
		player.combat_component.can_be_hurt = true

func start_ladder(top_or_bottom, mount_transform):
	player.ladder_started.emit(top_or_bottom)
	# The tweening and state transition still happens in the Hub 
	# because it involves global_transform and specific sequence timing
	# Or we can move it here if we want full isolation.
	var anim_len = player.anim_length if "anim_length" in player else 0.5
	var tween = get_tree().create_tween()
	tween.tween_property(player, "global_transform", mount_transform, anim_len * 0.4)
	await tween.finished
	player.current_state = 6 # state.LADDER
	
func exit_ladder(exit_loc):
	player.current_state = 2 # state.STATIC_ACTION
	player.ladder_finished.emit(exit_loc)
	var dismount_pos
	var anim_len = player.anim_length if "anim_length" in player else 0.5
	
	match exit_loc:
		"TOP":
			dismount_pos = player.to_global(Vector3(0,1.5,.5))
		"BOTTOM":
			dismount_pos = player.global_position
			
	var tween = get_tree().create_tween()
	tween.tween_property(player, "global_position", dismount_pos, anim_len * 0.6)
	await tween.finished
	player.current_state = 1 # state.FREE
