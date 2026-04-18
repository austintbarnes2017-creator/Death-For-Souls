extends Node

# Global character and game state management
var current_character: Dictionary = {}
var is_admin: bool = false
var admin_permissions: Dictionary = {}

signal character_data_loaded
signal admin_status_changed

func _ready():
	# Check if player has admin privileges
	check_admin_status()

func check_admin_status():
	# Simple admin check - in a real game this would be server-side
	var admin_file = FileAccess.open("user://admin.json", FileAccess.READ)
	if admin_file:
		var json_string = admin_file.get_as_text()
		admin_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var admin_data = json.data
			is_admin = admin_data.get("is_admin", false)
			admin_permissions = admin_data.get("permissions", {})
	
	admin_status_changed.emit()

func set_character_data(character_info: Dictionary):
	current_character = character_info
	character_data_loaded.emit()

func get_character_stat(stat_name: String) -> Variant:
	return current_character.get(stat_name, null)

func update_character_stat(stat_name: String, value: Variant):
	current_character[stat_name] = value
	save_character_data()

func save_character_data():
	var save_path = "user://current_character.json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(current_character)
		file.store_string(json_string)
		file.close()

func grant_admin_permissions(permissions: Dictionary):
	is_admin = true
	admin_permissions = permissions
	
	# Save admin status
	var admin_file = FileAccess.open("user://admin.json", FileAccess.WRITE)
	if admin_file:
		var admin_data = {
			"is_admin": true,
			"permissions": permissions
		}
		var json_string = JSON.stringify(admin_data)
		admin_file.store_string(json_string)
		admin_file.close()
	
	admin_status_changed.emit()

func revoke_admin_permissions():
	is_admin = false
	admin_permissions = {}
	
	# Remove admin file
	var admin_file_path = "user://admin.json"
	if FileAccess.file_exists(admin_file_path):
		DirAccess.remove_absolute(admin_file_path)
	
	admin_status_changed.emit()
