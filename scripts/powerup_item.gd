class_name PowerupItem
extends Area2D

signal collected(powerup_type: int, player: Node)

enum PowerupType {
	BOMB,
	UNLIMITED_AMMO,
	TRIPLE_SHOT,
}

const TEXTURES := {
	PowerupType.BOMB: preload("res://assets/sprites/powerups/bomb.png"),
	PowerupType.UNLIMITED_AMMO: preload("res://assets/sprites/powerups/unlimited_ammo.png"),
	PowerupType.TRIPLE_SHOT: preload("res://assets/sprites/powerups/triple_shot.png"),
}

@export var fall_speed := 105.0
@export var ground_y := 505.0
@export var lifetime_on_ground := 10.0

var powerup_type: PowerupType = PowerupType.BOMB
var landed := false
var hover_time := 0.0
var ground_center_y := 0.0


func _ready() -> void:
	add_to_group("powerup_items")
	apply_visual()


func setup(new_type: PowerupType) -> void:
	powerup_type = new_type
	apply_visual()


func apply_visual() -> void:
	if not is_node_ready():
		return
	$Sprite2D.texture = TEXTURES[powerup_type]


func _process(delta: float) -> void:
	$Sprite2D.rotation += delta * 1.6

	if not landed:
		global_position.y += fall_speed * delta
		if global_position.y >= ground_y:
			landed = true
			ground_center_y = ground_y
			global_position.y = ground_y
			$DespawnTimer.start(lifetime_on_ground)
		return

	hover_time += delta
	global_position.y = ground_center_y + sin(hover_time * TAU * 2.0) * 5.0


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	collected.emit(powerup_type, body)
	queue_free()


func _on_despawn_timer_timeout() -> void:
	queue_free()
