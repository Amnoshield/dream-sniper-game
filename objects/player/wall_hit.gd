extends Node3D


@rpc("any_peer", "reliable", "call_local")
func activate(to:Vector3, shot_rotation:Vector3):
	global_position = to
	$"hit wall".play()
	$particles.global_rotation = shot_rotation
	$particles.emitting = true
