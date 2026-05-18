extends Control

func _ready() -> void:
	$Message.text = "Let Him Cook"
	$Message.show()
	$StartButton.show()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game.tscn")
	#get_tree().change_scene_to_file("res://tutorial.tscn")
	
