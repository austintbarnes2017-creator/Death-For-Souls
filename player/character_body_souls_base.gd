extends CharacterBody3D
class_name CharacterBodySoulsBase

## Character system integration
var character_data: Dictionary = {}

@onready var movement_component : MovementComponent = $MovementComponent
@onready var combat_component : CombatComponent = $CombatComponent
@onready var fly_component : FlyComponent = $FlyComponent
@onready var network_sync : NetworkSyncComponent = $NetworkSyncComponent

## default/1st camera is a follow cam.
@onready var current_camera = get_viewport().get_camera_3d()
## Aids strafe rotation when alternating between cameras
@onready var orientation_target = current_camera

## Sensing interactable objects, like ladders, doors, etc. 
@export var interact_sensor : Node3D
## The sensor that spotted the object, TOP sensor, or BOTTOM sensor.
@onready var interact_loc : String # use "TOP","BOTTOM","BOTH"
## The newly sensed interactable node.
@onready var interactable : Node3D
signal interact_started
# signal door_started # Placeholder: Trigger in start_interact() when interact_type == "DOOR"
# signal gate_started # Placeholder: Trigger in start_interact() when interact_type == "GATE"
# signal chest_started # Placeholder: Trigger in start_interact() when interact_type == "CHEST"
# signal lever_started # Placeholder: Trigger in start_interact() when interact_type == "LEVER"


## Weapons and attacking equipment system that manages moving nodes from the 
## attacking hand, to their sheathed location
@export var weapon_system : EquipmentSystem
## A helper variable, tracks the current weapon type for easier referencing from
## the anim_state_tree
@onready var attack_combo_timer = Timer.new()
var weapon_type :String = "SLASH"
signal weapon_change_started
signal weapon_changed
signal weapon_change_ended
signal attack_started
signal attack_activated
signal air_attack_started
signal big_attack_started
## A helper variable for keyboard events across 2 key inputs "shift+ attack", etc.
var secondary_action

## Gadgets and guarding equipment system that manages moving nodes from the 
## off-hand, to their hip location
@export var gadget_system : EquipmentSystem
## A helper variable, tracks the current gadget type for easier referencing from
## the anim_state_tree
var gadget_type :String = "SHIELD"
signal gadget_change_started
signal gadget_changed
signal gadget_change_ended
signal gadget_started
signal gadget_activated



@export var health_system :Node
signal hurt_started
signal parry_started
signal block_started
signal damage_taken
signal health_received
signal death_started
var is_dead :bool = false
# signal respawn_started # Placeholder: Trigger when the respawn sequence begins.
@export var last_spawn_site : SpawnSite

@export var inventory_system : InventorySystem
var current_item : ItemResource
signal item_change_started
signal item_changed
signal item_change_ended
signal use_item_started
signal item_used

# Physics & Gravity
@onready var last_altitude = global_position
@export var hard_landing_height :float = 4 # how far they can fall before 'hard landing'
signal landed_hard
signal jump_started
signal dodge_started
signal dodge_ended
signal sprint_started
signal ladder_started
signal ladder_finished

# Movement state proxies (read by Animation Tree)
var strafing : bool = false
var input_dir : Vector2
var strafe_cross_product : float
var move_dot_product : float
var guarding : bool = false

# Strafing signals
signal strafe_toggled

@export var anim_state_tree : AnimationTree
@onready var anim_length

# State management
enum state {SPAWN,FREE,STATIC_ACTION,DYNAMIC_ACTION,DODGE,SPRINT,LADDER,ATTACK}
@onready var current_state = state.STATIC_ACTION : set = change_state
signal changed_state

func _ready():
	# Add to player group for admin panel access
	add_to_group("player")
	
	# Initialize mouse mode for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if anim_state_tree:
		anim_state_tree.animation_measured.connect(_on_animation_measured)

	if interact_sensor:
		interact_sensor.interact_updated.connect(_on_interact_updated)
		
	if weapon_system:
		weapon_system.equipment_changed.connect(_on_weapon_equipment_changed)
		_on_weapon_equipment_changed(weapon_system.current_equipment)
		
	if gadget_system:
		gadget_system.equipment_changed.connect(_on_gadget_equipment_changed)
		_on_gadget_equipment_changed(gadget_system.current_equipment)
	
	if inventory_system:
		inventory_system.item_used.connect(_on_inventory_item_used)
			
	if health_system:
		health_system.died.connect(death)
		
	# Components handle their own internal timers
	
	# Load character data from file
	load_character_data_from_file()
		
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	current_state = state.FREE

