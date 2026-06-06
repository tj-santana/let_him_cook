extends Control

@onready var texto_titulo = $Panel/VBoxContainer/TextoTitulo
@onready var texto_nota = $Panel/VBoxContainer/TextoNota
@onready var texto_buffs = $Panel/VBoxContainer/TextoBuffs
@onready var texto_nova_receita = $Panel/VBoxContainer/TextoNovaReceita
@onready var botao_continuar = $Panel/VBoxContainer/BotaoContinuar

func _ready():
	pass


func _unhandled_input(event):
	if event.is_action_pressed("escape"):
		GameManager.popup_ativo = false
		var viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		fechar_popup()
	
func mostrar_resultado(nome_prato: String, nota_final: float, buffs: String, e_nova: bool):
	# Calcula as estrelas ou a percentagem
	var percentagem = round(nota_final * 100)
	
	texto_titulo.text = "You cooked: " + nome_prato
	
	# Mensagem de qualidade
	if percentagem >= 90:
		texto_nota.text = "Quality: " + str(percentagem) + "% (Masterpiece!)"
	elif percentagem >= 75:
		texto_nota.text = "Quality: " + str(percentagem) + "% (Delicious!)"
	elif percentagem >= 50:
		texto_nota.text = "Quality: " + str(percentagem) + "% (Decent!)"
	elif percentagem >= 25:
		texto_nota.text = "Quality: " + str(percentagem) + "% (Edible...)"
	else:
		texto_nota.text = "Quality: " + str(percentagem) + "% (Toxic Garbage!)"
		
	texto_buffs.text = buffs
	
	# Mostra ou esconde o aviso de receita descoberta
	texto_nova_receita.visible = e_nova
	
	# Mostra o ecrã
	show()


func fechar_popup() -> void:
	var camada_popup = get_parent()
	if camada_popup != null:
		camada_popup.queue_free()
