extends Node2D

var ingredientes_na_panela: Array = []
var limite_ingredientes: int = 2

# --- TEXTURAS ---
var textura_sus_meat = preload("res://microgames/Assets/Food/Isolated Food/icon_sus_meat.tres")
var textura_slime = preload("res://microgames/Assets/Food/Isolated Food/icon_slime.tres")
var textura_essence = preload("res://microgames/Assets/Food/Isolated Food/icon_essence.tres")

@onready var slots_visuais = [
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot1,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot2,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot3,
	$CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/ListaSlots/Slot4
]

func _ready():
	if GameManager.desempenho_microgame > 0:
		avaliar_resultado()
	atualizar_ecra()
	atualizar_textos_inventario() # Garante que os números aparecem certos logo ao iniciar!
	
func _process(delta):
	if Input.is_action_pressed("escape"):
		for i in range(ingredientes_na_panela.size(), -1, -1):
			tentar_remover_ingrediente(i)
		get_tree().change_scene_to_file("res://game.tscn")

# --- ATUALIZAR OS TEXTOS DOS NÚMEROS ---
func atualizar_textos_inventario():
	var caminho_base = $CanvasLayer/MenuCozinha_Overlay/PainelPrincipal/InventarioJogador
	
	caminho_base.get_node("InvSlot_Carne/QtdTexto").text = str(GameManager.inventario_jogador["Sus Meat"])
	caminho_base.get_node("InvSlot_Slime/QtdTexto").text = str(GameManager.inventario_jogador["Slime"])
	caminho_base.get_node("InvSlot_Essence/QtdTexto").text = str(GameManager.inventario_jogador["Essence"])

# --- ADICIONAR E REMOVER DA PANELA ---
func tentar_adicionar_ingrediente(ingrediente: String):
	# 1. Verifica se temos quantidade maior que 0 no inventário
	if GameManager.inventario_jogador[ingrediente] > 0:
		
		# 2. Verifica se a panela tem espaço (limite de 2)
		if ingredientes_na_panela.size() < limite_ingredientes:
			
			# Retira 1 do inventário e coloca na panela
			GameManager.inventario_jogador[ingrediente] -= 1
			ingredientes_na_panela.append(ingrediente)
			print(ingrediente, " adicionado!")
			
			atualizar_ecra()
			atualizar_textos_inventario() # Atualiza os números no ecrã!
		else:
			print("A panela já está cheia!")
	else:
		print("Não tens mais ", ingrediente, " no inventário!")

func tentar_remover_ingrediente(indice_slot: int):
	# Se existir um item naquele slot
	if indice_slot < ingredientes_na_panela.size():
		var ingrediente_removido = ingredientes_na_panela[indice_slot]
		
		# Devolvemos 1 à quantidade desse item no inventário
		GameManager.inventario_jogador[ingrediente_removido] += 1
		
		# Tiramos da panela
		ingredientes_na_panela.remove_at(indice_slot)
		
		atualizar_ecra()
		atualizar_textos_inventario() # Atualiza os números no ecrã!

func _on_inv_slot_carne_pressed():
	tentar_adicionar_ingrediente("Sus Meat")

func _on_inv_slot_slime_pressed():
	tentar_adicionar_ingrediente("Slime")

func _on_inv_slot_essence_pressed():
	tentar_adicionar_ingrediente("Essence")

# --- BOTÃO DE COZINHAR ---
func _on_botao_cozinhar_pressed():
	# Verifica diretamente o tamanho da lista nova
	if ingredientes_na_panela.size() == limite_ingredientes:
		print("A começar o preparo...")
		
		# Guarda os ingredientes atuais no GameManager para quando o jogo voltar a esta cena saber o que avaliar!
		GameManager.ingredientes_atuais = ingredientes_na_panela.duplicate()
		
		# Chama o GameManager para arrancar com a roleta russa de minijogos!
		GameManager.iniciar_sequencia_minijogos()
	else:
		print("Precisas de 2 ingredientes na panela primeiro!")

# --- AVALIAÇÃO DE RECEITAS ---
func avaliar_resultado():
	var score = GameManager.desempenho_microgame
	var ingredientes = GameManager.ingredientes_atuais
	
	ingredientes.sort()
	
	if GameManager.livro_de_receitas.has(ingredientes):
		var nome_do_prato = GameManager.livro_de_receitas[ingredientes]
		
		if score >= 0.8:
			print("SUCESSO PERFEITO! Criaste um(a) ", nome_do_prato, " de excelente qualidade!")
		elif score >= 0.5:
			print("SUCESSO! Criaste um(a) ", nome_do_prato, " com qualidade razoável.")
		else:
			print("FALHA! Queimaste a receita de ", nome_do_prato, " no minijogo!")
	else:
		print("ERRO DE RECEITA! Essa combinação (", ingredientes, ") criou uma gororoba tóxica!")

	GameManager.limpar_dados()
	ingredientes_na_panela.clear()
	atualizar_ecra()

# --- MAGIA VISUAL ---
func atualizar_ecra():
	# Mudei para ver o tamanho total dos slots visuais para limpar corretamente os quadrados extras
	for i in range(slots_visuais.size()):
		var icon_do_slot = slots_visuais[i].get_node("Icon")
		
		if i < ingredientes_na_panela.size():
			if ingredientes_na_panela[i] == "Sus Meat":
				icon_do_slot.texture = textura_sus_meat
				slots_visuais[i].color = Color.DARK_GRAY

			elif ingredientes_na_panela[i] == "Slime":
				icon_do_slot.texture = textura_slime
				slots_visuais[i].color = Color.DARK_GRAY
				
			elif ingredientes_na_panela[i] == "Essence":
				icon_do_slot.texture = textura_essence
				slots_visuais[i].color = Color.DARK_GRAY
		else:
			icon_do_slot.texture = null
			slots_visuais[i].color = Color.DARK_GRAY

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
