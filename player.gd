extends Area2D
signal hit

@export var speed = 400 # How fast the player will move (pixels/sec).
@export var max_health = 100.0
@export var attack_range = 70.0
@export var attack_offset = 42.0
@export var attack_cooldown = 0.25
@export var dash_speed = 1100.0
@export var dash_duration = 0.16
@export var dash_cooldown = 0.7
@export var hit_invulnerability = 0.6
@export var debug_attack_preview = true
@export var is_playing = false

var can_attack = true
var can_dash = true
var can_take_hit = true
var is_dashing = false
var dash_time_left = 0.0
var current_health = 100.0
var show_attack_preview = false
var facing = Vector2.RIGHT
var screen_size # Size of the game window.

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = get_viewport_rect().size
	hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not is_playing:
		return
	var velocity = Vector2.ZERO # The player's movement vector.
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1

	if velocity.length() > 0:
		facing = velocity.normalized()

	if Input.is_action_just_pressed("attack"):
		attack()

	if Input.is_action_just_pressed("dash"):
		dash()

	if is_dashing:
		position += facing * dash_speed * delta
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		if velocity.length() > 0:
			velocity = velocity.normalized() * speed
			$AnimatedSprite2D.play()
		else:
			$AnimatedSprite2D.stop()
			
		position += velocity * delta
		
	position = position.clamp(Vector2.ZERO, screen_size)

	if debug_attack_preview and show_attack_preview:
		queue_redraw()
	
	if velocity.x != 0:
		$AnimatedSprite2D.animation = "walk"
		$AnimatedSprite2D.flip_v = false
		# See the note below about the following boolean assignment.
		$AnimatedSprite2D.flip_h = velocity.x < 0
	elif velocity.y != 0:
		$AnimatedSprite2D.animation = "up"
		$AnimatedSprite2D.flip_v = velocity.y > 0

func attack():
	if not can_attack:
		return

	can_attack = false
	show_attack_preview = true
	queue_redraw()
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + facing.normalized() * attack_offset)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	var hits = get_world_2d().direct_space_state.intersect_shape(query, 8)
	for hit in hits:
		var body = hit["collider"]
		if body != null and body.has_method("take_hit"):
			body.take_hit()

	await get_tree().create_timer(attack_cooldown).timeout
	show_attack_preview = false
	queue_redraw()
	can_attack = true

func dash():
	if not can_dash:
		return

	can_dash = false
	is_dashing = true
	dash_time_left = dash_duration
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func _on_body_entered(_body):
	if is_dashing or not can_take_hit:
		return

	can_take_hit = false
	hit.emit()
	await get_tree().create_timer(hit_invulnerability).timeout
	if visible:
		can_take_hit = true
	
func start(pos):
	position = pos
	show()
	current_health = max_health
	can_take_hit = true
	$CollisionShape2D.disabled = false	

func die():
	hide()
	can_take_hit = false
	# Must be deferred as we can't change physics properties on a physics callback.
	$CollisionShape2D.set_deferred("disabled", true)

func _draw():
	if debug_attack_preview and show_attack_preview:
		var center = facing.normalized() * attack_offset
		draw_circle(center, attack_range, Color(1.0, 0.2, 0.2, 0.2))
