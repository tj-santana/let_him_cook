extends Area2D

const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
@export var lever = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func action() -> void:
	if lever:
		if get_parent() and get_parent()._is_pulled:
			return
	# 1. Pause the game and show the mouse
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 2. Instantiate the balloon
	var balloon: Node = Balloon.instantiate()
	
	# 3. CRITICAL: Tell the balloon to keep running even though the game is paused!
	balloon.process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().current_scene.add_child(balloon)
	balloon.start(dialogue_resource, dialogue_start)
	
	# 4. Wait right here until the dialogue finishes and the balloon deletes itself
	await balloon.tree_exited
	
	# 5. Dialogue is over! Resume the game and hide the mouse
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	#  if this is a lever, we want to trigger the children to do their thing (like opening a door or something)
	if lever:
		if get_parent() and get_parent().has_method("action"):
			get_parent().action()
			
	if GameManager.boss_unlocked:
		GameManager.move_to_corridor()
