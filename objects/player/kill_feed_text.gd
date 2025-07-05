extends RichTextLabel


#func _ready() -> void:
	#$Timer.timeout.connect(die)


func start(death_text:String):
	text = death_text
	$AnimationPlayer.play("fade")
	#$Timer.start()


func die():
	visible = false
	queue_free()
	$"../..".update_size()
	


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	die()
