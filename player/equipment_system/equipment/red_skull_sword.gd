extends Node3D
class_name RedSkullSword

## Red Glowing Big Skull Sword - Death Plus exclusive weapon
## One shots everyone in the area when equipped

var is_equipped: bool = false
var damage: float = 999.0
var area_radius: float = 50.0

signal weapon_equipped()
signal weapon_unequipped()

func _ready():
	# Add to death plus weapon group for easy access
	add_to_group("death_plus_weapon")
	print("Red Glowing Big Skull Sword created")

func equip_weapon(player_node: Node3D):
	if is_equipped:
		return
	
	is_equipped = true
	
	# Parent to player's hand or appropriate attachment point
	var parent = get_parent()
	if parent:
		reparent(player_node)
	
	# Activate the weapon effect
	activate_death_plus_effect()
	
	weapon_equipped.emit()
	print("Red Glowing Big Skull Sword equipped!")

func unequip_weapon():
	if not is_equipped:
		return
	
	is_equipped = false
	weapon_unequipped.emit()
	print("Red Glowing Big Skull Sword unequipped")

func activate_death_plus_effect():
	# One shot everyone in the area
	print("ACTIVATING DEATH PLUS - ONE SHOT AREA EFFECT!")
	
	# Find all enemies in the area
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.create(
		SphereShape3D.new().radius, 
		global_transform, 
		32  # collision mask for enemies
	)
	
	var results = space_state.intersect_shape(query)
	
	# Deal massive damage to all enemies in area
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
			print("Death Plus hit: ", collider.name)
	
	# Create visual effect
	create_death_effect()

func create_death_effect():
	# Create a red explosion effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(3, 3, 3), 0.5)
	tween.tween_callback(func(): 
		# Reset scale after effect
		scale = Vector3(1, 1, 1)
	)
