extends CharacterBody2D

signal defeated(drop_type: String)

@export var damage_amount = 5.0
@export var drop_type: String = "Slime"
@export var speed: float = 60.0
@export var chase_speed: float = 90.0
@export var detection_radius: float = 140.0
@export var attack_range: float = 15.0
@export var attack_cooldown: float = 1.2
@export var health: float = 5.0

var _player = null
var _state: String = "idle" 
var _attack_ready: bool = true

func _resolve_player() -> Node:
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.has_node("Player"):
			return current_parent.get_node("Player")
		current_parent = current_parent.get_parent()
	return null

func _ready():
	z_index = 1
	$AnimatedSprite2D.play("walk")
	$HealthBar.value = health
	$HealthBar.max_value = health
	_player = _resolve_player()

func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = _resolve_player()
		return

	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	match _state:
		"idle":
			velocity = Vector2.ZERO
			if dist <= detection_radius:
				_state = "chase"
		"chase":
			if dist > detection_radius * 1.5:
				_state = "idle"
				velocity = Vector2.ZERO
			else:
				velocity = to_player.normalized() * chase_speed
				
				if to_player.x != 0:
					$AnimatedSprite2D.flip_h = to_player.x < 0
				
				if dist <= attack_range and _attack_ready:
					_attack_ready = false
					damage_player()
					_start_attack_cooldown()
					
	move_and_slide()

func _start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	_attack_ready = true

func take_hit(attack_dmg):
	health -= attack_dmg
	$HealthBar.value = health
	if health <= 0:
		defeated.emit(drop_type)
		queue_free()

func damage_player():
	if get_parent() and get_parent().has_method("take_damage_from_enemy"):
		get_parent().call_deferred("take_damage_from_enemy", damage_amount)

func get_snapshot() -> Dictionary:
	return {
		"scene_file_path": scene_file_path,
		"position": global_position,
		"health": health,
		"state": _state,
		"attack_ready": _attack_ready,
		"flip_h": $AnimatedSprite2D.flip_h,
		"drop_type": drop_type
	}

func apply_snapshot(snapshot: Dictionary) -> void:
	global_position = snapshot.get("position", global_position)
	health = float(snapshot.get("health", health))
	_state = str(snapshot.get("state", _state))
	_attack_ready = bool(snapshot.get("attack_ready", _attack_ready))
	drop_type = str(snapshot.get("drop_type", drop_type))
	$HealthBar.value = health
	$HealthBar.max_value = max($HealthBar.max_value, health)
	if snapshot.has("flip_h"):
		$AnimatedSprite2D.flip_h = bool(snapshot.get("flip_h", false))
