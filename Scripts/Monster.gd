extends Area2D

onready var target = get_tree().get_nodes_in_group("player")[0]
onready var bounds = $"../../MapBoundary".bounds

const MAX_SPEED = 300
const CHASING_SPEED = 359
const RADIUS = 32
const DAMAGE_RATE = 0.3

var velocity = Vector2(0,0)
var neighbors = []
var is_damaging = false
var flocked_before = false
var current_obstacle = {}

func _ready():
	rotation = randf() * PI*2
	
	var theta = randf() * 2*PI
	wander_target = Vector2(WANDER_RADIUS * cos(theta), WANDER_RADIUS * sin(theta))

func _process(delta):
	update_neighbor_list()
	velocity = (velocity + next_step(delta)).clamped(max_speed())
	
	position += velocity * delta
	call_deferred("declip")
	rotation = velocity.angle()
	
	if is_damaging:
		target.health -= 1
	
	update()

func next_step(delta):
	return flock(delta) + obstacle_avoidance() + wall_avoidance()
#	return _hide() + obstacle_avoidance()
#	return wander()

func seek(target_position):
	var desired_velocity = (target_position - position).normalized() * max_speed()
	return desired_velocity - velocity

const PANIC_DISTANCE_SQ = pow(300, 2)

func flee(target_position):
	if (target_position - position).length_squared() > PANIC_DISTANCE_SQ:
		return Vector2(0,0)
	
	var desired_velocity = (position - target_position).normalized() * max_speed()
	return desired_velocity - velocity

enum Deceleration{SLOW = 3, NORMAL = 2, FAST = 1}
const DECELERATION_TWEAKER = 0.3

func arrive(target_position, deceleration):
	var to_target = target_position - position
	var dist = to_target.length()
	
	if dist > 0:
		var speed = dist / deceleration * DECELERATION_TWEAKER
		speed = clamp(speed, 0, max_speed())
		
		var desired_velocity = to_target * speed / dist
		return desired_velocity - velocity
	
	return Vector2(0,0)

func pursuit():
	var to_target = target.position - position
	var heading = velocity.normalized()
	var relative_heading = heading.dot(target.velocity.normalized())
	
	if to_target.dot(heading) > 0 and relative_heading < -0.95: return seek(target.position)
	
	var look_ahead_time = to_target.length() / (max_speed() + target.speed)
	return seek(target.position + target.velocity * look_ahead_time)

func evade():
	var to_target = target.position - position
	var look_ahead_time = to_target.length() / (max_speed() + target.speed)
	return flee(target.position + target.velocity * look_ahead_time)

const MIN_DETECTION_BOX_LENGTH = 200
const BRAKING_WEIGHT = 0.2

func obstacle_avoidance():
	var speed = 100 #TODO
	var detection_box_length = MIN_DETECTION_BOX_LENGTH + (speed/max_speed()) * MIN_DETECTION_BOX_LENGTH
	
	var dist_to_closest_ip = INF
	var closest_intersecting_obstacle
	var local_pos_of_closest_obstacle = Vector2()
	
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if (obstacle.position - position).length_squared() < detection_box_length * detection_box_length:
			var local_pos = (obstacle.position - position).rotated(-rotation)
			
			if local_pos.x >= 0:
				var expanded_radius = obstacle.radius + RADIUS
				
				if abs(local_pos.y) < expanded_radius:
					var cX = local_pos.x
					var cY = local_pos.y
					var sqrt_part = sqrt(expanded_radius*expanded_radius - cY*cY)
					
					var ip = cX - sqrt_part
					if ip <= 0: ip = cX + sqrt_part
					
					if ip < dist_to_closest_ip:
						dist_to_closest_ip = ip
						closest_intersecting_obstacle = obstacle
						local_pos_of_closest_obstacle = local_pos
	
	var steering_force = Vector2()
	if closest_intersecting_obstacle:
		var multiplier = 1.0 + (detection_box_length - local_pos_of_closest_obstacle.x) / detection_box_length
		steering_force.y = (closest_intersecting_obstacle.radius - local_pos_of_closest_obstacle.y) * multiplier
		steering_force.x = (closest_intersecting_obstacle.radius - local_pos_of_closest_obstacle.x) * BRAKING_WEIGHT
		
#		avoided = true #powoduje mniejsze skakanie obrotu, ale tak meh
#	elif !avoided:
#		pass #meh meh
##		return pursuit(target.position)
#	else:
#		avoided = false
	
	return steering_force.rotated(rotation)

func wall_avoidance():
	var feelers = [$Feelers/LeftFeeler.global_position, $Feelers/RightFeeler.global_position]
	var steering_force = Vector2()
	
	for feeler in feelers:
		var feeler_position = (feeler - global_position).normalized()
		
		if feeler.x < bounds.position.x:
#			var inside = (feeler - get_intersection_point(bounds.position,
#				bounds.position + Vector2(0, bounds.size.y), position, feeler)).length()
			steering_force += feeler_position.reflect(Vector2.UP) * -feeler.x
		
		elif feeler.x > bounds.position.x + bounds.size.x:
#			var inside = (feeler - get_intersection_point(bounds.position + Vector2(bounds.size.x, 0),
#				bounds.position + bounds.size, position, feeler)).length()
			steering_force += feeler_position.reflect(Vector2.UP) * feeler.x
		
		elif feeler.y < bounds.position.y:
#			var inside = (feeler - get_intersection_point(bounds.position,
#				bounds.position + Vector2(bounds.size.x, 0), position, feeler)).length()
			steering_force += feeler_position.reflect(Vector2.RIGHT) * -feeler.y
		
		elif feeler.y > bounds.position.y + bounds.size.y:
