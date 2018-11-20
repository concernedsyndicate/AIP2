extends KinematicBody2D

onready var ray = $Railcast
onready var sight = $Laser
onready var camera = $Camera2D

var target_camera = Vector2()
var target_zoom = Vector2(1, 1)

const RAIL_COOLDOWN = 1.5

export (int) var speed
export (float) var rotation_speed

var health = 100 setget set_health
var cooldown = 0

var velocity = Vector2()
var rotation_dir = 0

func _process(delta):
	process_move(delta)
	process_attack(delta)
	process_camera(delta)
	$UI.rotation = -rotation

func process_move(delta):
	velocity.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	velocity.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))

	rotation = (get_global_mouse_position() - global_position).angle()
	
	move_and_slide(velocity.normalized() * speed)

func process_attack(delta):
	cooldown -= delta
	$Sprite.modulate.r = 1 - clamp(cooldown, 0, RAIL_COOLDOWN) / RAIL_COOLDOWN
	$Sprite.modulate.g = $Sprite.modulate.r

func process_camera(delta):
	target_camera = (get_local_mouse_position()/camera.zoom/5).clamped(400)
	var dist = clamp(camera.position.length()/70, 1, 1.3)
	target_zoom = Vector2(dist, dist)
	
	camera.position += (target_camera - camera.position) * delta
	camera.zoom += (target_zoom - camera.zoom) * delta
	
	var length = (global_position - ray.get_collision_point()).length()
	sight.region_rect.position.x -= 1
	sight.region_rect.size.x = length
	sight.position.x = length/2

func set_health(h):
	health = h
	$UI/Health.text = str(h)
	$UI/Health/Bar.value = h
	
	if health <= 0:
		get_tree().change_scene("res://Scenes/GameOver.tscn")

func _input(event):
	if cooldown <= 0 and event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		cooldown = RAIL_COOLDOWN
		
		var bullet = preload("res://Nodes/RailgunBullet.tscn").instance()
		get_parent().add_child(bullet)
		bullet.position = position
		bullet.rotation = rotation
		
		if ray.is_colliding():
			if ray.get_collider().is_in_group("monsters"): ray.get_collider().kill()
			bullet.line.points[1].x = (global_position - ray.get_collision_point()).length()