## Makes variable changes for each state, primiarily used for updating movement speeds
func change_state(new_state):
	current_state = new_state
	changed_state.emit(current_state)
	
	# Delegate speed and state logic to movement component
	if movement_component:
		movement_component.update_speed(current_state)

			
func _physics_process(_delta):
	if fly_component and fly_component.active:
		fly_component.handle_movement(_delta)
	elif movement_component:
		match current_state:
			state.FREE, state.SPRINT, state.DYNAMIC_ACTION:
				movement_component.rotate_player(current_state, false, orientation_target)
				movement_component.handle_free_movement(_delta)
			state.DODGE:
				movement_component.handle_dash_movement(_delta)
				movement_component.rotate_player(current_state, true, orientation_target)
			state.LADDER:
				movement_component.handle_ladder_movement(_delta)
			state.ATTACK:
				movement_component.handle_dash_movement(_delta)
		
		movement_component.apply_gravity(_delta)
		fall_check()
	
func _input(_event:InputEvent):
	if !Input.is_anything_pressed():
		current_camera = get_viewport().get_camera_3d()
	
	if _event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		
	if _event.is_action_pressed("strafe_target"):
		set_strafe_targeting()
		
	secondary_action = Input.is_action_pressed("secondary_action")
	
	if current_state == state.FREE:
		if is_on_floor():
			if _event.is_action_pressed("interact"):
				interact()
			elif _event.is_action_pressed("jump"):
				jump()
			elif _event.is_action_pressed("use_weapon_light"):
				attack(secondary_action)
			elif _event.is_action_pressed("use_weapon_strong"):
				attack(secondary_action)
			elif _event.is_action_pressed("dodge_dash"):
				dodge_or_sprint()
			elif _event.is_action_released("dodge_dash") and movement_component and movement_component.is_sprinting_timer_active():
				dodge()
			elif _event.is_action_pressed("change_primary"):
				weapon_change()
			elif _event.is_action_pressed("change_secondary"):
				gadget_change()
			elif _event.is_action_pressed("admin_panel"):
				toggle_admin_panel()
			elif _event.is_action_pressed("shift_lock"):
				toggle_shift_lock()
			elif _event.is_action_pressed("toggle_fly"):
				toggle_fly_mode()
			elif _event.is_action_pressed("use_gadget_strong"): 
				use_gadget()
			elif _event.is_action_pressed("use_gadget_light"):
				if secondary_action:
					use_gadget()
				else:
					start_guard()
			elif _event.is_action_pressed("change_item"):
				item_change()
			elif _event.is_action_pressed("use_item"): 
				use_item()
		else:
			if _event.is_action_pressed("use_weapon_light"):
				air_attack()
	
	elif current_state == state.SPRINT:
		if _event.is_action_released("dodge_dash"):
			end_sprint()
		elif _event.is_action_pressed("jump"):
			jump()
				
	elif current_state == state.LADDER:
		if _event.is_action_pressed("dodge_dash"):
			current_state = state.FREE
				
	if _event.is_action_released("use_gadget_light"):
		if not secondary_action:
			end_guard()
	
func set_strafe_targeting():
	if movement_component:
		movement_component.strafing = !movement_component.strafing
		strafe_toggled.emit(movement_component.strafing)
	
func _on_target_cleared():
	if movement_component:
		movement_component.strafing = false

func attack(_is_special_attack : bool = false):
	current_state = state.ATTACK
	if _is_special_attack:
		big_attack_started.emit()
	else:
		attack_started.emit()
	if anim_state_tree: 
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length *.3).timeout
	attack_activated.emit()
	dash(Vector3.FORWARD,.3) ## delayed dash to move forward during attack animation
	await get_tree().create_timer(anim_length *.7).timeout
	if current_state == state.ATTACK:
		current_state = state.FREE

		
func air_attack():
	air_attack_started.emit()
	current_state = state.DYNAMIC_ACTION
	if anim_state_tree: 
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length *.5).timeout
	attack_activated.emit()
	await get_tree().create_timer(anim_length *.5).timeout
	current_state = state.FREE
	
		


func fall_check():
	## If you leave the floor, store last position.
	## When you land again, compare the distances of both location y values, if greater
	## than the hard_landing_height, then trigger a hard landing. Otherwise, 
	## clear the last_altitude variable.
	if !is_on_floor() && last_altitude == null: 
		last_altitude = global_position
	if is_on_floor() && last_altitude != null:
		var fall_distance = abs(last_altitude.y - global_position.y)
		if fall_distance > hard_landing_height:
			hard_landing()
		last_altitude = null
				
