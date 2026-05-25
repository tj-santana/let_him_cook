extends Node2D

@export var interaction_action: StringName = &"interact"
var player_inside := false

@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	if not interact_area.body_entered.is_connected(_on_body_entered):
		interact_area.body_entered.connect(_on_body_entered)
	if not interact_area.body_exited.is_connected(_on_body_exited):
		interact_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed(interaction_action):
		_request_cooking()

func _on_body_entered(body: Node) -> void:
	if body != null and (body.name == "Player" or body.is_in_group("player")):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body != null and (body.name == "Player" or body.is_in_group("player")):
		player_inside = false

func _request_cooking() -> void:
	var node: Node = self
	while node != null and not node.has_method("open_cooking"):
		node = node.get_parent()
	if node != null and node.has_method("open_cooking"):
		node.open_cooking()
