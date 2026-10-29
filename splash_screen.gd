extends Node2D

@onready var anim_player: AnimationPlayer = $LogoGame/Logo/AnimationPlayer

func _ready() -> void:
	anim_player.play("Splash")
	await anim_player.animation_finished
	anim_player.play("Dc")
	await anim_player.animation_finished
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://ritual_arena.tscn")
