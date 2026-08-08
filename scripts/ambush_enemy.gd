extends Area2D

signal destroyed(score_value: int)

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

@export var wait_duration: float = 2.0
@export var dash_speed: float = 680.0
@export var score_value: int = 350
@export var damage: int = 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var warning_light: Polygon2D = $WarningLight

var state := "waiting"
var wait_time := 0.0
var dash_direction := Vector2.RIGHT
var is_destroying := false


func _ready() -> void:
	add_to_group("enemies")
	process_mode = Node.PROCESS_MODE_PAUSABLE


func spawn_from_side(side: int) -> void:
	# Start just inside the play area so the player can see the warning phase.
	global_position = Vector2(135.0 if side < 0 else 1017.0, 240.0)
	dash_direction = Vector2.RIGHT if side < 0 else Vector2.LEFT
	sprite.flip_h = side >= 0
	state = "waiting"
	wait_time = wait_duration
	warning_light.show()


func _process(delta: float) -> void:
	if is_destroying:
		return

	if state == "waiting":
		wait_time -= delta
		var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.012) * 0.35
		warning_light.modulate.a = pulse
		sprite.position.y = sin(Time.get_ticks_msec() * 0.008) * 2.0
		if wait_time <= 0.0:
			begin_dash()
		return

	global_position += dash_direction * dash_speed * delta
	sprite.rotation = dash_direction.angle()

	if global_position.x < -140.0 or global_position.x > 1292.0:
		queue_free()


func begin_dash() -> void:
	state = "dashing"
	warning_light.hide()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		dash_direction = global_position.direction_to(player.global_position)
	sprite.rotation = dash_direction.angle()


func destroy(award_points := true) -> void:
	if is_destroying:
		return
	is_destroying = true
	if award_points:
		destroyed.emit(score_value)
	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	explosion.scale = Vector2.ONE * 1.1
	if get_tree().current_scene.has_method("shake_camera"):
		get_tree().current_scene.call("shake_camera", 6.0, 0.2)
	if get_tree().current_scene.has_method("spawn_kill_feedback"):
		get_tree().current_scene.call("spawn_kill_feedback", global_position, score_value if award_points else 0)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_destroying:
		return
	area.queue_free()
	destroy()


func _on_body_entered(body: Node2D) -> void:
	if is_destroying:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	destroy(false)
