extends Node2D

var ingredientes_na_panela: Array = []

# --- LÓGICA DE TEXTURAS E CORES DINÂMICAS ---
func obter_textura_ingrediente(nome: String) -> Texture2D:
	var path_base = "res://microgames/Assets/Food/Isolated Food/"
	match nome:
		"Sus Meat", "Suspicious Meat":
			return load(path_base + "sus_meat.tres")
		"Slime":
			return load(path_base + "icon_slime.tres")
		"Essence":
			return load(path_base + "icon_essence.tres")
		"Bat Wings":
			return load(path_base + "asa_morcego.png")
		"Bat Meat":
			return load(path_base + "BatCarne.tres")
		"Bones":
			return load(path_base + "osso.png")
		"Orc Meat":
			return load(path_base + "orc_meat.tres")
		"Mimic Eye":
			return load(path_base + "mimic_eye.tres")
		"Mimic Tongue":
			return load(path_base + "mimic_tongue.tres")
		"Moss":
			return load(path_base + "moss.png")
		_:
			# Fallback
			return load(path_base + "icon_essence.tres")

func obter_cor_ingrediente(nome: String) -> Color:
	# Categoria Veggies:
	if nome in ["Big Leaf", "Roots", "Moss", "Carrots", "Potatoes", "Onions", "Garlic", "Cabbage", "Lettuce", "Broccoli", "Apple"]:
		return Color(0.5, 0.9, 0.5) # Verde claro agradável
	# Categoria Proteins:
	elif nome in ["Suspicious Meat", "Sus Meat", "Bat Wings", "Bat Meat", "Fish Meat", "Bones", "Spider Eyes", "Mush Meat", "Orc Meat", "Mimic Eye", "Mimic Tongue"]:
		return Color(0.9, 0.5, 0.5) # Vermelho suave
	# Outros / Pão
	else:
		return Color(0.95, 0.8, 0.4) # Amarelo/Laranja suave


@onready var slots_visuais = [
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot1,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot2,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot3,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot4
]

func _ready():
	atualizar_ecra()
	atualizar_textos_inventario() # Garante que os números aparecem certos logo ao iniciar!
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var slot_count = 0
	for slot in slots_visuais:
		if slot_count < GameManager.limite_ingredientes:
			slot.get_node("Icon").modulate = Color.WHITE
			slot.color = Color.DARK_GRAY
		else:
			slot.color = Color(0.69, 0.13, 0.1)
		slot_count += 1

func _unhandled_input(event):
	if event.is_action_pressed("escape") and not GameManager.popup_ativo:
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		for i in range(ingredientes_na_panela.size() - 1, -1, -1):
			tentar_remover_ingrediente(i)
		if typeof(GameManager) != TYPE_NIL:
			var s = GameManager.obter_estado_principal()
			if s != null:
				s["player_inventory"] = GameManager.inventario_jogador.duplicate()
			GameManager.limpar_dados()
		var cena_retorno = "res://game_shell.tscn"
		if typeof(GameManager) != TYPE_NIL and GameManager.cena_principal_path != "":
			cena_retorno = GameManager.cena_principal_path
		get_tree().change_scene_to_file(cena_retorno)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

# --- ATUALIZAR OS TEXTOS DOS NÚMEROS (DINÂMICO) ---
func atualizar_textos_inventario():
	var grelha = get_node_or_null("CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/InventarioJogadorScroll/GrelhaInventario")
	if not grelha:
		return
		
	# Limpa os botões anteriores
	for child in grelha.get_children():
		child.queue_free()
		
	# Popula a grelha de forma dinâmica
	for ingrediente in GameManager.inventario_jogador.keys():
		var qtd = GameManager.inventario_jogador[ingrediente]
		if qtd <= 0:
			continue
			
		var botao = Button.new()
		botao.custom_minimum_size = Vector2(100, 100)
		botao.expand_icon = true
		
		# Ícone (sem modular o botão para preservar a cor original do sprite)
		botao.icon = obter_textura_ingrediente(ingrediente)
		botao.tooltip_text = ingrediente + " (" + str(qtd) + ")"
		
		var cor = obter_cor_ingrediente(ingrediente)
		
		# Label de Nome (Top-Left, com a cor da categoria)
		var label_nome = Label.new()
		label_nome.text = ingrediente
		label_nome.position = Vector2(5, 5)
		label_nome.add_theme_color_override("font_color", cor)
		label_nome.add_theme_constant_override("outline_size", 4)
		label_nome.add_theme_font_size_override("font_size", 10)
		botao.add_child(label_nome)
		
		# Label de Quantidade (Bottom-Right, com a cor da categoria)
		var label_qtd = Label.new()
		label_qtd.text = str(qtd)
		label_qtd.position = Vector2(75, 70)
		label_qtd.add_theme_color_override("font_color", cor)
		label_qtd.add_theme_constant_override("outline_size", 4)
		label_qtd.add_theme_font_size_override("font_size", 16)
		botao.add_child(label_qtd)
		
		# Conexão de sinal ao clicar usando lambda multilinha correta
		botao.pressed.connect(func():
			tentar_adicionar_ingrediente(ingrediente)
		)
		
		grelha.add_child(botao)



