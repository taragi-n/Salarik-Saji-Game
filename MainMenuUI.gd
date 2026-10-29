extends CanvasLayer

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

@export var canvas_setting: CanvasLayer
@export var canvas_credits: CanvasLayer

@export var btn_id: TextureButton
@export var btn_en: TextureButton

@export var tex_music_on: Texture2D
@export var tex_music_off: Texture2D
@export var tex_sound_on: Texture2D
@export var tex_sound_off: Texture2D

@export var btn_music: TextureButton
@export var btn_sfx: TextureButton

var highscore = 0
@export var label_highscore: Label 

@export var sfx_klik: AudioStream

func _ready():
	load_settings()
	self.visible = true
	if canvas_setting:
		canvas_setting.visible = false
	if canvas_credits:
		canvas_credits.visible = false
		
func save_settings():
	config.set_value("audio", "music_mute", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	config.set_value("audio", "sfx_mute", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	config.set_value("language", "locale", TranslationServer.get_locale())
	
	config.set_value("game", "highscore", highscore)
	
	config.save(SAVE_PATH)
	print("Settings Saved!")

func load_settings():
	var err = config.load(SAVE_PATH)
	
	if err != OK:
		highscore = 0
		_update_label_highscore()
		TranslationServer.set_locale("id")
		_update_tampilan_tombol_bahasa("id")
		return
	
	var lang = config.get_value("language", "locale", "id")
	TranslationServer.set_locale(lang)
	highscore = config.get_value("game", "highscore", 0)
	_update_label_highscore()

	_update_tampilan_tombol_bahasa(lang)

	var m_mute = config.get_value("audio", "music_mute", false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), m_mute)
	_update_visual_audio_button("Music", btn_music, tex_music_on, tex_music_off)

	var s_mute = config.get_value("audio", "sfx_mute", false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), s_mute)
	_update_visual_audio_button("SFX", btn_sfx, tex_sound_on, tex_sound_off)

func _on_id_button_pressed():
	TranslationServer.set_locale("id")
	_update_label_highscore()
	_update_tampilan_tombol_bahasa("id")
	print("Bahasa diubah ke: Indonesia")
	save_settings()
	SoundManager.play_sfx(sfx_klik)

func _on_en_button_pressed():
	TranslationServer.set_locale("en")
	_update_label_highscore()
	_update_tampilan_tombol_bahasa("en")
	print("Bahasa diubah ke: Inggris")
	save_settings()
	SoundManager.play_sfx(sfx_klik)

func _update_tampilan_tombol_bahasa(kode_bahasa: String):
	if kode_bahasa.begins_with("id"):
		btn_id.disabled = true
		btn_en.disabled = false
	elif kode_bahasa.begins_with("en"):
		btn_id.disabled = false
		btn_en.disabled = true
	
	print("Visual Button Update: ID is ", btn_id.disabled, " | EN is ", btn_en.disabled)

func _on_tombol_setting_pressed():
	if canvas_setting:
		canvas_setting.visible = true
		self.visible = false
		SoundManager.play_sfx(sfx_klik)

func _on_tombol_credits_pressed():
	if canvas_credits:
		canvas_credits.visible = true
		self.visible = false
		SoundManager.play_sfx(sfx_klik)

func _on_tombol_back_dari_setting_pressed():
	if canvas_setting:
		canvas_setting.visible = false
		self.visible = true
		SoundManager.play_sfx(sfx_klik)

func _on_tombol_back_dari_credits_pressed():
	if canvas_credits:
		canvas_credits.visible = false
		self.visible = true
		SoundManager.play_sfx(sfx_klik)

func _on_music_button_pressed():
	_toggle_audio_bus("Music", btn_music, tex_music_on, tex_music_off)
	save_settings()
	SoundManager.play_sfx(sfx_klik)
	
func _on_sound_button_pressed():
	_toggle_audio_bus("SFX", btn_sfx, tex_sound_on, tex_sound_off)
	save_settings()
	SoundManager.play_sfx(sfx_klik)
	
func _toggle_audio_bus(bus_name: String, button: TextureButton, tex_on: Texture2D, tex_off: Texture2D):
	var bus_index = AudioServer.get_bus_index(bus_name)
	var is_muted = not AudioServer.is_bus_mute(bus_index)
	
	AudioServer.set_bus_mute(bus_index, is_muted)
	if is_muted:
		button.texture_normal = tex_off
	else:
		button.texture_normal = tex_on

func _update_visual_audio_button(bus_name: String, button: TextureButton, tex_on: Texture2D, tex_off: Texture2D):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		if AudioServer.is_bus_mute(bus_index):
			button.texture_normal = tex_off
		else:
			button.texture_normal = tex_on

func _update_label_highscore():
	if label_highscore:
		label_highscore.text = str(highscore) + " " + tr("KEY_RONDE")
		
func update_highscore(skor_akhir: int):
	if skor_akhir > highscore:
		highscore = skor_akhir
		_update_label_highscore()
		save_settings()
		
func cek_dan_simpan_highscore(skor_baru: int):
	if skor_baru > highscore:
		highscore = skor_baru
		_update_label_highscore()
		save_settings()
		print("Rekor Baru Tercetak: ", highscore)
