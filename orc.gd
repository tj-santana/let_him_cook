extends CharacterBody2D

signal defeated(drop_type: String)

# Boss base stats
@export var damage_amount = 20.0
@export var drop_type: String = "Orc Meat, Orc Meat, Orc Meat, Bones, Bones"
@export var speed: float = 60.0
@export var chase_speed: float = 100.0
@export var detection_radius: float = 320.0
@export var attack_range: float = 35.0
@export var attack_cooldown: float = 1.2
@export var health: float = 200.0

var _player = null
var _state: String = "idle" # "idle", "chase", "melee_attack", "charge_windup", "charge_dash", "charge_stun", "ground_slam"
var _attack_ready: bool = true

# Boss specific states & timers
var _special_ready: bool = true
var _special_cooldown: float = 4.0
var _is_raging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_timer: float = 0.0
var _windup_timer: float = 0.0
var _stun_timer: float = 0.0
var _slam_timer: float = 0.0
var _base_modulate = Color.WHITE

# Shockwave projectile script (compiled dynamically at runtime)
var _shockwave_script: GDScript

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
	
	# Scale Orc Boss aesthetics!
	$AnimatedSprite2D.scale = Vector2(7.0, 7.0)
	if $CollisionShape2D.shape:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius = 26.0
		$CollisionShape2D.shape.height = 54.0
		
	# Scale and style HealthBar to look like a Boss Bar!
	$HealthBar.self_modulate = Color(1.0, 0.1, 0.1, 1.0) # Red/Orange Boss Bar
	$HealthBar.size = Vector2(100.0, 12.0)
	$HealthBar.position = Vector2(-50.0, -65.0)
	
	# Compile dynamic shockwave script
	_shockwave_script = GDScript.new()
	_shockwave_script.source_code = """
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 15.0
var lifetime: float = 2.5

func _ready():
	# Set mask to hit player (layer 1)
	collision_layer = 0
	collision_mask = 1
	
	# Set up a collision shape
	var col = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 12.0
	col.shape = circ
	add_child(col)
	
	# Connect hit detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	queue_redraw()

func _draw():
	# Draw a glowing fire/shockwave circle
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.4, 0.1, 0.8)) # Main flame orange
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.7, 0.1, 0.9)) # Inner yellow core
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.2, 0.0, 0.3)) # Outer heat ring

func _on_body_entered(body):
	if body.has_method("take_damage_from_enemy"):
		body.take_damage_from_enemy(damage)
		queue_free()
"""
	_shockwave_script.reload()

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = _resolve_player()
		return

	# Handle Rage Mode Transition
	if health <= 100.0 and not _is_raging:
		_enter_rage_mode()

	var to_player = _player.global_position - global_position
	var dist = to_player.length()

	match _state:
		"idle":
			velocity = Vector2.ZERO
			if dist <= detection_radius:
				_state = "chase"
				
		"chase":
			velocity = to_player.normalized() * chase_speed
			if to_player.x != 0:
				$AnimatedSprite2D.flip_h = to_player.x < 0
			
			# Melee Attack check
			if dist <= attack_range and _attack_ready:
				_state = "melee_attack"
				_attack_ready = false
				damage_player()
				_start_attack_cooldown()
				_state = "chase"
			
			# Special Attack check
			elif _special_ready and dist > attack_range * 1.5 and dist <= detection_radius:
				# Decide which special to use
				if randf() < 0.6:
					_start_charge_windup()
				else:
					_start_ground_slam()

		"charge_windup":
			velocity = Vector2.ZERO
			_windup_timer -= delta
			
			# Telegraph: Rapidly flash red / white
			var flash_phase = int(Time.get_ticks_msec() / 50) % 2
			$AnimatedSprite2D.modulate = Color(2.5, 0.5, 0.5) if flash_phase == 0 else _base_modulate
			
			if _windup_timer <= 0.0:
				# Finish windup, begin charge!
				$AnimatedSprite2D.modulate = _base_modulate
				_state = "charge_dash"
				_charge_timer = 1.2 # Max dash duration
				_charge_direction = to_player.normalized()

		"charge_dash":
			velocity = _charge_direction * (chase_speed * 4.0)
			
			# Flip sprite according to charge direction
			if _charge_direction.x != 0:
				$AnimatedSprite2D.flip_h = _charge_direction.x < 0
				
			# Check collision with walls or targets
			var collided = move_and_slide()
			
			# Check if we hit the player or walls
			var hit_wall = false
			if collided:
				for i in range(get_slide_collision_count()):
					var collision = get_slide_collision(i)
					var collider = collision.get_collider()
					if collider == _player:
						# Hit player! Deal high damage and stop charge
						_player.call_deferred("take_damage_from_enemy", damage_amount * 1.5)
						_state = "charge_stun"
						_stun_timer = 1.5
						return
					elif collider != null and not collider.is_in_group("mobs"):
						hit_wall = true
			
			# Decrease dash timer
			_charge_timer -= delta
			if _charge_timer <= 0.0 or hit_wall:
				# Collided with wall or timed out, stun self!
				_state = "charge_stun"
				_stun_timer = 1.5
				
			return # We already called move_and_slide(), so skip the end one

		"charge_stun":
			velocity = Vector2.ZERO
			_stun_timer -= delta
			
			# Visual effect for stun: spin sprite or modulate blue/yellow
			$AnimatedSprite2D.modulate = Color(0.6, 0.8, 1.0, 1.0) # blue stun tint
			$AnimatedSprite2D.rotation += 12.0 * delta # rapid spin visual
			
			if _stun_timer <= 0.0:
				$AnimatedSprite2D.modulate = _base_modulate
				$AnimatedSprite2D.rotation = 0.0
				_state = "chase"
				_start_special_cooldown()

		"ground_slam":
			velocity = Vector2.ZERO
			_slam_timer -= delta
			
			# Shake effect
			$AnimatedSprite2D.position = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			
			if _slam_timer <= 0.0:
				$AnimatedSprite2D.position = Vector2.ZERO
				_execute_ground_slam()
				_state = "chase"
				_start_special_cooldown()

	move_and_slide()

