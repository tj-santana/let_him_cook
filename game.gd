extends Node

@export var mob_scene: PackedScene
@export var hunger_drain_rate = 4.0
@export var hit_health_damage = 10.0
@export var hit_max_health_damage = 5.0
@export var min_max_health = 25.0

var score
var ingredients
var health = 100.0
var max_health = 100.0
var hunger = 100.0
var max_hunger = 100.0
var is_game_over = false
var is_playing = false


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_game_over:
		return

	if is_playing and hunger > 0:
		hunger -= hunger_drain_rate * delta
		hunger = max(hunger, 0.0)
		$HUD.update_hunger(hunger, max_hunger)

	if hunger <= 0 or health <= 0:
		game_over()


func game_over():
	if is_game_over:
		return

	is_game_over = true
	is_playing = false
	$Player.is_playing = false
	$ScoreTimer.stop()
	$MobTimer.stop()
	$Player.die()
	$HUD.show_game_over()
	get_tree().call_group("mobs", "queue_free")

func new_game():
	is_game_over = false
	score = 0
	ingredients = 0
	max_health = 100.0
	health = max_health
	hunger = max_hunger
	$HUD.update_score(score)
	$HUD.update_ingredients(ingredients)
	$HUD.update_health(health, max_health)
	$HUD.update_hunger(hunger, max_hunger)
	$HUD.show_message("Get ready to cook")
	$Player.start($StartPosition.position)
	$StartTimer.start()

func _on_mob_timer_timeout():
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()

	# Choose a random location on Path2D.
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()

	# Set the mob's position to the random location.
	mob.position = mob_spawn_location.position

	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2

	# Add some randomness to the direction.
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction

	# Choose the velocity for the mob.
	var velocity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)
	mob.defeated.connect(_on_mob_defeated)

func _on_score_timer_timeout():
	score += 1
	$HUD.update_score(score)

func _on_mob_defeated():
	ingredients += 1
	$HUD.update_ingredients(ingredients)
	hunger += 5.0
	hunger = min(hunger, max_hunger)
	$HUD.update_hunger(hunger, max_hunger)

func _on_player_hit():
	if is_game_over:
		return

	max_health = max(max_health - hit_max_health_damage, min_max_health)
	if health != 100.0:
		health = min(health, max_health)
	health = max(health - hit_health_damage, 0.0)
	$HUD.update_health(health, max_health)
	if health <= 0:
		game_over()

func _on_start_timer_timeout():
	$MobTimer.start()
	$ScoreTimer.start()
	is_playing = true
	$Player.is_playing = true
