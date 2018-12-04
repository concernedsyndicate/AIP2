extends Node

enum WEAPON{RAIL, ROCKET}

var skin = 0

var health = 100
var armor = 0

var railgun_ammo = 5
var rocket_ammo = 5

var current_weapon setget set_weapon

func _ready():
	skin = randi()%5
	$"../Sprite".frame = skin*2

func set_weapon(weapon):
	current_weapon = weapon
	$"../Sprite".frame = skin*2 + int(weapon)

func damage(amount):
	health -= max(amount - armor, 0)
	armor = max(armor - amount/2, 0)