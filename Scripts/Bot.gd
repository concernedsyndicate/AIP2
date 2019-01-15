extends Area2D

onready var starting_position = position
onready var bounds = $"../../MapBoundary".bounds
onready var navigation = $"../..".navigation
onready var character = $Character
onready var state = $State
onready var game = $"../.."

const MAX_SPEED = 300
const CHASING_SPEED = 359
const RADIUS = 32
const DAMAGE_RATE = 0.3

var velocity = Vector2(0,0)
var neighbors = []
var is_damaging = false
var flocked_before = false
var current_obstacle = {}
var speed = 1

var target

var arrived_at_path_end = false

var color

func _ready():
	rotation = randf() * PI*2
	color = [Color.red, Color.blue, Color.green, Color.yellow][get_index()]

func _process(delta):
	state.process(delta)
	
	velocity = (velocity + next_step(delta)).clamped(MAX_SPEED)
	
	position += velocity * delta
	call_deferred("declip")
	rotation = velocity.angle()
	
	update()

func next_step(delta):
#	return wander()
	if arrived_at_path_end:
		arrived_at_path_end = false
		target = null
	
	return follow_path()

func seek(target_position):
	var desired_velocity = (target_position - position).normalized() * MAX_SPEED
	return desired_velocity - velocity

const PANIC_DISTANCE_SQ = pow(300, 2)

func flee(target_position):
	if (target_position - position).length_squared() > PANIC_DISTANCE_SQ:
		return Vector2(0,0)
	
	var desired_velocity = (position - target_position).normalized() * MAX_SPEED
	return desired_velocity - velocity

enum Deceleration{SLOW = 3, NORMAL = 2, FAST = 1}
const DECELERATION_TWEAKER = 0.3

func arrive(target_position, deceleration):
	var to_target = target_position - position
	var dist = to_target.length()
	
	if dist > 0:
		var speed = dist / deceleration * DECELERATION_TWEAKER
		speed = clamp(speed, 0, MAX_SPEED)
		
		var desired_velocity = to_target * speed / dist
		return desired_velocity - velocity
	
	return Vector2(0,0)

func pursuit():
	var to_target = target.position - position
	var heading = velocity.normalized()
	var relative_heading = heading.dot(target.velocity.normalized())
	
	if to_target.dot(heading) > 0 and relative_heading < -0.95: return seek(target.position)
	
	var look_ahead_time = to_target.length() / (MAX_SPEED + target.speed)
	return seek(target.position + target.velocity * look_ahead_time)

func evade():
	var to_target = target.position - position
	var look_ahead_time = to_target.length() / (MAX_SPEED + target.speed)
	return flee(target.position + target.velocity * look_ahead_time)

const MIN_DETECTION_BOX_LENGTH = 200
const BRAKING_WEIGHT = 0.2

func declip():
	if !get_tree(): return
	
	var move = Vector2()
	
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if (obstacle.position - position).length() <= obstacle.radius + RADIUS:
			move -= (obstacle.position - position).normalized() * ((obstacle.radius + RADIUS) - (obstacle.position - position).length())
	
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster != self and (monster.position - position).length() <= monster.RADIUS + RADIUS:
#			monster.position += (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
			move -= (monster.position - position).normalized() * ((monster.RADIUS + RADIUS) - (monster.position - position).length())
	
	position += move

const WANDER_RADIUS = pow(80, 2)
const WANDER_TOLERANCE = pow(16, 2)

onready var wander_target = position
onready var previous_target = position

func wander():
	if (position - wander_target).length_squared() <= WANDER_TOLERANCE:
		var possible = []
		for point in navigation:
			if (point - position).length_squared() <= WANDER_RADIUS:
				possible.append(point)
				possible.append(point)
				if point == previous_target : #rzadziej robi "w tył zwrot"
					possible.pop_back()
		
		previous_target = wander_target
		wander_target = possible[randi() % possible.size()]
	
	return seek(wander_target)

var path = []

func astar(target, source = closest_v(position)): # source = closest_v(position) # wez najblizszy pkt, a przy liczeniu sceizki go wyrzuc by sie nie cofac
	if !visible: return ###debug
	var W = navigation.duplicate()
	
	var to_visit = []
	var visited = {}
	
	to_visit.append({pos = source, G = 0, H = abs(source.x - target.x) + abs(source.y - target.y), previous = null})
	
	var cur
	while !to_visit.empty():
		cur = to_visit[0]
		for p in to_visit:
			if p.G + p.H < cur.G + cur.H:
				cur = p
		
		if cur.pos == target: break
		
		to_visit.erase(cur)
		
		add_astar_neigbor(cur, target, Vector2(64, 0), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, 0), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(0, 64), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(0, -64), 10, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(64, 64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(64, -64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, -64), 14, to_visit, visited)
		add_astar_neigbor(cur, target, Vector2(-64, 64), 14, to_visit, visited)
	
	path.clear()
	while cur.previous:
		path.append(cur.pos)
		cur = cur.previous
	path.invert()
	
	$Path.path = path
	$Path.update()

func add_astar_neigbor(point, target, add_pos, add_g, to_visit, visited):
	var p = point.pos + add_pos
	
	if p in navigation and not p in visited:
		visited[p]= true
		to_visit.append({pos = p, G = point.G + add_g, H = abs(p.x - target.x) + abs(p.y - target.y), previous = point})

onready var follow_target = position

const FOLLOW_PATH_TOLERANCE = pow(3, 2)

func follow_path():
	if !path.empty():
		follow_target = path.front()
		if (position - path.front()).length_squared() <= FOLLOW_PATH_TOLERANCE:
			path.pop_front()
			if path.empty():
				arrived_at_path_end = true
				return seek(position)
			
			follow_target = path.front()
		
		return seek(follow_target)
	else:
		return seek(position)

func closest_v(pos):
	var base = [pos.snapped(Vector2(64,64))]
	base.append(base[0] + Vector2(64,0))
	base.append(base[0] + Vector2(0,64))
	base.append(base[0] + Vector2(64,64))
	
	var valid = []
	
	for vec in navigation:
		if vec in base:
			valid.append(vec)
	
	for vec in base:
		if vec in valid: return vec
	
	printerr("Bot poza nawigacją (wtf co on tam robi)")

func get_closest_bot():
	var min_dist = INF
	var min_bot
	
	for bot in game.bots.get_children():
		if bot != self:
			var dist = (bot.position - position).length_squared()
			if dist < min_dist:
				min_dist = dist
				min_bot = bot
	
	return min_bot

func shoot_railgun(at):
	var bullet = preload("res://Nodes/RailgunBullet.tscn").instance()
	character.railgun_cooldown = 2
	character.railgun_ammo -= 1
	rotation = (at.position - position).angle()
	
	bullet.position = position
	bullet.rotation = rotation
	bullet.attacker = self
	bullet.modulate = color

	$"../..".add_child(bullet)

func shoot_missile(at):
	var bullet = preload("res://Nodes/Missile.tscn").instance()
	character.rocket_cooldown = 0.5
	character.rocket_ammo -= 1
	rotation = (at.position - position).angle()
	
	bullet.position = position
	bullet.rotation = rotation
	bullet.attacker = self
	bullet.modulate = color

	$"../..".add_child(bullet)