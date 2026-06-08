extends Node2D

# Drag and drop the walls you want this lever to remove into this array in the Inspector
@export var target_walls: int = 1
@export var is_one_shot: bool = true # If true, the lever can't be pulled back

var _is_pulled: bool = false

# This matches the method name your player searches for when interacting
func action() -> void:
	if _is_pulled and is_one_shot:
		return
		
	_is_pulled = not _is_pulled
	if _is_pulled:
		_remove_walls()


func _remove_walls() -> void:
	if target_walls == 1:
		get_parent().get_node("Walls2").queue_free()
		get_parent().get_node("lever1off").hide()
		get_parent().get_node("lever1on").show()
	elif target_walls == 2:
		get_parent().get_node("Walls3").queue_free()
		get_parent().get_node("lever2off").hide()
		get_parent().get_node("lever2on").show()
		
