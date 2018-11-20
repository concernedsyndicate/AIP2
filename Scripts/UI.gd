extends CanvasLayer

onready var monsters = $"../Monsters"

func _process(delta):
	$ZombieCounter.text = "Zombies left: %d" % [monsters.get_child_count()]

func win():
	$YouWon.visible = true