extends Node2D

var collectible

func _ready():
	get_tree().create_timer(5).connect("timeout", self, "respawn")

func respawn():
	get_parent().add_child(collectible)
	queue_free()