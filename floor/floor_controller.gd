extends Node

var rooms_container: Node2D
var overlay_rect: ColorRect
var current_room: Node = null
var snapshots := {}
var transitioning = false

func _ready():
	rooms_container = Node2D.new()
	rooms_container.name = "Rooms"
	add_child(rooms_container)

	# create a fade overlay
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	overlay_rect = ColorRect.new()
	overlay_rect.color = Color(0,0,0,0)
	overlay_rect.name = "FadeOverlay"
	overlay_rect.anchor_left = 0
	overlay_rect.anchor_top = 0
	overlay_rect.anchor_right = 1
	overlay_rect.anchor_bottom = 1
	layer.add_child(overlay_rect)

func _fade_in(time := 0.25) -> void:
	overlay_rect.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(overlay_rect, "modulate:a", 1.0, time)
	await tw.finished

func _fade_out(time := 0.25) -> void:
	var tw = create_tween()
	tw.tween_property(overlay_rect, "modulate:a", 0.0, time)
	await tw.finished

func enter_room(scene_path: String, entry_marker: String = "") -> void:
	if transitioning:
		return
	transitioning = true
	await _fade_in()

	# save snapshot of current room
	if current_room != null:
		if current_room.has_method("get_snapshot"):
			snapshots[current_room.room_id] = current_room.get_snapshot()
		current_room.queue_free()

	# load new room
	var ps = ResourceLoader.load(scene_path)
	if not ps:
		print("[FloorController] Failed to load room:", scene_path)
		await _fade_out()
		transitioning = false
		return
	var room = ps.instantiate()
	rooms_container.add_child(room)
	current_room = room

	# place player at entry marker
	var game_node = get_parent()
	if game_node and game_node.has_node("Player"):
		var player = game_node.get_node("Player")
		if room.is_safe_room:
			game_node.in_safe_room = true
		else:
			game_node.in_safe_room = false
		if room.has_method("get_entry_position") and entry_marker != "":
			var pos = room.get_entry_position(entry_marker)
			player.global_position = pos

		# set camera limits if player has Camera2D child
		if player and player.has_node("Camera2D"):
			var cam = player.get_node("Camera2D")
			if cam:
				if room.has_method("get_bounds_rect"):
					cam.position = player.global_position
					var b = room.get_bounds_rect()
					cam.limit_left = int(b.position.x)
					cam.limit_top = int(b.position.y)
					cam.limit_right = int(b.position.x + b.size.x)
					cam.limit_bottom = int(b.position.y + b.size.y)

	# apply saved snapshot if exists
	if snapshots.has(room.room_id) and room.has_method("apply_snapshot"):
		room.apply_snapshot(snapshots[room.room_id])

	# notify room
	if room.has_method("on_enter"):
		room.on_enter("", entry_marker)

	await _fade_out()
	transitioning = false
