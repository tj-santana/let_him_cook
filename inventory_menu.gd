extends CanvasLayer

@onready var menu_root: Control = $Menu
@onready var item_buttons: Array[Button] = [
	$Menu/Panel/VBoxContainer/InventoryGrid/SusMeatButton,
	$Menu/Panel/VBoxContainer/InventoryGrid/SlimeButton,
	$Menu/Panel/VBoxContainer/InventoryGrid/EssenceButton
]
@onready var selected_label: Label = $Menu/Panel/VBoxContainer/SelectedLabel
@onready var close_button: Button = $Menu/Panel/VBoxContainer/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.visible = false
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	if not item_buttons[0].pressed.is_connected(_on_item_button_pressed.bind("Sus Meat")):
		item_buttons[0].pressed.connect(_on_item_button_pressed.bind("Sus Meat"))
	if not item_buttons[1].pressed.is_connected(_on_item_button_pressed.bind("Slime")):
		item_buttons[1].pressed.connect(_on_item_button_pressed.bind("Slime"))
	if not item_buttons[2].pressed.is_connected(_on_item_button_pressed.bind("Essence")):
		item_buttons[2].pressed.connect(_on_item_button_pressed.bind("Essence"))
	_refresh_inventory_text()


func show_menu() -> void:
	_refresh_inventory_text()
	menu_root.visible = true
	get_tree().paused = true
	item_buttons[0].grab_focus.call_deferred()


func hide_menu() -> void:
	menu_root.visible = false
	get_tree().paused = false


func _refresh_inventory_text() -> void:
	if typeof(GameManager) == TYPE_NIL:
		return
	var inventory := GameManager.inventario_jogador
	item_buttons[0].text = "Sus Meat\n x%s" % inventory.get("Sus Meat", 0)
	item_buttons[1].text = "Slime\n x%s" % inventory.get("Slime", 0)
	item_buttons[2].text = "Essence\n x%s" % inventory.get("Essence", 0)
	selected_label.text = "Select an item to inspect it."


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("escape"):
		get_viewport().set_input_as_handled()
		hide_menu()


func _on_item_button_pressed(item_name: String) -> void:
	if typeof(GameManager) == TYPE_NIL:
		return
	selected_label.text = "%s: %s" % [item_name, GameManager.inventario_jogador.get(item_name, 0)]


func _on_close_button_pressed() -> void:
	hide_menu()