#			var inside = (feeler - get_intersection_point(bounds.position + Vector2(0, bounds.size.y),
#				bounds.position + bounds.size, position, feeler)).length()
			steering_force += feeler_position.reflect(Vector2.RIGHT) * feeler.y
	
#	print(steering_force)
	return steering_force

func declip():
	var move = Vector2()
	
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if (obstacle.position - position).length() <= obstacle.radius + RADIUS:
			move -= (obstacle.position - position).normalized() * ((obstacle.radius + RADIUS) - (obstacle.position - position).length())
	
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster != self and (monster.position - position).length() <= monster.RADIUS + RADIUS:
#			monster.position += (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
			move -= (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
	
	position += move

const WANDER_RADIUS = 16
const WANDER_DISTANCE = 256
const WANDER_JITTER = 16

var wander_target

func wander():
	wander_target = (wander_target + Vector2((-1 + randf()*2) * WANDER_JITTER, (-1 + randf()*2) * WANDER_JITTER)).normalized()
	wander_target *= WANDER_RADIUS
	var target_local = wander_target + Vector2(WANDER_DISTANCE, 0)
	return target_local.rotated(rotation)

const DISTANCE_FROM_BOUNDARY = 100

func get_hiding_position(obstacle):
	var dist_away = obstacle.radius + DISTANCE_FROM_BOUNDARY
	var towards_obstacle = (obstacle.position - target.position).normalized()
	return towards_obstacle * dist_away + obstacle.position

const MAX_HIDING = 3
const MAX_OBSTACLES_AVOIDED = 2

func _hide(delta):
	var dist_to_closest = INF
	var best_hiding_spot
	
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		var hiding_spot = get_hiding_position(obstacle)
		var dist = (hiding_spot - position).length_squared()
		
		if dist < dist_to_closest:
			dist_to_closest = dist
			best_hiding_spot = hiding_spot

	if best_hiding_spot and (!current_obstacle.has(best_hiding_spot) or current_obstacle[best_hiding_spot] < MAX_HIDING):
		if current_obstacle.empty() or best_hiding_spot != current_obstacle.keys()[0]:
			if current_obstacle.size() >= MAX_OBSTACLES_AVOIDED: current_obstacle.clear()
			current_obstacle[best_hiding_spot] = 0
		else:
			current_obstacle[best_hiding_spot] += delta
		
		return arrive(best_hiding_spot, FAST)
	else: return evade()

const NEIGHBOR_RANGE_SQ = pow(330, 2)

func update_neighbor_list():
	neighbors.clear()
	
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster != self and (monster.position - position).length_squared() < NEIGHBOR_RANGE_SQ:
			neighbors.append(monster)

func separation():
	var steering_force = Vector2()
	
	for neighbor in neighbors:
		var to_other = position - neighbor.position
		steering_force += to_other.normalized() / to_other.length()
	
	return steering_force

func alignment():
	var average_heading = Vector2()
	
	if !neighbors.empty():
		for neighbor in neighbors:
			average_heading += neighbor.velocity.normalized()
		
		average_heading /= neighbors.size()
		average_heading -= velocity.normalized()
	
	return average_heading

func cohesion():
	if !neighbors.empty():
		var center_position = Vector2()
		
		for neighbor in neighbors:
			center_position += neighbor.position
		
		center_position /= neighbors.size()
		return seek(center_position)
	
	return Vector2()

const FLEE_DIST = 200
const RISK_THRESHOLD = 3
const RISK_MAX = 4

var risk_timer = 0

func flock(delta):
	var steering_force = separation() * 2000 + alignment() + cohesion() * 0.1
	
	if neighbors.size() >= 2 or flocked_before or (!neighbors.empty() and neighbors[0].flocked_before):
		flocked_before = true
		steering_force += seek(target.position)
	else:
		if (target.position - position).length() > FLEE_DIST:
			steering_force += wander() + _hide(delta)
		else:
			steering_force += wander() + _hide(delta) + flee(target.position)
		
		risk_timer += delta
		if risk_timer > RISK_THRESHOLD:
			steering_force += wander()*2
			
			if risk_timer > RISK_MAX:
				risk_timer = 0
	return steering_force

func _draw():
	if Input.is_key_pressed(KEY_CONTROL):
		draw_set_transform(Vector2(), -rotation, Vector2(1, 1))
		draw_vector(Vector2(0,0), target.position - position, Color(0, 1, 0, 0.3), 5)  # green
#		draw_vector(Vector2(0,0), to_target_heading, Color(0, 0, 1, 0.3), 5)  # blue
		draw_vector(Vector2(0,0), velocity, Color(1, 0, 0, 0.4), 5)  # red

func draw_vector( origin, vector, color, arrow_size ):
	if vector.length_squared() > 1:
		var points = []
		var direction = vector.normalized()
		points.push_back(vector + direction * arrow_size * 2)
		points.push_back(vector + direction.rotated(PI / 2) * arrow_size)
		points.push_back(vector + direction.rotated(-PI / 2) * arrow_size)
		draw_polygon(points, PoolColorArray([color]))
		draw_line(origin, vector, color, arrow_size)

func on_collision(body):
	if body.is_in_group("player"):
		is_damaging = true

func on_decolission(body):
	if body.is_in_group("player"):
		is_damaging = false

func kill():
	queue_free()
	if get_parent().get_child_count() == 1:
		$"../../UI".win()

func max_speed():
	return CHASING_SPEED if flocked_before else MAX_SPEED