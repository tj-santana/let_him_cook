extends CanvasLayer

@onready var menu_root: Control = $Menu
@onready var grid_items: GridContainer = $Menu/Panel/MarginContainer/VBoxContainer/SplitContent/ScrollList/GridItems
@onready var selected_name_label: Label = $Menu/Panel/MarginContainer/VBoxContainer/SplitContent/DetailsContainer/PanelDetails/Margin/InfoVBox/SelectedNameLabel
@onready var selected_details_label: Label = $Menu/Panel/MarginContainer/VBoxContainer/SplitContent/DetailsContainer/PanelDetails/Margin/InfoVBox/SelectedDetailsLabel
@onready var eat_button: Button = $Menu/Panel/MarginContainer/VBoxContainer/SplitContent/DetailsContainer/EatButton
@onready var close_button: Button = $Menu/Panel/MarginContainer/VBoxContainer/CloseButton

var item_selecionado = null
var tipo_selecionado = "" # "ingrediente" ou "prato"
var index_prato_selecionado = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.visible = false
	
	if not close_button.pressed.is_connected(hide_menu):
		close_button.pressed.connect(hide_menu)
		
	if not eat_button.pressed.is_connected(_on_eat_button_pressed):
		eat_button.pressed.connect(_on_eat_button_pressed)
		
	_limpar_detalhes()

func show_menu() -> void:
	_limpar_detalhes()
	atualizar_inventario_ui()
	menu_root.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Foca no primeiro botão se houver
	if grid_items.get_child_count() > 0:
		grid_items.get_child(0).grab_focus.call_deferred()

func hide_menu() -> void:
	menu_root.visible = false
	get_tree().paused = false

func _limpar_detalhes() -> void:
	selected_name_label.text = "Select Item"
	selected_details_label.text = "Select an ingredient or cooked dish to view its details and bonuses."
	eat_button.visible = false
	item_selecionado = null
	tipo_selecionado = ""
	index_prato_selecionado = -1

func atualizar_inventario_ui() -> void:
	if typeof(GameManager) == TYPE_NIL:
		return
		
	# Limpa os itens anteriores
	for child in grid_items.get_children():
		child.queue_free()
		
	# 1. POPULAR INGREDIENTES CRUS
	var inventario = GameManager.inventario_jogador
	for ingrediente in inventario.keys():
		var qtd = inventario[ingrediente]
		if qtd > 0:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(120, 80)
			btn.text = ingrediente + "\n x" + str(qtd)
			
			# Define a cor com base na categoria
			var cor = _obter_cor_ingrediente(ingrediente)
			btn.add_theme_color_override("font_color", cor)
			btn.add_theme_color_override("font_hover_color", cor + Color(0.1, 0.1, 0.1))
			
			btn.pressed.connect(func(): _on_ingrediente_selected(ingrediente, qtd))
			grid_items.add_child(btn)
			
	# 2. POPULAR PRATOS COZINHADOS
	var pratos = GameManager.pratos_cozinhados
	for i in range(pratos.size()):
		var prato = pratos[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 80)
		btn.text = prato["nome"]
		
		# Tonalidade dourada/amarela para pratos cozinhados
		var cor_ouro = Color(1.0, 0.85, 0.2)
		btn.add_theme_color_override("font_color", cor_ouro)
		btn.add_theme_color_override("font_hover_color", cor_ouro + Color(0.0, 0.1, 0.1))
		
		btn.pressed.connect(func(): _on_prato_selected(prato, i))
		grid_items.add_child(btn)

func _on_ingrediente_selected(nome: String, qtd: int) -> void:
	item_selecionado = nome
	tipo_selecionado = "ingrediente"
	index_prato_selecionado = -1
	
	selected_name_label.text = nome
	selected_details_label.text = "Quantity: " + str(qtd) + "\n\nA fresh and raw ingredient. Take it to the kitchen to prepare delicious recipes with different culinary methods!"
	eat_button.visible = false

func _on_prato_selected(prato: Dictionary, index: int) -> void:
	item_selecionado = prato
	tipo_selecionado = "prato"
	index_prato_selecionado = index
	
	selected_name_label.text = prato["nome"]
	
	var detalhes = "Effects:\n"
	detalhes += "• Hunger: +" + str(prato.get("fome", 0.0)) + "\n"
	if prato.get("vida", 0.0) > 0:
		detalhes += "• HP: +" + str(prato.get("vida", 0.0)) + "\n"
	if prato.get("max_vida", 0.0) > 0:
		detalhes += "• Max HP: +" + str(prato.get("max_vida", 0.0)) + "\n"
	detalhes += "------------------------\n"
	if prato.get("velocidade", 0) > 0:
		detalhes += "• Speed: +" + str(prato.get("velocidade", 0)) + "\n"
	if prato.get("dano_causado", 0.0) > 0:
		detalhes += "• Attack Damage: +" + str(prato.get("dano_causado", 0.0)) + "\n"
	if prato.get("dano_recebido", 1.0) < 1.0:
		var def = int((1.0 - prato.get("dano_recebido", 1.0)) * 100)
		detalhes += "• Protection: +" + str(def) + "% Defense\n"
	if prato.get("duracao", 0.0) > 0:
		detalhes += "• Duration of Buffs: " + str(prato.get("duracao", 0.0)) + "s\n"
		
	selected_details_label.text = detalhes
	eat_button.visible = true

func _on_eat_button_pressed() -> void:
	if tipo_selecionado == "prato" and index_prato_selecionado >= 0:
		var prato = item_selecionado
		
		# Consome o prato através da lógica principal do jogo
		var parent = get_parent()
		if parent and parent.has_method("consumir_prato"):
			parent.consumir_prato(prato)
			
		# Remove o prato da lista global
		GameManager.pratos_cozinhados.remove_at(index_prato_selecionado)
		
		# Atualiza a UI e fecha ou limpa a seleção
		_limpar_detalhes()
		atualizar_inventario_ui()
		

func _obter_cor_ingrediente(nome: String) -> Color:
	# Copiado/adaptado das categorias visuais da cozinha
	var vegetais = ["Big Leaf", "Roots", "Moss", "Carrots", "Potatoes", "Onions", "Garlic", "Cabbage", "Lettuce", "Broccoli", "Apple", "Bread"]
	var proteinas = ["Suspicious Meat", "Sus Meat", "Bat Wings", "Bat Meat", "Fish Meat", "Bones", "Spider Eyes", "Mush Meat", "Orc Meat", "Mimic Eye", "Mimic Tongue"]
	
	if nome in vegetais:
		return Color(0.5, 0.9, 0.5) # Verde
	elif nome in proteinas:
		return Color(0.9, 0.4, 0.4) # Vermelho
	else:
		return Color(0.9, 0.8, 0.4) # Amarelo/Outro

func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("escape"):
		get_viewport().set_input_as_handled()
		hide_menu()
