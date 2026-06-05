extends Node

@export var mob_scene: PackedScene
@export var hunger_drain_rate = 2.0
@export var hit_health_damage = 10.0
@export var hit_max_health_damage = 5.0
@export var min_max_health = 25.0
@export var game_over_timer = 2.0
@export var use_room_spawn_points := true
@export var require_room_clear_to_exit := true
@export var in_safe_room := false
@export var spork_hunger_drain_multiplier := 2.0
@export var near_death_drain_rate = 5.0
@export var near_death_min_health = -50.0
@export var starvation_drain_rate = 3.0
var near_death_active = false
var near_death_overlay: CanvasLayer = null

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var inventory_menu: CanvasLayer = $InventoryMenu

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
var room_snapshots: Dictionary = {}
var room_host: Node2D = null
var active_room_root: Node = null
var active_room_instance: Node = null
var room_transitioning = false
var transition_rect: ColorRect = null
var spork_mode_active := false
const DEFAULT_ROOM_SCENE := "res://rooms/floor_1/F1_Entry.tscn"
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


func _spawn_room_mobs(room_root: Node) -> void:
	if not use_room_spawn_points:
		return
	if room_root == null or room_root == self:
		return
	if mob_scene == null or not room_root.has_method("get_spawn_positions"):
		return

	var spawn_positions: Array = room_root.get_spawn_positions("MobSpawn")
	if spawn_positions.is_empty():
		return

	mobs_alive = 0
	for spawn_position in spawn_positions:
		var mob = mob_scene.instantiate()
		room_root.add_child(mob)
		mob.global_position = spawn_position
		mob.defeated.connect(_on_mob_defeated)
		mobs_alive += 1


func can_leave_current_room() -> bool:
	if not require_room_clear_to_exit:
		return true
	if is_game_over or not is_playing:
		return true
	return mobs_alive <= 0


func _notify_room_locked() -> void:
	print("[game.gd] Room is locked until all enemies are defeated.")


func _get_room_snapshot_key(scene_path: String, room_root: Node = null) -> String:
	if scene_path != "":
		return scene_path
	if room_root != null and room_root.has_method("room_id"):
		return str(room_root.room_id)
	return DEFAULT_ROOM_SCENE


func _save_active_room_snapshot() -> void:
	if active_room_instance == null or not is_instance_valid(active_room_instance):
		return
	if not active_room_instance.has_method("get_snapshot"):
		return
	var scene_path = active_room_instance.scene_file_path
	var snapshot_key = _get_room_snapshot_key(scene_path, active_room_instance)
	room_snapshots[snapshot_key] = active_room_instance.get_snapshot()
	if room_snapshots[snapshot_key] is Dictionary:
		room_snapshots[snapshot_key]["mob_count"] = int(room_snapshots[snapshot_key].get("mobs", []).size())


func _restore_room_snapshot(room_root: Node, snapshot: Dictionary) -> void:
	if room_root == null or snapshot.is_empty():
		return
	if mob_scene == null:
		return

	for child in room_root.get_children():
		if child.is_in_group("mobs"):
			child.queue_free()

	var mob_snapshots: Array = snapshot.get("mobs", [])
	if mob_snapshots.is_empty():
		return

	mobs_alive = 0
	for mob_snapshot in mob_snapshots:
		if mob_snapshot is not Dictionary:
			continue
		var mob = mob_scene.instantiate()
		room_root.add_child(mob)
		if mob.has_method("apply_snapshot"):
			mob.apply_snapshot(mob_snapshot)
		else:
			mob.global_position = mob_snapshot.get("position", mob.global_position)
		mob.defeated.connect(_on_mob_defeated)
		mobs_alive += 1


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

	if use_room_spawn_points:
		$MobTimer.stop()
		mobs_left_to_spawn = 0
	_save_active_room_snapshot()
	mobs_alive = 0

	if active_room_instance != null and is_instance_valid(active_room_instance):
		active_room_instance.queue_free()
		active_room_instance = null

	if scene_path == "":
		scene_path = DEFAULT_ROOM_SCENE

	var room = null
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
			room = packed_room.instantiate()
			room_host.add_child(room)
			active_room_instance = room
			active_room_root = room
			_set_base_room_visible(false)

	var player = $Player
	if room.is_safe_room:
		in_safe_room = true
	else:
		in_safe_room = false
	var target_position = player_position
	if target_position == Vector2.INF:
		target_position = _get_marker_global_position(_get_active_room_root(), entry_marker)
	if target_position != Vector2.INF:
		player.global_position = target_position
	if player.has_method("grant_room_entry_invulnerability"):
		player.grant_room_entry_invulnerability(0.25)
	if show_player:
		player.show()
	else:
		player.hide()

	var room_snapshot = room_snapshots.get(scene_path, null)
	if is_playing:
		if room_snapshot is Dictionary and not room_snapshot.is_empty():
			_restore_room_snapshot(active_room_root, room_snapshot)
		elif use_room_spawn_points:
			_spawn_room_mobs(active_room_root)

	_configure_player_camera()
	if use_fade:
		await _fade_to(0.0)
	room_transitioning = false


