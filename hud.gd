extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func update_health(current_health: float, max_health: float):
	$HealthBar.value = max(0.0, (current_health / max_health) * 100.0)
	if current_health <= 0.0:
		$HealthBar.self_modulate = Color(0.4, 0.0, 0.0, 1.0) # Dark red/crimson
		$HealthBar/Label.text = "BLEEDING: %d" % current_health + "/%d" % max_health
	else:
		$HealthBar.self_modulate = Color(0.95, 0.0, 0.0, 1.0) # Bright red
		$HealthBar/Label.text = "%d" % current_health + "/%d" % max_health

func update_hunger(current_hunger: float, max_hunger: float):
	$HungerBar.value = (current_hunger / max_hunger) * 100.0
	$HungerBar/Label.text = "%d" % current_hunger + "/%d" % max_hunger

func update_ingredients(ingredients):
	# Accept either a dictionary inventory or nothing
	if typeof(ingredients) != TYPE_DICTIONARY:
		return

	var sus_meat = int(ingredients.get("Sus Meat", 0))
	var slime = int(ingredients.get("Slime", 0))
	var essence = int(ingredients.get("Essence", 0))

	if $InventorySlots.has_node("InvSlot_Carne"):
		$InventorySlots/InvSlot_Carne/QtdTexto.text = str(sus_meat)
	if $InventorySlots.has_node("InvSlot_Slime"):
		$InventorySlots/InvSlot_Slime/QtdTexto.text = str(slime)
	if $InventorySlots.has_node("InvSlot_Essence"):
		$InventorySlots/InvSlot_Essence/QtdTexto.text = str(essence)


func update_inventory(inventory: Dictionary):
	var sus_meat = int(inventory.get("Sus Meat", 0))
	var slime = int(inventory.get("Slime", 0))
	var essence = int(inventory.get("Essence", 0))

	$InventorySlots/InvSlot_Carne/QtdTexto.text = str(sus_meat)
	$InventorySlots/InvSlot_Slime/QtdTexto.text = str(slime)
	$InventorySlots/InvSlot_Essence/QtdTexto.text = str(essence)
	
func update_score(score):
	$ScoreLabel.text = "Time: %s" % score