func _enter_rage_mode() -> void:
	_is_raging = true
	_base_modulate = Color(1.4, 0.4, 0.4) # Menacing red glow
	$AnimatedSprite2D.modulate = _base_modulate
	
	# Increase size even further!
	$AnimatedSprite2D.scale = Vector2(8.5, 8.5)
	if $CollisionShape2D.shape:
		$CollisionShape2D.shape.radius = 32.0
		$CollisionShape2D.shape.height = 64.0
		
	# Buff stats!
	chase_speed = 135.0
	attack_range = 42.0
	attack_cooldown = 0.8
	_special_cooldown = 2.5

func _start_charge_windup() -> void:
	_state = "charge_windup"
	_windup_timer = 0.8
	_special_ready = false
	if $AnimatedSprite2D.sprite_frames.has_animation("attack"):
		$AnimatedSprite2D.play("attack")

func _start_ground_slam() -> void:
	_state = "ground_slam"
	_slam_timer = 0.7
	_special_ready = false
	if $AnimatedSprite2D.sprite_frames.has_animation("attack"):
		$AnimatedSprite2D.play("attack")

func _execute_ground_slam() -> void:
	# Spawn 8 shockwave projectiles in a circle!
	var num_projectiles = 8
	var base_angle = randf_range(0.0, PI / 4.0)
	for i in range(num_projectiles):
		var angle = base_angle + (i * (2.0 * PI / num_projectiles))
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_shockwave(global_position, dir)

func _spawn_shockwave(pos: Vector2, dir: Vector2) -> void:
	if _shockwave_script == null:
		return
	
	var wave = Area2D.new()
	wave.set_script(_shockwave_script)
	wave.velocity = dir * 220.0
	wave.damage = 15.0
	
	if get_parent():
		get_parent().add_child(wave)
		wave.global_position = pos + dir * 32.0

func _start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	_attack_ready = true

func _start_special_cooldown() -> void:
	await get_tree().create_timer(_special_cooldown).timeout
	_special_ready = true

func take_hit(attack_dmg):
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_enemy_hit(name)
	health -= attack_dmg
	$HealthBar.value = health
	
	# Hit flash effect
	var prev_modulate = $AnimatedSprite2D.modulate
	$AnimatedSprite2D.modulate = Color(4.0, 4.0, 4.0, 1.0) # Bright white flash
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			$AnimatedSprite2D.modulate = prev_modulate
	)
	
	if health <= 0:
		defeated.emit(drop_type)
		queue_free()

func damage_player():
	if get_parent() and get_parent().has_method("take_damage_from_enemy"):
		if $AnimatedSprite2D and $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation("attack"):
			$AnimatedSprite2D.animation = "attack"
			$AnimatedSprite2D.play()
		get_parent().call_deferred("take_damage_from_enemy", damage_amount)

func get_snapshot() -> Dictionary:
	return {
		"scene_file_path": scene_file_path,
		"position": global_position,
		"health": health,
		"state": _state,
		"attack_ready": _attack_ready,
		"flip_h": $AnimatedSprite2D.flip_h,
		"drop_type": drop_type,
		"is_raging": _is_raging
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
	if bool(snapshot.get("is_raging", false)):
		_enter_rage_mode()
