extends Node

enum WEAPON{RAIL, ROCKET}

var skin = 0

var health = 100 setget set_health
var armor = 0 setget set_armor

var railgun_ammo = 5
var rocket_ammo = 5

var current_weapon setget set_weapon

func _ready():
	skin = randi()%5
	$"../Sprite".frame = skin*2
	
	$"../Health".value = health
	$"../Armor".value = armor

func set_weapon(weapon):
	current_weapon = weapon
	$"../Sprite".frame = skin*2 + int(weapon)

func set_health(ile):
	health = ile
	$"../Health".value = health
	
func set_armor(ile):
	armor = ile
	$"../Armor".value = armor

func damage(amount):
	self.health -= max(amount - armor, 0)
	self.armor = max(armor - amount/2, 0)