func hard_landing():
		current_state = state.STATIC_ACTION
		landed_hard.emit()
		anim_length = .4
		if anim_state_tree:
			await anim_state_tree.animation_measured
		await get_tree().create_timer(anim_length).timeout
		if current_state == state.STATIC_ACTION:
			current_state = state.FREE
	
func jump():
	if movement_component:
		movement_component.jump()

func dash(_new_direction : Vector3 = Vector3.FORWARD, _duration = .1): 
	if movement_component:
		movement_component.dash(_new_direction, _duration)
	
func dodge_or_sprint():
	if movement_component:
		movement_component.dodge_or_sprint()
		
func end_sprint():
	if movement_component:
		movement_component.end_sprint()
		
func dodge(): 
	if movement_component:
		movement_component.dodge(current_camera)
	

func start_ladder(top_or_bottom,mount_transform):
	if movement_component:
		movement_component.start_ladder(top_or_bottom, mount_transform)
	
func exit_ladder(exit_loc):
	if movement_component:
		movement_component.exit_ladder(exit_loc)

func _on_animation_measured(_new_length):
	anim_length = _new_length - .05 # offset slightly for the process frame

func _on_interact_updated(_interactable, _int_loc):
	interactable = _interactable
	interact_loc = _int_loc
	
func interact():
	## interactions are a handshake. The interactable will reply back with more
	## info or actions if needed.
	if interactable:
		interactable.activate(self,interact_loc)

func start_interact(interact_type = "GENERIC", desired_transform :Transform3D = global_transform, move_time : float = .5):
	current_state = state.STATIC_ACTION
	# After timer finishes, return to pre-dodge state
	var tween = create_tween()
	tween.tween_property(self,"global_transform", desired_transform, move_time)
	await tween.finished
	interact_started.emit(interact_type)
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length).timeout
	current_state = state.FREE



func weapon_change():
	current_state = state.DYNAMIC_ACTION
	weapon_change_started.emit()
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length *.5).timeout
	weapon_changed.emit()
	if weapon_system:
		await weapon_system.equipment_changed
	print(weapon_type)
	weapon_change_ended.emit(weapon_type)
	await get_tree().create_timer(anim_length *.5).timeout
	current_state = state.FREE
	
func _on_weapon_equipment_changed(_new_weapon:EquipmentObject):
	weapon_type = _new_weapon.equipment_info.object_type

func _on_gadget_equipment_changed(_new_gadget:EquipmentObject):
	gadget_type = _new_gadget.equipment_info.object_type

func _on_inventory_item_used(_item):
	current_item = _item

func _on_attack_combo_timeout():
	# Reset attack combo when timer expires
	# This function is called when the attack combo timer times out
	# Reset any combo-related state here
	pass
	
func gadget_change():
	current_state = state.DYNAMIC_ACTION
	gadget_change_started.emit()
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length *.5).timeout
	gadget_changed.emit()
	if gadget_system:
		await gadget_system.equipment_changed
	print(gadget_type)
	gadget_change_ended.emit(gadget_type)
	await get_tree().create_timer(anim_length *.5).timeout
	current_state = state.FREE

func item_change():
	current_state = state.DYNAMIC_ACTION
	item_change_started.emit()
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length *.5).timeout
	item_changed.emit()
	await get_tree().process_frame
	item_change_ended.emit(current_item)
	await get_tree().create_timer(anim_length *.5).timeout
	current_state = state.FREE
	
func start_guard():
	if combat_component:
		combat_component.start_guard()
	
func end_guard():
	if combat_component:
		combat_component.end_guard()

func use_gadget(): # emits to start the gadget, and runs some timers before stopping the gadget
	current_state = state.STATIC_ACTION
	gadget_started.emit()
	if anim_state_tree:
		await anim_state_tree.animation_started
	await get_tree().create_timer(anim_length  *.3).timeout
	gadget_activated.emit()
	dash(Vector3.FORWARD,.3)
	await get_tree().create_timer(anim_length  *.7).timeout
	if current_state == state.STATIC_ACTION:
		current_state = state.FREE

