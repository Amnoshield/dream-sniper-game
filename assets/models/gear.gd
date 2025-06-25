extends Node3D


@export var rotation_speed :float = 0


func _ready() -> void:
	$StaticBody3D.constant_angular_velocity.y = rotation_speed


func _process(delta: float) -> void:
	$Cylinder.rotate(Vector3(0,1,0), rotation_speed*delta)
