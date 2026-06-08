extends CharacterBody2D

signal defeated(drop_type: String)

@export var damage_amount = 8.0
@export var drop_type: String = "Mimic Eye, Mimic Eye, Mimic Tongue, Sus Meat"
@export var speed: float = 60.0
@export var chase_speed: float = 110.0
@export var detection_radius: float = 180.0
@export var attack_range: float = 24.0
@export var attack_cooldown: float = 1.0
@export var health: float = 100.0

var _player = null
var _state: String = "disguised" # "disguised", "waking", "chase", "lunge"
var _attack_ready: bool = true
var _player_nearby: bool = false

# Lunge special attack variables
var _lunge_cooldown: float = 3.0
var _lunge_ready: bool = true
var _lunge_direction: Vector2 = Vector2.ZERO
var _lunge_timer: float = 0.0

func _resolve_player() -> Node:
	var current_parent := get_parent()
	while current_parent != null:
		if current_parent.has_node("Player"):
			return current_parent.get_node("Player")
		current_parent = current_parent.get_parent()
	return null

func _ready():
	z_index = 1
	$AnimatedSprite2D.play("idle")
	$HealthBar.value = health
	$HealthBar.max_value = health
	$HealthBar.hide() # Hide health bar while disguised!
	
	_player = _resolve_player()
	
	# Connect interaction area signals
	$InteractionArea.body_entered.connect(_on_interaction_body_entered)
	$InteractionArea.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_nearby = true
		if _state == "disguised":
			check_proximity_wake()

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_nearby = false

func check_proximity_wake():
	if _player == null:
		_player = _resolve_player()
	if _player != null:
		var dist = (global_position - _player.global_position).length()
		if dist <= 38.0 and _state == "disguised":
			wake_up()

func _unhandled_input(event: InputEvent) -> void:
	if _state == "disguised" and _player_nearby and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		wake_up()

func wake_up():
	_state = "waking"
	$HealthBar.show()
	
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_creak()
		am.play_door_open()
	
	# Shake effect to telegraph waking up
	var duration = 0.6
	var elapsed = 0.0
	$AnimatedSprite2D.play("walk") # play the teeth reveal
	
	while elapsed < duration:
		$AnimatedSprite2D.position = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
		if not is_instance_valid(self):
			return
			
	$AnimatedSprite2D.position = Vector2.ZERO
	_state = "chase"

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = _resolve_player()
		return

	if _state == "disguised":
		if _player_nearby:
			check_proximity_wake()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _state == "waking":
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	match _state:
		"chase":
			velocity = to_player.normalized() * chase_speed
			
			if to_player.x != 0:
				$AnimatedSprite2D.flip_h = to_player.x < 0
			
			# Attack range check
			if dist <= attack_range and _attack_ready:
				_attack_ready = false
				damage_player(damage_amount)
				_start_attack_cooldown()
			
			# Leap/Lunge attack trigger
			elif _lunge_ready and dist <= detection_radius and dist > attack_range * 1.5:
				_start_lunge(to_player.normalized())

		"lunge":
			velocity = _lunge_direction * (chase_speed * 2.5)
			_lunge_timer -= delta
			
			# Collision checks during lunge
			var collided = move_and_slide()
			if collided:
				for i in range(get_slide_collision_count()):
					var collision = get_slide_collision(i)
					var collider = collision.get_collider()
					if collider == _player:
						# Lunge hit: deal extra damage!
						_player.call_deferred("take_damage_from_enemy", damage_amount * 1.5)
						_state = "chase"
						return
			
			if _lunge_timer <= 0.0:
				_state = "chase"
				
			return # Skip standard move_and_slide at end

	move_and_slide()

func _start_lunge(dir: Vector2):
	_state = "lunge"
	_lunge_ready = false
	_lunge_direction = dir
	_lunge_timer = 0.4 # lunge duration
	_start_lunge_cooldown()

func _start_lunge_cooldown():
	await get_tree().create_timer(_lunge_cooldown).timeout
	_lunge_ready = true

func _start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	_attack_ready = true

func take_hit(attack_dmg):
	if _state == "disguised":
		wake_up()
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_enemy_hit(name)
	health -= attack_dmg
	$HealthBar.value = health
	
	# White hit flash
	var prev_modulate = $AnimatedSprite2D.modulate
	$AnimatedSprite2D.modulate = Color(4.0, 4.0, 4.0, 1.0)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			$AnimatedSprite2D.modulate = prev_modulate
	)
	
	if health <= 0:
		defeated.emit(drop_type)
		queue_free()
		GameManager.get_key()

func damage_player(dmg: float):
	if get_parent() and get_parent().has_method("take_damage_from_enemy"):
		get_parent().call_deferred("take_damage_from_enemy", dmg)

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
		
	# If loaded while awake, make sure healthbar is visible and sprite is playing
	if _state != "disguised":
		$HealthBar.show()
		$AnimatedSprite2D.play("walk")
	else:
		$HealthBar.hide()
		$AnimatedSprite2D.play("idle")
