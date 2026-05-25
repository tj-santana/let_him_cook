extends Node

@export var mob_scene: PackedScene
@export var hunger_drain_rate = 3.0
@export var hit_health_damage = 10.0
@export var hit_max_health_damage = 5.0
@export var min_max_health = 25.0
@export var game_over_timer = 2.0

var score
var ingredients
var health = 100.0
var max_health = 100.0
var hunger = 100.0
var max_hunger = 100.0
var is_game_over = false
var is_playing = false
var player_inventory = {
	"Sus Meat": 0,
	"Slime": 0,
	"Essence": 0
}

# Simple wave system: list of dictionaries {count, interval}
var waves = [
	{"count": 5, "interval": 0.8},
	{"count": 8, "interval": 0.7},
	{"count": 12, "interval": 0.6}
]
var current_wave = 0
var mobs_left_to_spawn = 0
var mobs_alive = 0
var room_host: Node2D = null
var active_room_root: Node = null
var active_room_instance: Node = null
var room_transitioning = false
var transition_rect: ColorRect = null
const DEFAULT_ROOM_SCENE := "res://game.tscn"
const SHELL_SCENE := "res://game_shell.tscn"


func _refresh_inventory_hud() -> void:
	if $HUD.has_method("update_inventory"):
		$HUD.update_inventory(player_inventory)


func _ensure_room_host() -> void:
	if room_host != null and is_instance_valid(room_host):
		return
	room_host = Node2D.new()
	room_host.name = "RoomHost"
	add_child(room_host)


func _ensure_transition_overlay() -> void:
	if transition_rect != null and is_instance_valid(transition_rect):
		return
	var layer = CanvasLayer.new()
	layer.name = "TransitionLayer"
	layer.layer = 200
	add_child(layer)
	transition_rect = ColorRect.new()
	transition_rect.name = "TransitionRect"
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.anchor_left = 0
	transition_rect.anchor_top = 0
	transition_rect.anchor_right = 1
	transition_rect.anchor_bottom = 1
	layer.add_child(transition_rect)


func _set_base_room_visible(visible: bool) -> void:
	for node_name in ["Floor", "Walls", "Props", "MobPath", "StartPosition"]:
		if has_node(node_name):
			var node = get_node(node_name)
			if node is CanvasItem:
				node.visible = visible


func _get_active_room_root() -> Node:
	if active_room_instance != null and is_instance_valid(active_room_instance):
		return active_room_instance
	return self


func _collect_tilemap_layers(node: Node, layers: Array) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			layers.append(child)
		_collect_tilemap_layers(child, layers)


func _get_room_bounds_for(room_root: Node) -> Rect2:
	if room_root != null and room_root.has_method("get_bounds_rect"):
		return room_root.get_bounds_rect()

	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	var found_any = false
	var layers: Array = []
	_collect_tilemap_layers(room_root if room_root != null else self, layers)

	for layer in layers:
		if not layer.has_method("get_used_rect"):
			continue
		var used_rect = layer.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue
		var tile_size = Vector2(16.0, 16.0)
		var scale = layer.scale
		var origin = layer.global_position
		var rect_pos = origin + Vector2(used_rect.position.x * tile_size.x * scale.x, used_rect.position.y * tile_size.y * scale.y)
		var rect_size = Vector2(used_rect.size.x * tile_size.x * scale.x, used_rect.size.y * tile_size.y * scale.y)
		min_x = min(min_x, rect_pos.x)
		min_y = min(min_y, rect_pos.y)
		max_x = max(max_x, rect_pos.x + rect_size.x)
		max_y = max(max_y, rect_pos.y + rect_size.y)
		found_any = true

	if not found_any:
		return Rect2()

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _configure_player_camera() -> void:
	if not has_node("Player/Camera2D"):
		return

	var cam: Camera2D = $Player/Camera2D
	if cam.has_method("make_current"):
		cam.make_current()
	cam.position_smoothing_enabled = false

	var bounds = _get_room_bounds_for(_get_active_room_root())
	if bounds.size != Vector2.ZERO:
		cam.limit_left = int(bounds.position.x)
		cam.limit_top = int(bounds.position.y)
		cam.limit_right = int(bounds.position.x + bounds.size.x)
		cam.limit_bottom = int(bounds.position.y + bounds.size.y)


func _get_marker_global_position(room_root: Node, marker_name: String) -> Vector2:
	if room_root == null or marker_name == "":
		return Vector2.INF
	if room_root.has_method("get_entry_position"):
		return room_root.get_entry_position(marker_name)
	if room_root.has_node(marker_name):
		return room_root.get_node(marker_name).global_position
	return Vector2.INF


func _get_current_room_scene_path() -> String:
	if active_room_instance != null and is_instance_valid(active_room_instance):
		var scene_path = active_room_instance.scene_file_path
		if scene_path != "":
			return scene_path
	return DEFAULT_ROOM_SCENE


func _get_cooking_menu_scene_path() -> String:
	var caminho_novo = "res://microgames/Cenas/CozinhaPrincipal.tscn"
	if FileAccess.file_exists(caminho_novo):
		return caminho_novo
	return "res://microgames/Cenas/CozinhaPrincipal.tscn"


