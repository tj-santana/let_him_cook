extends Area2D

@export var target_scene: String = "" # path like 'res://rooms/floor_1/F1_EastHall.tscn'
@export var entry_marker: String = ""

var _check_timer: Timer = null
var _locked_visual_color: Color = Color(1, 0.4, 0.4, 1)
var _unlocked_visual_color: Color = Color(1, 1, 1, 1)

func _ready():
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2

	if not has_node("CollisionShape2D"):
		# create a default small collision shape so the door is detectable in code
		var cs = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(32, 64)
		cs.shape = rect
		add_child(cs)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# start a short timer to update the locked/unlocked visual state
	_check_timer = Timer.new()
	_check_timer.wait_time = 0.2
	_check_timer.one_shot = false
	add_child(_check_timer)
	_check_timer.start()
	if not _check_timer.timeout.is_connected(_on_check_timer_timeout):
		_check_timer.timeout.connect(_on_check_timer_timeout)
	# update immediately
	_update_locked_visual()

func _on_body_entered(body):
	if not body or (not body.is_in_group("player") and body.name != "Player"):
		return
	# Find the FloorController in the parent chain
	var p = get_parent()
	while p and not p.has_method("enter_room"):
		p = p.get_parent()
	if p and p.has_method("can_leave_current_room") and not p.can_leave_current_room():
		if p.has_method("_notify_room_locked"):
			p._notify_room_locked()
		return
	if p and p.has_method("enter_room"):
		p.enter_room(target_scene, entry_marker)


func _on_check_timer_timeout() -> void:
	_update_locked_visual()


func _update_locked_visual() -> void:
	# find controller with can_leave_current_room
	var controller = get_parent()
	while controller != null and not controller.has_method("can_leave_current_room"):
		controller = controller.get_parent()
	var locked := false
	if controller != null and controller.has_method("can_leave_current_room"):
		locked = not controller.can_leave_current_room()

	# find a Sprite2D child to tint; common name is "Sprite2D"
	var spr: Sprite2D = null
	if has_node("Sprite2D"):
		spr = get_node("Sprite2D")
	else:
		for c in get_children():
			if c is Sprite2D:
				spr = c
				break

	if spr != null:
		if locked:
			spr.modulate = _locked_visual_color
		else:
			spr.modulate = _unlocked_visual_color
