extends Button


func _on_pressed() -> void:
	$Panel.visible = true


func _on_button_pressed() -> void:
	$Panel.visible = false


func _on_noray_address_text_submitted(_new_text: String) -> void:
	change_noray()


func _on_noray_port_text_submitted(_new_text: String) -> void:
	change_noray()


func change_noray():
	MultiMaster.noray_address = $"Panel/noray address".text
	MultiMaster.noray_port = int($"Panel/noray port".text)
	
	MultiMaster.change_noray_server(MultiMaster.noray_address, MultiMaster.noray_port)
