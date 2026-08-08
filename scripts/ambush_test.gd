extends Node2D

@onready var ambush_enemy: Area2D = $AmbushEnemy


func _ready() -> void:
	ambush_enemy.spawn_from_side(-1)