func _fade_to(alpha: float, duration: float = 0.16) -> void:
	_ensure_transition_overlay()
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", alpha, duration)
	await tween.finished


func enter_room(scene_path: String, entry_marker: String = "", player_position: Vector2 = Vector2.INF, show_player: bool = true, use_fade: bool = true) -> void:
	if room_transitioning:
		return
	room_transitioning = true
	if use_fade:
		await _fade_to(1.0)

	if active_room_instance != null and is_instance_valid(active_room_instance):
		active_room_instance.queue_free()
		active_room_instance = null

	if scene_path == "":
		scene_path = DEFAULT_ROOM_SCENE

	if scene_path == SHELL_SCENE:
		active_room_root = self
		_set_base_room_visible(true)
	else:
		_ensure_room_host()
		var packed_room = load(scene_path)
		if packed_room == null:
			print("[game.gd] Failed to load room:", scene_path)
			active_room_root = self
			_set_base_room_visible(true)
		else:
			var room = packed_room.instantiate()
			room_host.add_child(room)
			active_room_instance = room
			active_room_root = room
			_set_base_room_visible(false)

	var player = $Player
	var target_position = player_position
	if target_position == Vector2.INF:
		target_position = _get_marker_global_position(_get_active_room_root(), entry_marker)
	if target_position != Vector2.INF:
		player.global_position = target_position
	if show_player:
		player.show()
	else:
		player.hide()

	_configure_player_camera()
	if use_fade:
		await _fade_to(0.0)
	room_transitioning = false


# Called when the node enters the scene tree for the first time.
func _ready():
	# If there's a saved state from the cooking flow, restore it.
	if typeof(GameManager) != TYPE_NIL and GameManager.obter_estado_principal() != null:
		var s = GameManager.obter_estado_principal()
		var saved_room_scene = s.get("room_scene", DEFAULT_ROOM_SCENE)
		# Restore numeric state
		score = s.get("score", 0)
		health = s.get("health", max_health)
		max_health = s.get("max_health", max_health)
		hunger = s.get("hunger", max_hunger)
		max_hunger = s.get("max_hunger", max_hunger)
		player_inventory = s.get("player_inventory", player_inventory).duplicate()

		# Update HUD
		$HUD.update_score(score)
		$HUD.update_health(health, max_health)
		$HUD.update_hunger(hunger, max_hunger)
		_refresh_inventory_hud()

		# Apply any pending food buffs from cooking
		if typeof(GameManager) != TYPE_NIL:
			var pending = false
			if GameManager.has_method("get"):
				pending = GameManager.get("buff_pendente")
			print("[game.gd] Checking for pending buff:", pending)
			if pending:
				print("--- APPLYING FOOD BUFFS ---")
				print("[game.gd] Buff values -> vel:", GameManager.get("buff_velocidade"), ", cooldown:", GameManager.get("buff_cooldown"), ", dur:", GameManager.get("buff_duracao"))
				if $Player.has_method("aplicar_buff_comida"):
					$Player.aplicar_buff_comida(
						GameManager.get("buff_velocidade"),
						GameManager.get("buff_cooldown"),
						GameManager.get("buff_duracao")
					)
					# Recover some health and hunger from eating
					hunger = min(hunger + 10.0, max_hunger)
					health = min(health + 20.0, max_health)
					$HUD.update_hunger(hunger, max_hunger)
					$HUD.update_health(health, max_health)
			else:
				print("ERRO: O script do Jogador não tem a função aplicar_buff_comida!")
						
			# Clear the pending buff flag
			GameManager.buff_pendente = false
			print("Buffs aplicados com sucesso!")
		
		if saved_room_scene == "" or saved_room_scene == SHELL_SCENE:
			saved_room_scene = DEFAULT_ROOM_SCENE
		var saved_player_pos = s.get("player_pos", Vector2.INF)
		await enter_room(
			saved_room_scene,
			s.get("entry_marker", "StartPosition"),
			saved_player_pos,
			false,
			false
		)
		$Player.show()

		# Restart timers if the game was playing
		if s.get("is_playing", false):
			$MobTimer.start()
			$ScoreTimer.start()
			is_playing = true
			$Player.is_playing = true

		# Clear saved state
		GameManager.limpar_estado_principal()
	else:
		new_game()
		await enter_room(DEFAULT_ROOM_SCENE, "StartPosition")

	_ensure_transition_overlay()

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

	# If we returned from the cooking scene, the autoload GameManager may
	# carry an updated inventory. Merge it into our local inventory and
	# refresh the HUD once. (Assumes GameManager is autoloaded.)
	if not Engine.is_editor_hint() and typeof(GameManager) != TYPE_NIL:
		if GameManager.inventario_jogador:
			player_inventory = GameManager.inventario_jogador.duplicate()
			_refresh_inventory_hud()



