extends Area2D

onready var starting_position = position
onready var target = position
onready var bounds = $"../../MapBoundary".bounds
onready var navigation = $"../..".navigation

enum STATE{EXPLORE, ATTACK, FLEE, RESTOCK, HEAL}
var state = EXPLORE

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

var not_smart_solution = true

func _ready():
	rotation = randf() * PI*2

func _process(delta):
	
	if not_smart_solution:
		not_smart_solution = false
		target = navigation[randi() % navigation.size()]
		print(target)
		dijxtra(target)
	
	velocity = (velocity + next_step(delta)).clamped(MAX_SPEED)
	
	position += velocity * delta
	call_deferred("declip")
	rotation = velocity.angle()
	
	if is_damaging:
		target.health -= 1
	
	update()

func next_step(delta):
#	return wander()
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

func dijxtra(target, graph = navigation.duplicate(), source = starting_position): # source = closest_v(position)
	var D = {}
	var previous = {}
	
	for v in graph:
		D[v] = INF # distance(source, v)
		previous[v] = null
	
	D[source] = 0
	var W = graph
	
	while !W.empty():
		# u = wierzcholek z W taki, że D[u] jest najmniejsza
		var u = W.front()
		var index = 0
		var desired_index = 0
		
		for temp in W:
			if D[temp] < D[u]:
				u = temp
				desired_index = index
			index = index + 1
				
#		W.pop_front() # nie
		W.remove(desired_index)
		for x in range(-1, 2): # dla kazdego sasiada v wierzcholka u z W
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				
				var v = u + Vector2(x * 64, y * 64)
				if v in navigation:
					if D[v] >= D[u] + (u - v).length_squared():  # relax(u, v), distance_to do podmienienia na stale wartosci
#						print (u.distance_to(v))
						D[v] = D[u] + (u - v).length_squared() #length_squared jest szybsze
						previous[v] = u
					
#					if v == target: print(previous[v], previous[target])
	
	var new_path = []
	var u = target
	while u != source:
		new_path.push_front(u)
		u = previous[u]
		
	path = new_path

onready var follow_target = position

func follow_path():
	if !path.empty():
		follow_target = path.front()
		if (position - path.front()).length_squared() <= WANDER_TOLERANCE:
			path.pop_front()
			if path.empty():
				return seek(position)
			
			follow_target = path.front()
		
		return seek(follow_target)
	else:
		return seek(position)