func use_item():
	current_state = state.DYNAMIC_ACTION
	use_item_started.emit()
	if anim_state_tree:
		await anim_state_tree.animation_measured
	await get_tree().create_timer(anim_length * .5).timeout
	item_used.emit()
	await get_tree().create_timer(anim_length * .5).timeout
	if current_state == state.DYNAMIC_ACTION:
		current_state = state.FREE

func hit(_who, _by_what: EquipmentResource):
	if combat_component:
		combat_component.hit(_who, _by_what)

func heal(_by_what):
	health_received.emit(_by_what)

func block():
	if combat_component:
		combat_component.block()

func parry():
	if combat_component:
		combat_component.parry()

func hurt():
	if combat_component:
		combat_component.hurt()

func death():
	if combat_component:
		combat_component.death()
	else:
		# Fallback if component missing
		current_state = state.STATIC_ACTION
		is_dead = true
		death_started.emit()
		await get_tree().create_timer(3).timeout
		get_tree().reload_current_scene()

# Character system integration functions
func load_character_data_from_file():
	var character_file_path = "user://current_character.json"
	if FileAccess.file_exists(character_file_path):
		var file = FileAccess.open(character_file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var char_info = json.data
				load_character_data(char_info)
			else:
				print("Error parsing character data")

func load_character_data(char_info: Dictionary):
	character_data = char_info
	
	# Apply character data
	if character_data.has("health"):
		if health_system and health_system.has_method("set_health"):
			health_system.set_health(character_data.health)
	
	# Apply gender-specific material
	if character_data.has("material_path"):
		apply_character_material(character_data.material_path)
	
	# Give starting weapons
	if character_data.has("weapons"):
		for weapon in character_data.weapons:
			give_weapon(weapon)

func apply_character_material(material_path: String):
	if not ResourceLoader.exists(material_path):
		print("Material not found: " + material_path)
		return
	
	var material = load(material_path)
	if not material:
		print("Failed to load material: " + material_path)
		return
	
	# Find the character mesh and apply material
	var character_mesh = %GeneralSkeleton if has_node("%GeneralSkeleton") else find_child("GeneralSkeleton", true, false)
	if character_mesh:
		# Apply material to all mesh instances in the skeleton
		apply_material_to_children(character_mesh, material)
	else:
		print("Character skeleton not found")

func apply_material_to_children(node: Node, material: Material):
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = material
		elif child.get_child_count() > 0:
			apply_material_to_children(child, material)

func set_admin_status(is_admin_enabled: bool):
	if is_admin_enabled:
		print("Admin privileges granted")
	else:
		print("Admin privileges revoked")
		if fly_component and fly_component.active:
			fly_component.disable()

func toggle_fly_mode():
	if fly_component:
		fly_component.toggle()

var shift_locked: bool = false

func toggle_admin_panel():
	# Toggle admin panel during gameplay
	print("Admin panel toggle called")
	var existing_panel = get_tree().get_nodes_in_group("admin_panel")
	
	if existing_panel.size() > 0:
		# Close existing admin panel
		print("Closing existing admin panel")
		existing_panel[0].queue_free()
	else:
		# Open new admin panel
		print("Opening new admin panel")
		var admin_panel = preload("res://ui/admin_panel.tscn").instantiate()
		if admin_panel:
			admin_panel.add_to_group("admin_panel")
			get_tree().current_scene.add_child(admin_panel)
			print("Admin panel added to scene")
		else:
			print("ERROR: Failed to instantiate admin panel")

func toggle_shift_lock():
	# Toggle mouse lock state
	shift_locked = !shift_locked
	
	if shift_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("Mouse unlocked for UI")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("Mouse captured for gameplay")

# Admin functionality
func give_weapon(new_weapon_type: String):
	if not weapon_system:
		print("No weapon system available")
		return
		
	match new_weapon_type:
		"axe":
			# Create and add axe to weapon system
			var axe_scene = preload("res://player/equipment_system/equipment/Ax.tscn")
			var axe_instance = axe_scene.instantiate()
			weapon_system.held_mount_point.add_child(axe_instance)
			print("Axe added to inventory")
		"sword":
			var sword_scene = preload("res://player/equipment_system/equipment/sword.tscn")
			var sword_instance = sword_scene.instantiate()
			weapon_system.held_mount_point.add_child(sword_instance)
			print("Sword added to inventory")
		"shield":
			var shield_scene = preload("res://player/equipment_system/equipment/shield.tscn")
			var shield_instance = shield_scene.instantiate()
			gadget_system.held_mount_point.add_child(shield_instance)
			print("Shield added to inventory")
