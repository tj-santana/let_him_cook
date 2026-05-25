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
	# Se tivermos ingredientes guardados no GameManager, significa que acabámos de voltar dos minijogos!
	if GameManager.ingredientes_atuais.size() > 0:
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
	if GameManager.inventario_jogador[ingrediente] > 0:
		if ingredientes_na_panela.size() < limite_ingredientes:
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

func _on_inv_slot_carne_pressed(): tentar_adicionar_ingrediente("Sus Meat")
func _on_inv_slot_slime_pressed(): tentar_adicionar_ingrediente("Slime")
func _on_inv_slot_essence_pressed(): tentar_adicionar_ingrediente("Essence")

# --- BOTÃO DE COZINHAR ---
func _on_botao_cozinhar_pressed():
	# 1. Verifica se a panela tem os ingredientes necessários
	if ingredientes_na_panela.size() == limite_ingredientes:
		
		# 2. Testa se a receita existe antes de ir para os minijogos
		var ingredientes_teste = ingredientes_na_panela.duplicate()
		ingredientes_teste.sort()
		
		if GameManager.livro_de_receitas.has(ingredientes_teste):
			print("A começar o preparo do prato...")
			GameManager.ingredientes_atuais = ingredientes_na_panela.duplicate()
			GameManager.iniciar_sequencia_minijogos()
		else:
			print("ERRO: Essa combinação não existe no livro de receitas!")
	else:
		print("Precisas de 2 ingredientes na panela primeiro!")

# --- AVALIAÇÃO DE RECEITAS ---
# Altera a tua função avaliar_resultado() para incluir o GameManager.buff_fome:

func avaliar_resultado():
	var pontuacao = GameManager.pontuacao_total
	var ingredientes = GameManager.ingredientes_atuais
	ingredientes.sort()
	
	if GameManager.livro_de_receitas.has(ingredientes):
		var nome_do_prato = GameManager.livro_de_receitas[ingredientes]
		
		if pontuacao >= 2.5: 
			print("SUCESSO PERFEITO! Criaste um(a) ", nome_do_prato, " ★★★")
			GameManager.buff_pendente = true
			GameManager.buff_velocidade = 200
			GameManager.buff_cooldown = 0.15
			GameManager.buff_duracao = 30.0
			GameManager.buff_fome = 10.0 # <--- ADICIONADO

		elif pontuacao >= 1.5: 
			print("SUCESSO! Criaste um(a) ", nome_do_prato, " ★★")
			GameManager.buff_pendente = true
			GameManager.buff_velocidade = 100
			GameManager.buff_cooldown = 0.05
			GameManager.buff_duracao = 15.0
			GameManager.buff_fome = 10.0 # <--- ADICIONADO
			
		else: 
			print("POR POUCO! O teu(a) ", nome_do_prato, " ficou meio queimado ★")
			GameManager.buff_pendente = true
			GameManager.buff_velocidade = 50
			GameManager.buff_cooldown = 0.0
			GameManager.buff_duracao = 10.0
			GameManager.buff_fome = 10.0 # <--- ADICIONADO
		
		pontuacao = 0.0 # Reseta a pontuação para o próximo prato	
		GameManager.pontuacao_total = 0.0
		GameManager.ingredientes_atuais = [] # Limpa os ingredientes atuais		
		
# --- MAGIA VISUAL ---
func atualizar_ecra():
	for i in range(slots_visuais.size()):
		var icon_do_slot = slots_visuais[i].get_node("Icon")
		
		if i < ingredientes_na_panela.size():
			if ingredientes_na_panela[i] == "Sus Meat":
				icon_do_slot.texture = textura_sus_meat
			elif ingredientes_na_panela[i] == "Slime":
				icon_do_slot.texture = textura_slime
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