# Called when the node enters the scene tree for the first time.
func _ready():
	if pause_menu != null:
		pause_menu.hide_menu()
	if inventory_menu != null:
		inventory_menu.hide_menu()
	# If there's a saved state from the cooking flow, restore it.
	if typeof(GameManager) != TYPE_NIL and GameManager.obter_estado_principal() != null:
		var s = GameManager.obter_estado_principal()
		var saved_room_scene = s.get("room_scene", DEFAULT_ROOM_SCENE)
		spork_mode_active = bool(s.get("spork_mode_active", false))
		if $Player.has_method("set_spork_mode_active"):
			$Player.set_spork_mode_active(spork_mode_active)
		# Restore numeric state
		score = s.get("score", 0)
		health = s.get("health", max_health)
		max_health = s.get("max_health", max_health)
		hunger = s.get("hunger", max_hunger)
		max_hunger = s.get("max_hunger", max_hunger)
		near_death_active = bool(s.get("near_death_active", false))
		$Player.current_health = health
		if $Player.has_method("set_near_death_active"):
			$Player.set_near_death_active(near_death_active)
		if near_death_active:
			enter_near_death()
		player_inventory = s.get("player_inventory", player_inventory).duplicate()
		room_snapshots = s.get("room_snapshots", room_snapshots)
		if room_snapshots == null:
			room_snapshots = {}
		elif room_snapshots is Dictionary:
			room_snapshots = room_snapshots.duplicate(true)

		# Update HUD
		$HUD.update_score(score)
		$HUD.update_health(health, max_health)
		$HUD.update_hunger(hunger, max_hunger)
		_refresh_inventory_hud()

		# Food buffs are now stored in inventory and consumed manually.
		
		if saved_room_scene == "" or saved_room_scene == SHELL_SCENE:
			saved_room_scene = DEFAULT_ROOM_SCENE
		var saved_player_pos = s.get("player_pos", Vector2.INF)
		var saved_room_snapshot = room_snapshots.get(saved_room_scene, null)
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
			is_playing = true
			if use_room_spawn_points:
				if saved_room_snapshot is Dictionary and not saved_room_snapshot.is_empty():
					_restore_room_snapshot(_get_active_room_root(), saved_room_snapshot)
				else:
					_spawn_room_mobs(_get_active_room_root())
			if not use_room_spawn_points:
				$MobTimer.start()
			$ScoreTimer.start()
			$Player.is_playing = true

		# Clear saved state
		GameManager.limpar_estado_principal()
	else:
		new_game()
		await enter_room(DEFAULT_ROOM_SCENE, "StartPosition")

	_ensure_transition_overlay()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if is_game_over:
		return

	if is_playing and hunger > 0 and not in_safe_room:
		var drain_rate = hunger_drain_rate * (spork_hunger_drain_multiplier if spork_mode_active else 1.0)
		hunger -= drain_rate * delta
		hunger = max(hunger, 0.0)
		$HUD.update_hunger(hunger, max_hunger)

	if $Player.has_method("set_starving_active"):
		$Player.set_starving_active(is_playing and hunger <= 0.0)

	# Continuous HP depletion during near death
	if is_playing and near_death_active and not in_safe_room:
		health -= near_death_drain_rate * delta
		health = max(health, near_death_min_health)
		$HUD.update_health(health, max_health)
		$Player.current_health = health
		if health <= near_death_min_health:
			game_over()
			return

	# Continuous HP depletion during starvation (hunger reaches 0)
	elif is_playing and hunger <= 0.0 and not in_safe_room:
		health -= starvation_drain_rate * delta
		if health <= 0.0:
			health = 0.0
			enter_near_death()
		$HUD.update_health(health, max_health)
		$Player.current_health = health

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
	if near_death_active:
		exit_near_death()
	is_playing = false
	spork_mode_active = false
	if $Player.has_method("set_spork_mode_active"):
		$Player.set_spork_mode_active(false)
	if pause_menu != null:
		pause_menu.hide_menu()
	if inventory_menu != null:
		inventory_menu.hide_menu()
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
	spork_mode_active = false
	if $Player.has_method("set_spork_mode_active"):
		$Player.set_spork_mode_active(false)
	near_death_active = false
	if $Player.has_method("set_near_death_active"):
		$Player.set_near_death_active(false)
	if near_death_overlay != null and is_instance_valid(near_death_overlay):
		near_death_overlay.queue_free()
		near_death_overlay = null
	if pause_menu != null:
		pause_menu.hide_menu()
	if inventory_menu != null:
		inventory_menu.hide_menu()
	room_snapshots.clear()
	active_room_root = self
	if active_room_instance != null and is_instance_valid(active_room_instance):
		active_room_instance.queue_free()
		active_room_instance = null
	_set_base_room_visible(true)
	score = 0
	ingredients = 0
	max_health = 100.0
	health = max_health
	$Player.current_health = health
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
		GameManager.pratos_cozinhados.clear()

	_configure_player_camera()

