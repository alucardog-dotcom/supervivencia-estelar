extends Node2D

const DROP_COUNT := 240
const SCREEN_SIZE := Vector2(1152.0, 648.0)

var rain_active := false
var drops: Array[Vector2] = []
var drop_speeds: Array[float] = []
var random := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	random.seed = 7137
	for index in DROP_COUNT:
		drops.append(Vector2(
			random.randf_range(0.0, SCREEN_SIZE.x),
			random.randf_range(0.0, SCREEN_SIZE.y)
		))
		drop_speeds.append(random.randf_range(520.0, 760.0))
	queue_redraw()


func _process(delta: float) -> void:
	if not rain_active:
		return

	for index in drops.size():
		var drop := drops[index]
		drop.x -= 42.0 * delta
		drop.y += drop_speeds[index] * delta
		if drop.y > SCREEN_SIZE.y + 20.0:
			drop.y = random.randf_range(-80.0, -10.0)
			drop.x = random.randf_range(0.0, SCREEN_SIZE.x)
		drops[index] = drop

	queue_redraw()


func _draw() -> void:
	if not rain_active:
		return

	for drop in drops:
		draw_line(
			drop,
			drop + Vector2(-5.0, 18.0),
			Color(0.52, 0.72, 0.95, 0.62),
			1.0
		)
