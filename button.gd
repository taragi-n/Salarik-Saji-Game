extends Button

func _ready():
	update_teks_tombol()

func _on_pressed():
	var locale_sekarang = TranslationServer.get_locale()
	
	if locale_sekarang.begins_with("id"):
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("id")
	
	update_teks_tombol()
	var kartu = get_parent().get_node_or_null("KartuRoh")
	if kartu:
		kartu.setup_kartu() 
		
	get_parent().update_tampilan_ui()
	print("ganti")

func update_teks_tombol():
	var locale = TranslationServer.get_locale()
	if locale.begins_with("id"):
		text = "Bahasa: Indonesia"
	else:
		text = "Language: English"
