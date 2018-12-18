extends Area2D

onready var starting_position = position
onready var target = null
onready var bounds = $"../../MapBoundary".bounds
onready var navigation = $"../..".navigation
onready var character = $Character

enum {EXPLORE, ATTACK, FLEE, RESTOCK, HEAL}
var state = HEAL

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

var arrived_at_path_end = false

func _ready():
	rotation = randf() * PI*2

func _process(delta):
	match state:
		EXPLORE:
			if !target:
				target = navigation[randi() % navigation.size()]
				print(self.name, " going to ", target)
				dijxtra(target)
		HEAL:
			if !target:
				var healths = get_tree().get_nodes_in_group("health")
				target = closest_v(healths[randi() % healths.size()].position)
				print(self.name, " going to ", target)
				dijxtra(target)
		RESTOCK:
			if !target:
				var ammos = get_tree().get_nodes_in_group("ammo")
				target = closest_v(ammos[randi() % ammos.size()].position)
				print(self.name, " going to ", target)
				dijxtra(target)
		
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

func dijxtra(target, source = closest_v(position)): # source = closest_v(position) # wez najblizszy pkt, a przy liczeniu sceizki go wyrzuc by sie nie cofac
	var D = {}
	var previous = {}
	
	for v in navigation:
		D[v] = INF # distance(source, v)
		previous[v] = null
	
	D[source] = 0
	var W = navigation.duplicate()
	
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
				
		W.remove(desired_index)
		for x in range(-1, 2): # dla kazdego z 8 sasiadow v wierzcholka u z W
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				
				var v = u + Vector2(x * 64, y * 64)
				if v in navigation:
					if D[v] > D[u] + (u - v).length_squared():  # relax(u, v), length_squared ew. do podmienienia na stale wartosci
#						print (u.distance_to(v))
						D[v] = D[u] + (u - v).length_squared()
						previous[v] = u
					
					if v == target and previous[v] != previous[target]: print("CO") # nie ma prawa sie tak dziać
	
	var new_path = []
	var u = target
	while u != source:
		new_path.push_front(u)
		u = previous[u]
		
	path = new_path

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
	var base = pos.snapped(Vector2(64,64))
#	var v = (pos + Vector2(32, 32)).snapped(Vector2(64, 64))
#	if v in navigation:
#		return v
	if base in navigation: # lewy gorny
		return base
	
	base += Vector2(64,0)
	if base in navigation: # prawy gorny
		return base
	
	base += Vector2(0,64)
	if base in navigation: # prawy dolny
		return base
	
	base -= Vector2(64,0)
	if base in navigation: # lewy dolny
		return base
	
	print("Bot poza nawigacją")