func _on_mob_timer_timeout():
	if use_room_spawn_points:
		return
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
	if use_room_spawn_points:
		return
	if mobs_left_to_spawn == 0 and mobs_alive == 0:
		_advance_wave()

	# update GameManager inventory snapshot
	if typeof(GameManager) != TYPE_NIL:
		GameManager.inventario_jogador = player_inventory.duplicate()


func _on_player_hit(damage: float = hit_health_damage):
	if is_game_over:
		return

	var applied_damage = max(damage, 0.0)
	if applied_damage > 0.0:
		max_health = max(max_health - hit_max_health_damage, min_max_health)
		if health != 100.0:
			health = min(health, max_health)
		health = health - applied_damage
	
	if health <= 0.0:
		if not near_death_active:
			enter_near_death()
		if health <= near_death_min_health:
			health = near_death_min_health
			$HUD.update_health(health, max_health)
			$Player.current_health = health
			game_over()
			return

	$HUD.update_health(health, max_health)
	$Player.current_health = health


func take_damage_from_enemy(damage: float = hit_health_damage) -> void:
	_on_player_hit(damage)

func _on_start_timer_timeout():
	$ScoreTimer.start()
	is_playing = true
	$Player.is_playing = true
	if use_room_spawn_points:
		_spawn_room_mobs(_get_active_room_root())
	if not use_room_spawn_points:
		$MobTimer.start()
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


