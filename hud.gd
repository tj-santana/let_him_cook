extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func update_health(current_health: float, max_health: float):
	$HealthBar.value = (current_health / max_health) * 100.0
	$HealthBar/Label.text = "%d" % current_health + "/%d" % max_health

func update_hunger(current_hunger: float, max_hunger: float):
	$HungerBar.value = (current_hunger / max_hunger) * 100.0
	$HungerBar/Label.text = "%d" % current_hunger + "/%d" % max_hunger

func update_ingredients(ingredients):
	pass


func update_inventory(inventory: Dictionary):
	var sus_meat = int(inventory.get("Sus Meat", 0))
	var slime = int(inventory.get("Slime", 0))
	var essence = int(inventory.get("Essence", 0))

	$InventorySlots/InvSlot_Carne/QtdTexto.text = str(sus_meat)
	$InventorySlots/InvSlot_Slime/QtdTexto.text = str(slime)
	$InventorySlots/InvSlot_Essence/QtdTexto.text = str(essence)
	
func update_score(score):
	$ScoreLabel.text = "Time: %s" % score
