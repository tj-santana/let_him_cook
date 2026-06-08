extends Area2D

const Balloon = preload("res://dialogue/balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func action() -> void:
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
