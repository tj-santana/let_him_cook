extends Node2D

@export var room_id: String = ""
@export var is_safe_room: bool = false
@export var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1024, 768))

func _rect_from_points(points: PackedVector2Array, transform: Transform2D) -> Rect2:
	if points.is_empty():
		return Rect2()

	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for point in points:
		var global_point = transform * point
		min_x = min(min_x, global_point.x)
		min_y = min(min_y, global_point.y)
		max_x = max(max_x, global_point.x)
		max_y = max(max_y, global_point.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _merge_rect(target: Dictionary, rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		return

	if not target.get("found", false):
		target["rect"] = rect
		target["found"] = true
		return

	var current: Rect2 = target["rect"]
	var min_x = min(current.position.x, rect.position.x)
	var min_y = min(current.position.y, rect.position.y)
	var max_x = max(current.position.x + current.size.x, rect.position.x + rect.size.x)
	var max_y = max(current.position.y + current.size.y, rect.position.y + rect.size.y)
	target["rect"] = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _collect_content_bounds(node: Node, target: Dictionary) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			var used_rect = child.get_used_rect()
			if used_rect.size != Vector2i.ZERO:
				var tile_size = Vector2(16.0, 16.0)
				var local_rect = Rect2(
					Vector2(used_rect.position.x * tile_size.x, used_rect.position.y * tile_size.y),
					Vector2(used_rect.size.x * tile_size.x, used_rect.size.y * tile_size.y)
				)
				var points = PackedVector2Array([
					local_rect.position,
					local_rect.position + Vector2(local_rect.size.x, 0.0),
					local_rect.position + local_rect.size,
					local_rect.position + Vector2(0.0, local_rect.size.y)
				])
				_merge_rect(target, _rect_from_points(points, child.global_transform))

		elif child is Polygon2D:
			_merge_rect(target, _rect_from_points(child.polygon, child.global_transform))

		elif child is CollisionShape2D:
			var shape = child.shape
			if shape is RectangleShape2D:
				var rect_shape: RectangleShape2D = shape
				var half_size = rect_shape.size * 0.5
				var points = PackedVector2Array([
					Vector2(-half_size.x, -half_size.y),
					Vector2(half_size.x, -half_size.y),
					Vector2(half_size.x, half_size.y),
					Vector2(-half_size.x, half_size.y)
				])
				_merge_rect(target, _rect_from_points(points, child.global_transform))

		elif child is Node:
			_collect_content_bounds(child, target)


# Return the bounds in global coordinates
func get_bounds_rect() -> Rect2:
	var exported_bounds = Rect2(global_position + bounds.position, bounds.size)
	var content_bounds := {"rect": Rect2(), "found": false}
	_collect_content_bounds(self, content_bounds)

	if content_bounds.get("found", false):
		return content_bounds["rect"]

	return exported_bounds

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


func _collect_marker_positions(node: Node, marker_prefix: String, positions: Array) -> void:
	for child in node.get_children():
		if child is Marker2D and child.name.begins_with(marker_prefix):
			positions.append(child.global_position)
		if child is Node:
			_collect_marker_positions(child, marker_prefix, positions)


func get_spawn_positions(marker_prefix: String = "MobSpawn") -> Array:
	var positions: Array = []
	_collect_marker_positions(self, marker_prefix, positions)
	return positions


func _collect_mob_snapshots(node: Node, snapshots: Array) -> void:
	for child in node.get_children():
		if child.is_in_group("mobs") and child.has_method("get_snapshot"):
			var mob_snapshot = child.get_snapshot()
			if mob_snapshot is Dictionary:
				snapshots.append(mob_snapshot)
		if child is Node:
			_collect_mob_snapshots(child, snapshots)


func get_snapshot() -> Dictionary:
	var mob_snapshots: Array = []
	_collect_mob_snapshots(self, mob_snapshots)
	return {
		"mob_count": mob_snapshots.size(),
		"mobs": mob_snapshots
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.has_method("_restore_room_snapshot"):
			current_parent.call_deferred("_restore_room_snapshot", self, snapshot)
			return
		current_parent = current_parent.get_parent()


func take_damage_from_enemy(damage_amount: float) -> void:
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.has_method("take_damage_from_enemy"):
			current_parent.call_deferred("take_damage_from_enemy", damage_amount)
			return
		current_parent = current_parent.get_parent()

func on_enter(from_room: String, entry_marker: String) -> void:
	# override in specific rooms if needed
	pass

func on_exit() -> void:
	pass
