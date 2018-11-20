tool
extends Node2D

export var radius = 128

func _ready():
	if !Engine.editor_hint:
		$Sprite.scale = Vector2(radius / 128.0, radius / 128.0)
		$CollisionShape2D.shape.radius = radius

func _process(delta): if Engine.editor_hint: update()

func _draw():
	if Engine.editor_hint: draw_circle(Vector2(), radius, Color(0, 1, 0, 0.2))