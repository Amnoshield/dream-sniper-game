extends MeshInstance3D


func _ready() -> void:
	transparency = 0

@rpc("any_peer", "call_local", "reliable")
func start(collision_point:Vector3, global_pos:Vector3, ray_global_rotation):
	var direction = collision_point-global_pos
	global_position = global_pos+direction/2
	scale.y = direction.length()
	global_rotation = ray_global_rotation
	rotation.x += (PI/2)
	
	$AnimationPlayer.play("fade")
