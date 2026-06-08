extends Area2D

@export var target_scene: String = "" # path like 'res://rooms/floor_1/F1_EastHall.tscn'
@export var entry_marker: String = ""
@export var to_different_floor = false

var _check_timer: Timer = null
var _locked_visual_color: Color = Color(1, 0.4, 0.4, 0.5)
var _unlocked_visual_color: Color = Color(1, 1, 1, 0.5)

var prompt_layer: CanvasLayer = null
var btn_no_reference: Button = null

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

	if to_different_floor:
		_create_prompt_ui()

func _create_prompt_ui() -> void:
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = 150
	prompt_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Allows UI to run while paused
	prompt_layer.hide()
	add_child(prompt_layer)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_layer.add_child(bg)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -100
	panel.offset_right = 200
	panel.offset_bottom = 100
	bg.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "Descend to the next floor?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 50)
	vbox.add_child(hbox)

	var btn_yes = Button.new()
	btn_yes.text = " Yes "
	btn_yes.add_theme_font_size_override("font_size", 24)
	btn_yes.custom_minimum_size = Vector2(100, 40)
	btn_yes.pressed.connect(_on_prompt_yes)
	hbox.add_child(btn_yes)

	# Store this in our script variable so we can target it directly later
	btn_no_reference = Button.new()
	btn_no_reference.text = " No "
	btn_no_reference.add_theme_font_size_override("font_size", 24)
	btn_no_reference.custom_minimum_size = Vector2(100, 40)
	btn_no_reference.pressed.connect(_on_prompt_no)
	hbox.add_child(btn_no_reference)

func _on_body_entered(body):
	if not body or (not body.is_in_group("player") and body.name != "Player"):
		return
	
	var p = get_parent()
	
	# Check if room is locked
	var controller = p
	while controller and not controller.has_method("enter_room"):
		controller = controller.get_parent()
	
	if controller and controller.has_method("can_leave_current_room") and not controller.can_leave_current_room():
		if controller.has_method("_notify_room_locked"):
			controller._notify_room_locked()
		return

	# Handle transition
	if to_different_floor and prompt_layer:
		prompt_layer.show()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# FIXED: Use the saved direct reference instead of get_node() pathing
		if is_instance_valid(btn_no_reference):
			btn_no_reference.grab_focus.call_deferred()
		
		GameManager.limite_ingredientes += 1
	else:
		# Normal intra-floor transition
		if controller and controller.has_method("enter_room"):
			controller.enter_room(target_scene, entry_marker)


func _on_prompt_yes():
	if prompt_layer:
		prompt_layer.hide()
	
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN # Re-hide mouse for gameplay

	var p = get_parent()
	while p and not p.has_method("enter_room"):
		p = p.get_parent()
	if p and p.has_method("enter_room"):
		p.enter_room(target_scene, entry_marker)


func _on_prompt_no():
	if prompt_layer:
		prompt_layer.hide()
		
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN # Re-hide mouse for gameplay


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
			spr.visible = true
			spr.modulate = _locked_visual_color
		else:
			spr.visible = false
			spr.modulate = _unlocked_visual_color
