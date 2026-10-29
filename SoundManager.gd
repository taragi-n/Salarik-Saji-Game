extends Node

var players: Array = []
var num_players: int = 8

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(num_players):
		var p = AudioStreamPlayer.new()
		add_child(p)
		p.bus = "SFX"
		players.append(p)

func play_sfx(stream: AudioStream):
	for p in players:
		if not p.playing:
			p.stream = stream
			p.bus = "SFX"
			p.play()
			return
