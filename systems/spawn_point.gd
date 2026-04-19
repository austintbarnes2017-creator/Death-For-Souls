extends Marker3D
class_name SpawnPoint

## A simple marker used by NetworkManager to identify player spawn locations.
## It automatically registers itself into a 'spawn_points' group for easy lookup.

func _ready() -> void:
    add_to_group("spawn_points")
