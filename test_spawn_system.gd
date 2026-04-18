extends SceneTree

func _init():
	# Test the spawn system
	print("Testing spawn system...")
	
	# Load the world castle scene
	var world_scene = load("res://demo_level/world_castle.tscn")
	if world_scene:
		print("✓ World castle scene loaded successfully")
		
		# Instance the scene
		var world_instance = world_scene.instantiate()
		
		# Check if SpawnManager exists
		var spawn_manager = world_instance.get_node("SpawnManager")
		if spawn_manager:
			print("✓ SpawnManager found in scene")
			
			# Check spawn points
			if spawn_manager.starter_area_spawn:
				print("✓ Starter area spawn path set: ", spawn_manager.starter_area_spawn)
			else:
				print("✗ Starter area spawn path not set")
				
			if spawn_manager.city_area_spawn:
				print("✓ City area spawn path set: ", spawn_manager.city_area_spawn)
			else:
				print("✗ City area spawn path not set")
		else:
			print("✗ SpawnManager not found in scene")
	else:
		print("✗ Failed to load world castle scene")
	
	# Check if spawn manager script exists
	var spawn_script = load("res://demo_level/spawn_manager.gd")
	if spawn_script:
		print("✓ SpawnManager script exists")
	else:
		print("✗ SpawnManager script not found")
	
	print("Spawn system test complete!")
	quit()
