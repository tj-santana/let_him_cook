extends Control

@onready var start_button: Button = $StartButton

func _ready() -> void:
	$Message.text = "Let Him Cook"
	$Message.show()
	start_button.show()
	start_button.focus_mode = Control.FOCUS_ALL
	start_button.grab_focus.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_start_button_pressed()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game_shell.tscn")
	#get_tree().change_scene_to_file("res://tutorial.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
