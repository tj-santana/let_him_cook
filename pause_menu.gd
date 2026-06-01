extends CanvasLayer

@onready var menu_root: Control = $Menu
@onready var resume_button: Button = $Menu/Panel/VBoxContainer/ResumeButton
@onready var quit_button: Button = $Menu/Panel/VBoxContainer/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.visible = false
	if not resume_button.pressed.is_connected(_on_resume_button_pressed):
		resume_button.pressed.connect(_on_resume_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)


func show_menu() -> void:
	menu_root.visible = true
	get_tree().paused = true
	resume_button.grab_focus.call_deferred()


func hide_menu() -> void:
	menu_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		hide_menu()


func _on_resume_button_pressed() -> void:
	hide_menu()


func _on_quit_button_pressed() -> void:
	hide_menu()
	get_tree().change_scene_to_file("res://MainMenu.tscn")