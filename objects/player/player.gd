extends CharacterBody3D

@export var cam:Camera3D
@export var collision:CollisionShape3D
@export var squash:Node3D
@export var standCheck:ShapeCast3D
@export var multSync:MultiplayerSynchronizer
@export var ani:AnimationPlayer

@export var hitscan:RayCast3D

@export var wall_hit_effects:Node3D
@export var blood_particles:CPUParticles3D


@export_subgroup("gun stuff")
@export var multiplayer_gun:Node3D
@export var hud_gun:Node3D
@export var gun_ani:AnimationPlayer
@export var scoped_in := false

@export_subgroup("cooldowns")
@export var slide_cooldown:Timer

@export_subgroup("UI")
@export var UI:CanvasLayer
@export var pause:CanvasLayer
@export var health_display:Label
@export var reload_ani:AnimationPlayer
@export var hit_ani:AnimationPlayer


@export_subgroup("sync")
@export var health = 100

@export_subgroup("audio")
@export var shoot_sfx:AudioStreamPlayer3D
@export var kill_sfx:AudioStreamPlayer

@onready var spawn_points = get_tree().get_nodes_in_group("PlayerSpawnPoint")

var walking = false
var crouching = false
var uncrouch = false
var airborn = false

var sense := 0.002
#var scope_mult := 3
var sense_scope_mult := 3

#consts
const SPEED = 5
const SPRINT_MULT = 1.8
const CROUCH_MULT = 0.8
const FRIC = 15.0
const RAY_LENGTH = 1000
const ACC = 40.0
const SLIDE_BOOST = 15
const MAX_SPEED = 15
#fighting stuff
const DAMAGE_HEAD = 100
const DAMAGE_BODY = 40
const KB_OUT = 0
const KB_IN = 10
const MAX_HEALTH = 100

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	multSync.set_multiplayer_authority(name.to_int())
	
	if multSync.get_multiplayer_authority() == multiplayer.get_unique_id():
		cam.current = true
		$Camera3D/eyes.visible = false
		multiplayer_gun.hide()
	else:
		cam.current = false
		UI.hide()
		hud_gun.hide()
		shoot_sfx.volume_db = 0

func _enter_tree() -> void:
	multSync.set_multiplayer_authority(name.to_int())

func _physics_process(delta: float) -> void:
	if !multiplayer.is_server():
		pass
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
	elif event.is_action_pressed("shoot"):
		if !visible:return
		shoot()
	elif event.is_action("scope"):
		if event.is_action_pressed("scope"):
			#cam.fov /= scope_mult
			sense /= sense_scope_mult
			gun_ani.play("scope in")
		else:
			#cam.fov *= scope_mult
			sense *= sense_scope_mult
			gun_ani.play("scope out")

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
	elif event.is_action_pressed("pause"):
		pause.pause()

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

func shoot():
	if reload_ani.is_playing(): return
	play_shoot_sound.rpc()
	
	reload_ani.play("reload")
	
	hitscan.global_rotation.y = global_rotation.y
	hitscan.global_rotation.x = cam.global_rotation.x
	hitscan.global_position = cam.global_position
	
	var direction2D := Vector2(0, 1).rotated(-rotation.y)
	var sideDirection2D := direction2D.rotated(PI/2)
	var kb_angle := Vector3(direction2D.x, 0, direction2D.y).rotated(Vector3(sideDirection2D.x, 0, sideDirection2D.y), -cam.rotation.x)
	
	
	velocity += kb_angle*KB_IN
	
	hitscan.force_raycast_update()
	var hit:Node3D = hitscan.get_collider()
	if !hit: return
	
	if hit.is_in_group("players") and hit.visible:
		blood_particles.global_position = hitscan.get_collision_point()
		blood_particles.global_rotation = hitscan.global_rotation
		blood_particles.emitting = true
		
		var damage = DAMAGE_BODY
		if scoped_in: damage *= 2
		
		hit.take_damage.rpc_id(int(hit.name), damage, kb_angle*KB_OUT)
		if hit.health - DAMAGE_BODY < 0:
			kill_sfx.play()
			hit_ani.play("kill")
		else:
			hit_ani.play("hit")
	else:
		wall_hit_effects.activate.rpc(hitscan.get_collision_point(), hitscan.global_rotation)

@rpc("any_peer", "reliable", "call_remote")
func take_damage(damage:int, knockback:Vector3):
	health -= damage
	velocity += knockback
	
	ani.play("hurt")
	
	if health <= 0:
		die()
	update_health_display()

func die():
	visible = false
	reload_ani.stop()
	
	await get_tree().create_timer(2).timeout
	
	var spawn = spawn_points[randi_range(0, spawn_points.size()-1)]
	global_position = spawn.global_position
	health = 100
	visible = true
	update_health_display()

func update_health_display():
	health_display.text = str(health)+"/"+str(MAX_HEALTH)+"❤️"

@rpc("any_peer", "reliable", "call_local")
func play_shoot_sound():
	shoot_sfx.play()
