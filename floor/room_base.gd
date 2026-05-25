extends Node2D

@export var room_id: String = ""
@export var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1024, 768))

# Return the bounds in global coordinates
func get_bounds_rect() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)

# Return a global position for a named entry marker (Marker2D child)
func get_entry_position(marker_name: String) -> Vector2:
	if has_node(marker_name):
		return get_node(marker_name).global_position

	for child in get_children():
		if child is Node2D and (child.name == marker_name or child.name.ends_with("#" + marker_name) or child.name.ends_with(marker_name)):
			return child.global_position

	var found := find_child(marker_name, true, false)
	if found is Node2D:
		return found.global_position
	# fallback to room origin
	return global_position

# Snapshot hooks (optional for each room to implement state save/restore)
func get_snapshot() -> Dictionary:
	return {}

func apply_snapshot(snapshot: Dictionary) -> void:
	pass

func on_enter(from_room: String, entry_marker: String) -> void:
	# override in specific rooms if needed
	pass

func on_exit() -> void:
	pass
