extends CharacterBody3D

@export var cam:Camera3D
@export var collision:CollisionShape3D
@export var squash:Node3D
@export var standCheck:ShapeCast3D
@export var multSync:MultiplayerSynchronizer

@export_subgroup("Random crap")
@export var slide_cooldown:Timer
#@onready var worldRoot = get_tree().get_first_node_in_group("world root")

var walking = false
var crouching = false
var uncrouch = false
var airborn = false

var sense = 0.002

#consts
const SPEED = 5
const SPRINT_MULT = 1.8
const CROUCH_MULT = 0.8
const FRIC = 15.0
const RAY_LENGTH = 1000
const ACC = 40.0
const SLIDE_BOOST = 15
const MAX_SPEED = 15


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#multSync
	multSync.set_multiplayer_authority(name.to_int())
	
	if multSync.get_multiplayer_authority() != multiplayer.get_unique_id(): return

func _physics_process(delta: float) -> void:
	if multSync.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if_land()
	
	#Deal with crouch
	if uncrouch and !standCheck.is_colliding():
		uncrouch = false
		end_crouch()
	
	#move
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if crouching:
		direction *= CROUCH_MULT
	elif !walking:
		direction *= SPRINT_MULT
	
	#physics
	if not is_on_floor(): #gravity
		velocity += get_gravity() * delta
	
	if direction and is_on_floor():
		velocity = velocity.move_toward(Vector3(direction.x * SPEED, velocity.y, direction.z * SPEED), ACC*delta)
	elif direction:
		velocity = velocity.move_toward(Vector3(direction.x * SPEED, velocity.y, direction.z * SPEED), ACC/2*delta)
	if is_on_floor():
		velocity = velocity.move_toward(
			Vector3(0, velocity.y, 0),
			FRIC * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector3(0, velocity.y, 0),
			FRIC/4 * delta
		)
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if multSync.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sense)
		cam.rotate_x(-event.relative.y * sense)
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-75), deg_to_rad(75))

func _unhandled_key_input(event: InputEvent) -> void:
	if multSync.get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if event.is_action("walk"):
		if event.is_action_pressed("walk") and not crouching:
			walking = true
		elif event.is_action_released("walk"):
			walking = false
	
	elif event.is_action("crouch"):
		if event.is_action_pressed("crouch"):
			uncrouch = false
			start_crouch()
		if event.is_action_released("crouch"):
			end_crouch()
	
	elif event.is_action_pressed("jump"):
		if is_on_floor():
			jump()

func start_crouch():
	if crouching: return
	crouching = true
	
	collision.shape.height = 0.9
	squash.scale.y = 0.5
	standCheck.position.y += .45
	cam.position.y -= .45
	position.y -= collision.shape.height/2
	
	if is_on_floor():
		slide()

func end_crouch():
	if not crouching: return
	elif standCheck.is_colliding():
		uncrouch = true
		return
	
	crouching = false
	collision.shape.height = 1.8
	squash.scale.y = 1
	standCheck.position.y -= .45
	cam.position.y += .45
	position.y += collision.shape.height/4

func slide():
	if !slide_cooldown.is_stopped(): return
	slide_cooldown.start()
	
	if Vector2(velocity.x, velocity.z).length() > MAX_SPEED: return
	
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction = input_dir.rotated(-rotation.y)
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	horizontal_velocity = direction*(horizontal_velocity.length()+SLIDE_BOOST) #Change all momentum to go in current direction
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y

func jump():
	velocity.y += 7.8

func if_land():
	if is_on_floor() and !airborn: return
	elif !is_on_floor():
		airborn = true
		return
		
	#Landed
	airborn = false
	
	if crouching and slide_cooldown.is_stopped():
		slide()
	
	if Input.is_action_pressed("jump"):
		jump()
