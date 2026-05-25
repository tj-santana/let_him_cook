extends Control

@onready var texto_titulo = $Panel/VBoxContainer/TextoTitulo
@onready var texto_nota = $Panel/VBoxContainer/TextoNota
@onready var texto_buffs = $Panel/VBoxContainer/TextoBuffs
@onready var texto_nova_receita = $Panel/VBoxContainer/TextoNovaReceita
@onready var botao_continuar = $Panel/VBoxContainer/BotaoContinuar

func _ready():
	pass
	
func mostrar_resultado(nome_prato: String, nota_final: float, buffs: String, e_nova: bool):
	# Calcula as estrelas ou a percentagem
	var percentagem = round(nota_final * 100)
	
	texto_titulo.text = "Cozinhaste: " + nome_prato
	
	# Mensagem de qualidade
	if percentagem >= 90:
		texto_nota.text = "Qualidade: " + str(percentagem) + "% (Obra-prima!)"
	elif percentagem >= 50:
		texto_nota.text = "Qualidade: " + str(percentagem) + "% (Comestível...)"
	else:
		texto_nota.text = "Qualidade: " + str(percentagem) + "% (Gororoba Tóxica!)"
		
	texto_buffs.text = buffs
	
	# Mostra ou esconde o aviso de receita descoberta
	texto_nova_receita.visible = e_nova
	
	# Mostra o ecrã
	show()
