extends Area2D

@export var item_name: String = "Moss"
@export var amount: int = 1
@export var item_texture: Texture2D
@export var unique_id: String = ""

var _player_nearby: bool = false

func _ready() -> void:
	if GameManager.collected_items.has(unique_id):
		queue_free()
	# If the designer sets a custom texture in the editor, apply it
	if item_texture != null and has_node("Sprite2D"):
		$Sprite2D.texture = item_texture
		
	# Add a premium feel: A smooth, continuous floating animation
	
	# Connect the collision signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_nearby = true
		# Optional: You could show a small "Press E to pick up" label here

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_nearby = false
		# Optional: Hide the label here

func _unhandled_input(event: InputEvent) -> void:
	# Check if the player is near and pressed the interact key
	# Replace "ui_accept" with "interact" if you made a custom key mapping in Project Settings
	if _player_nearby and event.is_action_pressed("interact"): 
		get_viewport().set_input_as_handled()
		_pick_up()

func _pick_up() -> void:
	var game = get_tree().current_scene
	if game and game.has_method("collect_item"):
		if unique_id != "":
			GameManager.mark_item_collected(unique_id)
		game.collect_item(item_name, amount)
		print("Picked up: %s x%d" % [item_name, amount])
			
		queue_free()


func get_snapshot() -> Dictionary:
	return {
		"item_name": item_name,
		"amount": amount,
		"position": global_position,
		"item_texture": item_texture
	}

func apply_snapshot(snapshot: Dictionary) -> void:
	# Avoid moving the item around instantly if it handles a float tween offset
	var saved_pos = snapshot.get("position", global_position)
	if global_position.distance_to(saved_pos) > 5.0:
		global_position = saved_pos
	item_name = str(snapshot.get("item_name", item_name))
	amount = int(snapshot.get("amount", amount))