func consumir_prato(dados_do_prato: Dictionary) -> void:
	print("Consumindo prato: ", dados_do_prato["nome"])
	var vel = dados_do_prato.get("velocidade", 0)
	var cooldown = dados_do_prato.get("cooldown", 0.0)
	var dur = dados_do_prato.get("duracao", 0.0)
	var vida_rec = dados_do_prato.get("vida", 0.0)
	var max_vida_rec = dados_do_prato.get("max_vida", 0.0)
	var fome_rec = dados_do_prato.get("fome", 0.0)
	var dano_causado = dados_do_prato.get("dano_causado", 0.0)
	var dano_recebido = dados_do_prato.get("dano_recebido", 1.0)
	
	if $Player.has_method("aplicar_buff_comida"):
		$Player.aplicar_buff_comida(vel, cooldown, dur, dano_causado, dano_recebido)
		
		# Recover MaxHP, health and hunger
		if max_vida_rec > 0.0:
			max_health = min(max_health + max_vida_rec, 100.0)
		
		hunger = min(hunger + fome_rec, max_hunger)
		health = min(health + vida_rec, max_health)
		$Player.current_health = health
		
		if health > 0.0 and near_death_active:
			exit_near_death()
		
		$HUD.update_health(health, max_health)
		$HUD.update_hunger(hunger, max_hunger)
		_refresh_inventory_hud()
		print("Prato consumido com sucesso! Status atualizados.")
	else:
		print("ERRO: O script do Jogador não tem a função aplicar_buff_comida!")


func open_cooking() -> void:
	if is_game_over or room_transitioning or not is_playing:
		return
	if pause_menu != null:
		pause_menu.hide_menu()
	if inventory_menu != null:
		inventory_menu.hide_menu()
	if not can_leave_current_room():
		_notify_room_locked()
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
			"spork_mode_active": spork_mode_active,
			"near_death_active": near_death_active,
			"player_pos": $Player.global_position,
			"room_scene": _get_current_room_scene_path(),
			"is_playing": is_playing,
			"player_inventory": player_inventory.duplicate(),
			"room_snapshots": room_snapshots.duplicate(true)
		})

	is_playing = false
	$MobTimer.stop()
	$ScoreTimer.stop()
	$Player.is_playing = false
	_save_active_room_snapshot()
	get_tree().change_scene_to_file(_get_cooking_menu_scene_path())


func _input(event):
	if event.is_action_pressed("pause") and not get_tree().paused and is_playing and not is_game_over and not room_transitioning:
		if inventory_menu != null:
			inventory_menu.hide_menu()
		if pause_menu != null:
			pause_menu.show_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not get_tree().paused and is_playing and not is_game_over and not room_transitioning:
		if pause_menu != null:
			pause_menu.hide_menu()
		if inventory_menu != null:
			inventory_menu.show_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("transform") and not get_tree().paused and is_playing and not is_game_over and not room_transitioning:
		spork_mode_active = not spork_mode_active
		if $Player.has_method("set_spork_mode_active"):
			$Player.set_spork_mode_active(spork_mode_active)
		get_viewport().set_input_as_handled()


func enter_near_death() -> void:
	if near_death_active:
		return
	near_death_active = true
	if $Player.has_method("set_near_death_active"):
		$Player.set_near_death_active(true)
	
	# Premium visual feedback: pulsing red overlay screen
	if near_death_overlay == null or not is_instance_valid(near_death_overlay):
		near_death_overlay = CanvasLayer.new()
		near_death_overlay.name = "NearDeathOverlay"
		near_death_overlay.layer = 99
		add_child(near_death_overlay)
		
		var color_rect = ColorRect.new()
		color_rect.name = "RedVignette"
		color_rect.color = Color(1.0, 0.0, 0.0, 0.0) # Start transparent
		color_rect.anchor_left = 0
		color_rect.anchor_top = 0
		color_rect.anchor_right = 1
		color_rect.anchor_bottom = 1
		near_death_overlay.add_child(color_rect)
		
		# Animate the overlay opacity (pulsing red)
		var tween = create_tween().set_loops()
		tween.tween_property(color_rect, "color:a", 0.22, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(color_rect, "color:a", 0.05, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func exit_near_death() -> void:
	if not near_death_active:
		return
	near_death_active = false
	if $Player.has_method("set_near_death_active"):
		$Player.set_near_death_active(false)
		
	# Clean up overlay
	if near_death_overlay != null and is_instance_valid(near_death_overlay):
		near_death_overlay.queue_free()
		near_death_overlay = null
