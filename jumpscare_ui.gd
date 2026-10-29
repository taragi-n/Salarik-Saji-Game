extends CanvasLayer

@onready var container = $Node2D
var is_shaking = false
var shake_power = 15.0

func _process(_delta):
	if is_shaking:
		container.position = Vector2(
			randf_range(-shake_power, shake_power),
			randf_range(-shake_power, shake_power)
		)
		print("p")
	else:
		container.position = Vector2.ZERO

func start_jumpscare():
	is_shaking = true
	$AnimJumpScare.play("Jumpscare1")
	await get_tree().create_timer(2.0).timeout
	is_shaking = false
