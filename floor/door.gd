extends Area2D

@export var target_scene: String = "" # path like 'res://rooms/Room_B.tscn'
@export var entry_marker: String = ""

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

func _on_body_entered(body):
	if not body or (not body.is_in_group("player") and body.name != "Player"):
		return
	# Find the FloorController in the parent chain
	var p = get_parent()
	while p and not p.has_method("enter_room"):
		p = p.get_parent()
	if p and p.has_method("enter_room"):
		p.enter_room(target_scene, entry_marker)