func game_over():
	if is_game_over:
		return

	is_game_over = true
	is_playing = false
	$Player.is_playing = false
	$ScoreTimer.stop()
	$MobTimer.stop()
	$Player.die()
	get_tree().call_group("mobs", "queue_free")
	if typeof(GameManager) != TYPE_NIL:
		GameManager.limpar_estado_principal()
	$HUD.get_node("GameOver").show()
	await get_tree().create_timer(game_over_timer).timeout
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func new_game():
	is_game_over = false
	is_playing = false
	active_room_root = self
	if active_room_instance != null and is_instance_valid(active_room_instance):
		active_room_instance.queue_free()
		active_room_instance = null
	_set_base_room_visible(true)
	score = 0
	ingredients = 0
	max_health = 100.0
	health = max_health
	hunger = max_hunger
	player_inventory = {
		"Sus Meat": 0,
		"Slime": 0,
		"Essence": 0
	}
	$HUD.update_score(score)
	$HUD.update_health(health, max_health)
	$HUD.update_hunger(hunger, max_hunger)
	if $HUD.has_node("Message"):
		$HUD.get_node("Message").hide()
	if $HUD.has_node("StartButton"):
		$HUD.get_node("StartButton").hide()
	if $HUD.has_node("MessageTimer"):
		$HUD.get_node("MessageTimer").stop()
	$StartTimer.start()

	# initialize waves
	current_wave = 0
	mobs_left_to_spawn = 0
	mobs_alive = 0
	# prepare first wave when start timer fires

	# refresh HUD for inventory
	_refresh_inventory_hud()
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()

	_configure_player_camera()

func _on_mob_timer_timeout():
	var room_root = _get_active_room_root()
	var mob_spawn_location = null
	if room_root != null and room_root.has_node("MobPath/MobSpawnLocation"):
		mob_spawn_location = room_root.get_node("MobPath/MobSpawnLocation")

	var mob = mob_scene.instantiate()
	if mob_spawn_location != null:
		mob_spawn_location.progress_ratio = randf()
		mob.global_position = mob_spawn_location.global_position
	else:
		mob.global_position = $Player.global_position + Vector2(randf_range(-160, 160), randf_range(-160, 160))

	var screen_center = get_viewport().get_visible_rect().size / 2
	var direction_to_center = (screen_center - mob.global_position).normalized()
	
	var random_variance = randf_range(-PI / 4, PI / 4)
	direction_to_center = direction_to_center.rotated(random_variance)
	
	var base_speed = randf_range(mob.speed, mob.chase_speed)
	mob.velocity = direction_to_center * base_speed
	
	add_child(mob)

	mob.defeated.connect(_on_mob_defeated)
	mobs_alive += 1
	if mobs_left_to_spawn > 0:
		mobs_left_to_spawn -= 1
		if mobs_left_to_spawn == 0:
			# stop spawning for this wave
			$MobTimer.stop()

	# If we've spawned all and there are no mobs alive, advance wave
	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		_advance_wave()

func _on_score_timer_timeout():
	score += 1
	$HUD.update_score(score)

func _on_mob_defeated(drop_type: String = "Sus Meat"):

	# Add the dropped ingredient type to the player's inventory
	var key = drop_type if typeof(drop_type) == TYPE_STRING and drop_type != "" else "Sus Meat"
	player_inventory[key] = player_inventory.get(key, 0) + 1

	# Update the visible ingredient count (sum of all ingredient types)
	_refresh_inventory_hud()
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()

	# Small hunger refund on kill
	hunger += 5.0
	hunger = min(hunger, max_hunger)
	$HUD.update_hunger(hunger, max_hunger)

	# track alive mobs for wave progression
	mobs_alive = max(0, mobs_alive - 1)
	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		_advance_wave()

	# update GameManager inventory snapshot
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()


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
	# Start first wave
	_start_wave(current_wave)


func _start_wave(index: int) -> void:
	if index >= waves.size():
		# no more waves; optionally loop or increase difficulty
		return
	var w = waves[index]
	mobs_left_to_spawn = int(w.get("count", 5))
	$MobTimer.wait_time = float(w.get("interval", 0.8))
	$MobTimer.start()


func _advance_wave() -> void:
	current_wave += 1
	if current_wave < waves.size():
		# small delay then start next wave
		get_tree().create_timer(1.2).timeout.connect(func(): _start_wave(current_wave))
	else:
		# all waves complete -- for now, restart waves
		current_wave = 0
		get_tree().create_timer(2.0).timeout.connect(func(): _start_wave(current_wave))


func open_cooking() -> void:
	if is_game_over or room_transitioning or not is_playing:
		return

	if typeof(GameManager) != TYPE_NIL:
		GameManager.cena_principal_path = SHELL_SCENE
		GameManager.inventario_jogador = player_inventory.duplicate()
		GameManager.guardar_estado_principal({
			"score": score,
			"health": health,
			"max_health": max_health,
			"hunger": hunger,
			"max_hunger": max_hunger,
			"player_pos": $Player.global_position,
			"room_scene": _get_current_room_scene_path(),
			"is_playing": is_playing,
			"player_inventory": player_inventory.duplicate()
		})

	is_playing = false
	$MobTimer.stop()
	$ScoreTimer.stop()
	$Player.is_playing = false
	get_tree().change_scene_to_file(_get_cooking_menu_scene_path())


func _input(event):
	pass