# --- ADICIONAR E REMOVER DA PANELA ---
func tentar_adicionar_ingrediente(ingrediente: String):
	if GameManager.inventario_jogador[ingrediente] > 0:
		if ingredientes_na_panela.size() < GameManager.limite_ingredientes:
			GameManager.inventario_jogador[ingrediente] -= 1
			ingredientes_na_panela.append(ingrediente)
			print(ingrediente, " adicionado!")
			
			atualizar_ecra()
			atualizar_textos_inventario()
		else:
			print("A panela já está cheia!")
	else:
		print("Não tens mais ", ingrediente, " no inventário!")

func tentar_remover_ingrediente(indice_slot: int):
	if indice_slot < ingredientes_na_panela.size():
		var ingrediente_removido = ingredientes_na_panela[indice_slot]
		GameManager.inventario_jogador[ingrediente_removido] += 1
		ingredientes_na_panela.remove_at(indice_slot)
		
		atualizar_ecra()
		atualizar_textos_inventario()


# --- BOTÃO DE COZINHAR E MÉTODOS ---
func cozinhar_com_metodo(metodo: String):
	if ingredientes_na_panela.size() >= 2:
		print("A começar o preparo do prato com o método ", metodo, "...")
		GameManager.ingredientes_atuais = ingredientes_na_panela.duplicate()
		GameManager.iniciar_sequencia_minijogos(metodo)
	else:
		print("Precisas de pelo menos 2 ingredientes na panela primeiro!")

func _on_botao_ferver_pressed():
	cozinhar_com_metodo("Boil")

func _on_botao_fritar_pressed():
	cozinhar_com_metodo("Fry")

func _on_botao_assar_pressed():
	cozinhar_com_metodo("Roast")

# --- LIVRO DE RECEITAS ---
func _on_botao_livro_pressed():
	var overlay = get_node_or_null("CanvasLayer/MenuCozinha_Overlay/LivroReceitas_Overlay")
	if overlay:
		overlay.visible = true
		atualizar_livro_receitas()

func _on_botao_fechar_livro_pressed():
	var overlay = get_node_or_null("CanvasLayer/MenuCozinha_Overlay/LivroReceitas_Overlay")
	if overlay:
		overlay.visible = false

func atualizar_livro_receitas():
	var lista_recipiente = get_node_or_null("CanvasLayer/MenuCozinha_Overlay/LivroReceitas_Overlay/FundoLivro/ScrollContainer/ListaReceitas")
	if not lista_recipiente:
		return
		
	# Limpa a lista existente de receitas
	for child in lista_recipiente.get_children():
		child.queue_free()
		
	# Percorre todas as receitas possíveis do livro de receitas
	for chave in GameManager.livro_de_receitas.keys():
		var nome_prato = GameManager.livro_de_receitas[chave]
		
		# Vamos criar um painel simples para cada receita para ficar super premium
		var item_panel = PanelContainer.new()
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 15)
		margin_container.add_theme_constant_override("margin_right", 15)
		margin_container.add_theme_constant_override("margin_top", 10)
		margin_container.add_theme_constant_override("margin_bottom", 10)
		
		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 20)
		
		var label_status = Label.new()
		var label_nome = Label.new()
		
		label_status.add_theme_font_size_override("font_size", 18)
		label_nome.add_theme_font_size_override("font_size", 18)
		
		if GameManager.receitas_desbloqueadas.has(nome_prato):
			# Receita Desbloqueada
			label_status.text = "📖"
			label_status.modulate = Color(0.2, 0.9, 0.2) # Verde neon
			
			var ing_texto = chave[0] + ": " + " + ".join(chave.slice(1, chave.size()))
			label_nome.text = nome_prato + " (" + ing_texto + ")"
			label_nome.modulate = Color(0.95, 0.95, 0.9) # Bege claro
		else:
			# Receita Bloqueada
			label_status.text = "🔒"
			label_status.modulate = Color(0.6, 0.6, 0.6) # Cinzento
			
			label_nome.text = "??? (Bloqueado)"
			label_nome.modulate = Color(0.5, 0.5, 0.5) # Cinzento escuro
			
		item_hbox.add_child(label_status)
		item_hbox.add_child(label_nome)
		margin_container.add_child(item_hbox)
		item_panel.add_child(margin_container)
		lista_recipiente.add_child(item_panel)

# --- MAGIA VISUAL ---
func atualizar_ecra():
	for i in range(slots_visuais.size()):
		var icon_do_slot = slots_visuais[i].get_node("Icon")
		
		if i < ingredientes_na_panela.size():
			var ingrediente = ingredientes_na_panela[i]
			icon_do_slot.texture = obter_textura_ingrediente(ingrediente)
			icon_do_slot.modulate = Color.WHITE
			slots_visuais[i].color = Color.DARK_GRAY
		else:
			icon_do_slot.texture = null

# --- SINAIS PARA REMOVER (CLIQUES NOS SLOTS DA PANELA) ---
func _on_slot_1_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tentar_remover_ingrediente(0)

func _on_slot_2_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tentar_remover_ingrediente(1)

func _on_slot_3_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tentar_remover_ingrediente(2)

func _on_slot_4_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tentar_remover_ingrediente(3)
