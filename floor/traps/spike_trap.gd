extends Area2D

enum SpikeState { INACTIVE, WARNING, ACTIVE, COOLDOWN }

@export var damage_amount: float = 5.0
@export var warning_duration: float = 0.35
@export var active_duration: float = 0.55
@export var cooldown_duration: float = 0.45
@export var start_delay: float = 0.0
@export var hazard_name: String = "spike_trap"

var _state: SpikeState = SpikeState.INACTIVE
var _cycle_token := 0
var _damaged_bodies: Array[Node] = []

@onready var _visual: Polygon2D = $Polygon2D


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 8
	if collision_mask == 0:
		collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_apply_state(SpikeState.INACTIVE)
	call_deferred("_run_cycle")


func _run_cycle() -> void:
	_cycle_token += 1
	var token = _cycle_token

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if not is_inside_tree() or token != _cycle_token:
			return

	while is_inside_tree() and token == _cycle_token:
		_apply_state(SpikeState.WARNING)
		await _wait_phase(warning_duration, token)
		if not is_inside_tree() or token != _cycle_token:
			return

		_apply_state(SpikeState.ACTIVE)
		_damaged_bodies.clear()
		_damage_overlapping_bodies()
		await _wait_phase(active_duration, token)
		if not is_inside_tree() or token != _cycle_token:
			return

		_apply_state(SpikeState.COOLDOWN)
		await _wait_phase(cooldown_duration, token)


func _wait_phase(duration: float, token: int) -> void:
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if not is_inside_tree() or token != _cycle_token:
		return


func _apply_state(new_state: SpikeState) -> void:
	_state = new_state
	if _visual == null:
		return

	match _state:
		SpikeState.INACTIVE:
			_visual.modulate = Color(0.35, 0.35, 0.35, 1.0)
		SpikeState.WARNING:
			_visual.modulate = Color(1.0, 0.78, 0.2, 1.0)
		SpikeState.ACTIVE:
			_visual.modulate = Color(0.9, 0.18, 0.18, 1.0)
		SpikeState.COOLDOWN:
			_visual.modulate = Color(0.5, 0.5, 0.5, 1.0)


func _physics_process(_delta: float) -> void:
	if _state != SpikeState.ACTIVE:
		return
	_damage_overlapping_bodies()


func _on_body_entered(body: Node) -> void:
	if _state == SpikeState.ACTIVE:
		_try_damage(body)


func _damage_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		_try_damage(body)


func _try_damage(body: Node) -> void:
	if body == null or not body.has_method("apply_damage"):
		return
	if _state != SpikeState.ACTIVE:
		return
	if _damaged_bodies.has(body):
		return
	if "is_dashing" in body and body.is_dashing:
		return
	if body.has_method("get") and body.get("can_take_hit") == false:
		return

	_damaged_bodies.append(body)
	body.apply_damage(damage_amount)
