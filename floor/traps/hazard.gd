extends Area2D

@export var damage_amount: float = 10.0
@export var one_shot: bool = false
@export var reset_player_to_start: bool = false
@export var reset_cooldown: float = 0.8
@export var pitfall_freeze_duration: float = 0.35
@export var hazard_name: String = "hazard"

var _triggered := false

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 8
	if collision_mask == 0:
		collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if not reset_player_to_start:
		return
	for body in get_overlapping_bodies():
		_try_trigger(body)


func _on_body_entered(body: Node) -> void:
	_try_trigger(body)


func _try_trigger(body: Node) -> void:
	if _triggered and one_shot:
		return
	if body == null or not body.has_method("apply_damage"):
		return
	if "is_in_pitfall_sequence" in body and body.is_in_pitfall_sequence:
		return
	if "is_dashing" in body and body.is_dashing:
		return
	if not body.can_take_hit:
		return

	_triggered = true
	if reset_player_to_start and body.has_method("apply_nonlethal_damage"):
		body.apply_nonlethal_damage(damage_amount)
	else:
		body.apply_damage(damage_amount)
	if reset_player_to_start:
		var room_root := get_parent()
		if room_root != null:
			var start_position = room_root.get_entry_position("StartPosition")
			if start_position != Vector2.INF:
				if body.has_method("begin_pitfall_sequence"):
					await body.begin_pitfall_sequence(start_position, pitfall_freeze_duration)
				else:
					body.global_position = start_position
					if "velocity" in body:
						body.velocity = Vector2.ZERO
	if one_shot:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		if has_node("CollisionPolygon2D"):
			$CollisionPolygon2D.set_deferred("disabled", true)
		queue_free()
