extends Node3D
class_name RedSkullSword

## Red Glowing Big Skull Sword - Death Plus exclusive weapon
## Standard sword that one shots enemies

@export var damage: float = 999.0
@export var swing_speed: float = 1.5
@export var equipped: bool = false

var is_swinging: bool = false
var player_node: Node3D
var equipment_system: EquipmentSystem

signal weapon_equipped()
signal weapon_unequipped()

func _ready():
	# Add to death plus weapon group for easy access
	add_to_group("death_plus_weapon")
	add_to_group("Targets")  # For equipment system detection
	
	# Start on back if we have a parent equipment system
	var parent = get_parent()
	if parent and parent.get("stored_mount_point"):
		reparent(parent.stored_mount_point)
		transform = Transform3D.IDENTITY
	
	print("Red Glowing Big Skull Sword created")

func _on_area_entered(body):
	if not equipped or not is_swinging:
		return
	
	# Deal massive damage to enemies
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Death Plus hit: ", body.name, " for ", damage, " damage!")
	elif body.has_method("hit"):
		body.hit(player_node, self)
		print("Death Plus hit: ", body.name)

func equip_weapon(player: Node3D):
	if equipped:
		return
	
	player_node = player
	equipped = true
	
	# Find equipment system
	equipment_system = player.get_node_or_null("EquipmentSystem")
	
	# Move sword from back to hand
	if equipment_system and equipment_system.stored_mount_point:
		reparent(equipment_system.stored_mount_point)
		transform = Transform3D.IDENTITY
		
		# Animate to hand
		var tween = create_tween()
		tween.tween_method(_move_to_hand, 0.5)
		tween.tween_callback(_on_equipment_complete)

func _move_to_hand(progress: float):
	if equipment_system and equipment_system.held_mount_point:
		var start_pos = equipment_system.stored_mount_point.global_position
		var end_pos = equipment_system.held_mount_point.global_position
		global_position = start_pos.lerp(end_pos, progress)

func _on_equipment_complete():
	# Final positioning in hand
	if equipment_system and equipment_system.held_mount_point:
		reparent(equipment_system.held_mount_point)
		transform = Transform3D.IDENTITY
	
	# Connect area signals
	if $Area3D:
		$Area3D.body_entered.connect(_on_area_entered)
	
	weapon_equipped.emit()
	print("Red Glowing Big Skull Sword equipped!")

func unequip_weapon():
	if not equipped:
		return
	
	equipped = false
	is_swinging = false
	
	# Disconnect area signals
	if $Area3D and $Area3D.is_connected("body_entered", _on_area_entered):
		$Area3D.body_entered.disconnect(_on_area_entered)
	
	# Move back to storage
	if equipment_system and equipment_system.stored_mount_point:
		reparent(equipment_system.stored_mount_point)
		transform = Transform3D.IDENTITY
	
	weapon_unequipped.emit()
	print("Red Glowing Big Skull Sword unequipped")

func start_swing():
	if not equipped or is_swinging:
		return
	
	is_swinging = true
	print("Starting Death Plus sword swing!")
	
	# Enable collision during swing
	if $Area3D:
		$Area3D.monitoring = true
	
	# Create swing animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Swing rotation
	tween.tween_property(self, "rotation_degrees:z", -90, swing_speed * 0.3)
	tween.tween_property(self, "rotation_degrees:z", 90, swing_speed * 0.4).set_delay(swing_speed * 0.3)
	tween.tween_property(self, "rotation_degrees:z", 0, swing_speed * 0.3).set_delay(swing_speed * 0.7)
	
	# Scale effect for impact
	tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), swing_speed * 0.1).set_delay(swing_speed * 0.5)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), swing_speed * 0.1).set_delay(swing_speed * 0.6)
	
	# End swing
	tween.tween_callback(_on_swing_complete).set_delay(swing_speed)

func _on_swing_complete():
	is_swinging = false
	
	# Disable collision after swing
	if $Area3D:
		$Area3D.monitoring = false
	
	print("Death Plus sword swing complete!")

func get_equipment_info():
	return {
		"name": "Red Glowing Big Skull Sword",
		"damage": damage,
		"type": "Death Plus Weapon"
	}
