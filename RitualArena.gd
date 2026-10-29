extends Node2D

class_name RitualArena 

static var auto_start: bool = false 


@export_enum("id", "en") var set_bahasa: String = "id"

var semua_slot: Dictionary = {}
var skor_total: int = 0
var jumlah_marah: int = 0
var boleh_hapus: bool = false
var ronde_saat_ini: int = 1

var kartu_terpilih_saat_ini = null
var jarak_antar_kartu = 100
var sedang_menghitung: bool = false

var game_over = false
@onready var jumpscare_ui = $JumpscareUI

@onready var label_skor = $CanvasLayer/PanelInfo/LabelSkor
@onready var label_amarah = $CanvasLayer/HUD/LabelAmarah
@onready var label_ronde = $CanvasLayer/HUD/LabelRonde
@onready var label_nama = $CanvasLayer/PanelInfo/LabelNama

@export var kartu_scene: PackedScene
@onready var posisi_tangan = $CanvasLayer/PosisiTangan

@onready var panel_info = $CanvasLayer/PanelInfo
@onready var label_aturan = $CanvasLayer/PanelInfo/LabelAturan
@onready var stack_posisi = $Stack

@onready var tombol_selesai = $CanvasLayer/HUD/TombolSelesai
@onready var label_tombol = $CanvasLayer/HUD/TombolSelesai/LabelTombol

@onready var canvas_pause = $PauseCanvas
@onready var canvas_game_over = $GameOverCanvas

# --- EXPORT UNTUK DRAG DROP DI INSPECTOR ---
@export var canvas_main_menu: CanvasLayer
@export var canvas_ui: CanvasLayer
@export var grid_slot: Node2D

@export var sfx_klik_play: AudioStream

@export var sfx_klik: AudioStream

var game_dimulai: bool = false

@onready var kamera = $KameraArena
var shake_base: float = 0.0
var shake_burst: float = 0.0

signal klik_di_luar
var deskripsi_aturan: String = ""

var waktu_awal_per_ronde: float = 15.0
var waktu_sisa: float = 15.0
var timer_aktif: bool = false
@onready var bilah_waktu = $CanvasLayer/PanelInfo/BilahWaktu

func _ready():
	canvas_ui.visible = false
	muat_bahasa_dari_save()
	if RitualArena.auto_start:
		RitualArena.auto_start = false
		game_dimulai = true
		game_over = false

		if canvas_main_menu: canvas_main_menu.visible = false
		if canvas_ui: canvas_ui.visible = true
		if grid_slot: grid_slot.visible = true
		
		update_tampilan_ui()
		mulai_ronde_baru()
	else:
		game_dimulai = false
		if canvas_main_menu: canvas_main_menu.visible = true
		if canvas_ui: canvas_ui.visible = false
		if grid_slot: grid_slot.visible = false
	
	if canvas_game_over:
		canvas_game_over.visible = false
	if canvas_pause:
		canvas_pause.visible = false

	print("Bahasa aktif saat ini: ", TranslationServer.get_locale())
	
	kumpulkan_slot_arena()
	tombol_selesai.button_down.connect(_on_tombol_selesai_down)
	tombol_selesai.button_up.connect(_on_tombol_selesai_up)
	
	update_tampilan_ui()

	if has_signal("klik_di_luar"):
		klik_di_luar.connect(_on_arena_klik_di_luar)

func muat_bahasa_dari_save():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		var lang = config.get_value("language", "locale", "id")
		TranslationServer.set_locale(lang)
	else:
		TranslationServer.set_locale(set_bahasa)
	
	print("RitualArena: Bahasa dimuat -> ", TranslationServer.get_locale())

func _on_play_button_pressed():
	SoundManager.play_sfx(sfx_klik_play)
	game_dimulai = true
	game_over = false
	
	canvas_main_menu.visible = false
	
	for child in canvas_ui.get_children():
		if child is Control:
			child.modulate.a = 0.0
	
	grid_slot.modulate.a = 0.0
	
	canvas_ui.visible = true
	grid_slot.visible = true
	
	var tween_in = create_tween().set_parallel(true)
	
	for child in canvas_ui.get_children():
		if child is Control:
			tween_in.tween_property(child, "modulate:a", 1.0, 0.7)
	
	tween_in.tween_property(grid_slot, "modulate:a", 1.0, 0.7)
	
	await tween_in.finished
	
	update_tampilan_ui()
	mulai_ronde_baru()

func on_backmenu_button_pressed():
	SoundManager.play_sfx(sfx_klik)
	get_tree().reload_current_scene()

func _process(delta):
	var total_shake = shake_base + shake_burst
	
	if total_shake > 0:
		shake_burst = lerp(shake_burst, 0.0, delta * 5.0)
		kamera.offset = Vector2(
			randf_range(-total_shake, total_shake), 
			randf_range(-total_shake, total_shake)
		)
	else:
		kamera.offset = Vector2.ZERO
		
	if timer_aktif and not game_over:
		waktu_sisa -= delta
		if waktu_sisa <= 0:
			waktu_sisa = 0
			timer_aktif = false
			pemicu_game_over()
			
	if bilah_waktu:
		bilah_waktu.value = (waktu_sisa / get_waktu_maks_ronde()) * 100

func get_waktu_maks_ronde() -> float:
	var pengurangan = floor(ronde_saat_ini / 5.0) * 2.0
	return max(5.0, waktu_awal_per_ronde - pengurangan)

func guncang_layar(kekuatan: float = 10.0):
	shake_burst = kekuatan

func kumpulkan_slot_arena():
	var grid_node = $GridSlot
	
	for child in grid_node.get_children():
		if child.name.begins_with("Slot_"):
			var parts = child.name.split("_")
			var r = parts[1].trim_prefix("r")
			var c = parts[2].trim_prefix("c")
			
			var kunci_slot = r + "," + c 
			semua_slot[kunci_slot] = child
			
			child.set_meta("ditempati", false)
			child.set_meta("pos_r", int(r))
			child.set_meta("pos_c", int(c))
			child.set_meta("kartu_di_sini", null)

func update_semua_logika_kartu():
	update_efek_suster()
	jumlah_marah = 0
	
	for child in get_children():
		if child.has_method("cek_aturan"):
			if "is_destroying" in child and child.is_destroying:
				continue
			child.cek_aturan()
			if child.marah:
				jumlah_marah += 1
	if jumlah_marah == 1:
		shake_base = 0.7 
	elif jumlah_marah == 2:
		shake_base = 1.2
	elif jumlah_marah >= 3:
		shake_base = 5.0
	else:
		shake_base = 0.0
	if not boleh_hapus:
		tombol_selesai.disabled = ada_kartu_di_tangan()
	else:
		tombol_selesai.disabled = false
		
	update_tampilan_ui()

func update_tampilan_ui():
	if label_skor: label_skor.text = tr("KEY_SKOR") + ": " + str(skor_total)
	if label_amarah:
		label_amarah.text = tr("KEY_ROH_MURKA") + ": " + str(jumlah_marah) + "/3"
		label_amarah.add_theme_color_override("font_color", Color.RED if jumlah_marah > 0 else Color.BLACK)
	if label_ronde: label_ronde.text = tr("KEY_RONDE") + " " + str(ronde_saat_ini)
	
	if jumlah_marah >= 3 and not game_over:
		game_over = true
		pemicu_game_over()
		
	if label_tombol:
		label_tombol.text = tr("KEY_NEXT") if boleh_hapus else tr("KEY_FINISH")
		label_tombol.modulate.a = 0.5 if tombol_selesai.disabled else 1.0
		
	if label_nama and label_aturan:
		if boleh_hapus:
			label_nama.text = tr("KEY_SESI_PEMBERSIHAN")
			label_nama.add_theme_color_override("font_color", Color.RED)
			label_aturan.text = tr("KEY_INFO_HAPUS_KARTU")
			label_aturan.add_theme_color_override("font_color", Color.WHITE)
		elif is_instance_valid(kartu_terpilih_saat_ini):
			if not kartu_terpilih_saat_ini.is_queued_for_deletion():
				label_nama.text = tr("KEY_" + kartu_terpilih_saat_ini.jenis_roh.to_upper())
				label_nama.add_theme_color_override("font_color", Color.YELLOW)
				label_aturan.text = tr("KEY_" + kartu_terpilih_saat_ini.jenis_roh.to_upper() + "_RULES")
				label_aturan.add_theme_color_override("font_color", Color.WHITE)
			else:
				_set_panel_default()
		else:
			_set_panel_default()

func _set_panel_default():
	label_nama.text = tr("KEY_RITUAL_SAJI")
	label_nama.add_theme_color_override("font_color", Color.WHITE)
	
	label_aturan.text = tr("KEY_KLIK_KARTU_DEFAULT")
	label_aturan.add_theme_color_override("font_color", Color.GRAY)

func _on_tombol_selesai_down():
	if label_tombol and not tombol_selesai.disabled:
		label_tombol.position.y += 2

func _on_tombol_selesai_up():
	if label_tombol:
		label_tombol.position.y = 6

func _on_tombol_selesai_pressed():
	if game_over: return
	SoundManager.play_sfx(sfx_klik)
	
	
	if not boleh_hapus:
		if ada_kartu_di_tangan(): return
		
		timer_aktif = false
			
		tombol_selesai.disabled = true
		await proses_hitung_poin_berurutan()
		
		boleh_hapus = true
		tombol_selesai.disabled = false
		update_tampilan_ui()
	else:
		waktu_sisa = get_waktu_maks_ronde()
		if bilah_waktu: bilah_waktu.value = 100
		for child in get_children():
			if child.has_method("cek_aturan") and child.jenis_roh == "GundulPeringis":
				child.slot_terakhir_ronde_lalu = child.slot_saat_ini
		
		for anak in get_children():
			if anak.has_method("cek_aturan") and anak.jenis_roh == "SusterNgesot":
				if anak.slot_saat_ini != null:
					_bebaskan_slot_dari_kartu(anak)
					anak.hancurkan_kartu()
				
		boleh_hapus = false
		ronde_saat_ini += 1
		update_tampilan_ui()
		mulai_ronde_baru()

func ada_kartu_di_tangan() -> bool:
	for child in get_children():
		if child.has_method("cek_aturan"):
			var sedang_hancur = child.get("is_destroying") == true
			
			if child.slot_saat_ini == null and not child.is_queued_for_deletion() and not sedang_hancur:
				return true
	return false

func eksekusi_hapus_kartu(kartu_target):
	if boleh_hapus and skor_total >= 50:
		skor_total -= 50
		if kartu_target.slot_saat_ini != null:
			var slot = kartu_target.slot_saat_ini
			slot.set_meta("ditempati", false)
			slot.set_meta("kartu_di_sini", null)
		
		kartu_target.hancurkan_kartu()
		update_tampilan_ui()
		await get_tree().process_frame
		update_semua_logika_kartu()

func mulai_ronde_baru():
	var jumlah_kartu = 3
	var sudah_ada_genderuwo = apakah_genderuwo_ada()
	var genderuwo_terpilih_ronde_ini = false
	var jumlah_gundul_saat_ini = hitung_jumlah_gundul()
	
	var stack_posisi = $Stack 
	
	sedang_menghitung = true
	
	for i in range(jumlah_kartu):
		var kartu_baru = kartu_scene.instantiate()
		var jenis_pilihan = tentukan_roh_berdasarkan_peluang()
		
		if jenis_pilihan == "Genderuwo":
			if sudah_ada_genderuwo or genderuwo_terpilih_ronde_ini:
				jenis_pilihan = "Pocong"
			else:
				genderuwo_terpilih_ronde_ini = true
		elif jenis_pilihan == "GundulPeringis":
			if jumlah_gundul_saat_ini >= 2:
				jenis_pilihan = "Tuyul"
			else:
				jumlah_gundul_saat_ini += 1
		
		kartu_baru.jenis_roh = jenis_pilihan
		add_child(kartu_baru)
		
		kartu_baru.global_position = stack_posisi.global_position
		kartu_baru.global_rotation = stack_posisi.global_rotation
		
		kartu_baru.setup_kartu()
		
		if kartu_baru.has_node("AnimKartu"):
			kartu_baru.get_node("AnimKartu").play("flip")
			
		susun_ulang_tangan()
		
		await get_tree().create_timer(0.3).timeout 
		
	sedang_menghitung = false
	update_semua_logika_kartu()
	
	waktu_sisa = get_waktu_maks_ronde()
	timer_aktif = true

func tentukan_roh_berdasarkan_peluang() -> String:
	var n = randf()
	var ada_genderuwo = apakah_genderuwo_ada()
	
	if n < 0.05 and not ada_genderuwo:
		return "Genderuwo"
	elif n < 0.10:
		return "Banaspati"
	elif n < 0.18:
		return "Tengkorak"
	elif n < 0.15:
		return "SusterNgesot"
	elif n < 0.32:
		return "Leak"
	elif n < 0.40:
		return "Kuyang"
	elif n < 0.48:
		return "Kunti"
	elif n < 0.56:
		return "SundelBolong"
	elif n < 0.65:
		return "GundulPeringis"
	elif n < 0.85:
		return "Pocong"
	else:
		return "Tuyul"

func apakah_genderuwo_ada() -> bool:
	for child in get_children():
		if child.has_method("cek_aturan"):
			if child.is_queued_for_deletion():
				continue
			if child.jenis_roh == "Genderuwo":
				return true
	return false

func ledakan_banaspati(slot_target):
	guncang_layar(35.0)
	
	var r = slot_target.get_meta("pos_r")
	var c = slot_target.get_meta("pos_c")
	
	for i in range(r - 1, r + 2):
		for j in range(c - 1, c + 2):
			var kunci = str(i) + "," + str(j)
			if semua_slot.has(kunci):
				var slot = semua_slot[kunci]
				
				trigger_kilatan_ledakan(slot)
				
				slot.set_meta("ditempati", false)
				slot.set_meta("kartu_di_sini", null)
				
				for child in get_children():
					if child.has_method("hancurkan_kartu") and child.slot_saat_ini == slot:
						child.slot_saat_ini = null
						child.hancurkan_kartu()
							
	slot_highlight_aktif = null 
	matikan_semua_highlight()
	update_semua_logika_kartu()
	
func trigger_kilatan_ledakan(slot):
	var hl = slot.find_child("Highlight", true, false)
	if hl:
		hl.visible = true
		hl.modulate = Color(3.0, 0.3, 0.1, 1.0)
		
		var tween = create_tween()
		tween.tween_property(hl, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_EXPO)
		tween.finished.connect(func(): 
			hl.modulate = Color8(255, 255, 255, 60)
			
			hl.visible = false
		)
		
func terima_kartu_di_slot(kartu, slot_tujuan):
	kartu.dragging = false 
	
	if kartu.jenis_roh == "Banaspati":
		kartu.slot_saat_ini = slot_tujuan 
		ledakan_banaspati(slot_tujuan)
		
		kartu.queue_free() 
		susun_ulang_tangan()
		update_semua_logika_kartu()
	elif kartu.jenis_roh == "SusterNgesot":
		guncang_layar(35.0)
	else:
		kartu.slot_saat_ini = slot_tujuan
		slot_tujuan.set_meta("ditempati", true)
		slot_tujuan.set_meta("kartu_di_sini", kartu)
		kartu.global_position = slot_tujuan.global_position
		kartu.global_rotation = 0
		update_semua_logika_kartu()
		susun_ulang_tangan()
		
	call_deferred("cek_papan_penuh")
	
func _logika_pasang_kartu_biasa(kartu, slot_tujuan):
	kartu.slot_saat_ini = slot_tujuan
	slot_tujuan.set_meta("ditempati", true)
	slot_tujuan.set_meta("kartu_di_sini", kartu)
	kartu.global_position = slot_tujuan.global_position
	kartu.global_rotation = 0
	update_semua_logika_kartu()
	susun_ulang_tangan()
		
func eksekusi_tengkorak(slot_target):
	guncang_layar(20.0)
	var ditemukan_korban = false
	
	for anak in get_children():
		if anak.has_method("cek_aturan") and anak.slot_saat_ini == slot_target:
			if anak.is_destroying == false and anak.jenis_roh != "Tengkorak":
				anak.hancurkan_kartu()
				ditemukan_korban = true
				print("Tengkorak membakar: ", anak.jenis_roh)
				break
	
	if not ditemukan_korban:
		print("Tengkorak tidak menemukan korban, bakar diri di slot kosong.")
	
	slot_target.set_meta("ditempati", false)
	slot_target.set_meta("kartu_di_sini", null)
	
	await get_tree().process_frame
	update_semua_logika_kartu()

func update_efek_suster():
	for anak in get_children():
		if anak.has_method("cek_aturan"):
			anak.ditenangkan_suster = false
	for anak in get_children():
		if anak.has_method("cek_aturan") and anak.jenis_roh == "SusterNgesot" and anak.slot_saat_ini != null:
			var r = anak.slot_saat_ini.get_meta("pos_r")
			var c = anak.slot_saat_ini.get_meta("pos_c")
			var tetangga = [
				str(r-1) + "," + str(c), str(r+1) + "," + str(c),
				str(r) + "," + str(c-1), str(r) + "," + str(c+1)
			]
			
			for kunci in tetangga:
				if semua_slot.has(kunci):
					var slot_tetangga = semua_slot[kunci]
					for kartu in get_children():
						if kartu.has_method("cek_aturan") and kartu.slot_saat_ini == slot_tetangga:
							kartu.ditenangkan_suster = true

func hitung_jumlah_gundul() -> int:
	var jumlah = 0
	for child in get_children():
		if child.has_method("cek_aturan") and not child.is_queued_for_deletion():
			if child.jenis_roh == "GundulPeringis":
				jumlah += 1
	return jumlah

func tampilkan_info(kartu, teks):
	if kartu_terpilih_saat_ini != null and kartu_terpilih_saat_ini != kartu:
		if is_instance_valid(kartu_terpilih_saat_ini):
			var b = kartu_terpilih_saat_ini.find_child("box")
			if b: b.visible = false
	kartu_terpilih_saat_ini = kartu
	update_tampilan_ui()
	deskripsi_aturan = teks 
	
	label_aturan.text = deskripsi_aturan
	panel_info.visible = true

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		reset_semua_seleksi()
		kartu_terpilih_saat_ini = null
		update_tampilan_ui()
		emit_signal("klik_di_luar")

func reset_semua_seleksi():
	for child in get_children():
		if child.has_method("cek_aturan"):
			var b = child.find_child("select", true, false)
			if b:
				b.visible = false

func pemicu_game_over():
	game_over = true
	jumpscare_ui.visible = true
	
	if canvas_main_menu and canvas_main_menu.has_method("cek_dan_simpan_highscore"):
		canvas_main_menu.cek_dan_simpan_highscore(ronde_saat_ini)
	var pocong_sprite = jumpscare_ui.get_node("PocongJumpscare")
	var mat = pocong_sprite.material as ShaderMaterial
	
	if mat:
		mat.set_shader_parameter("strength", 0.0)
		
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/strength", 30.0, 0.1)
		print("hui")
	var anim_player = jumpscare_ui.get_node("AnimJumpScare") 
	
	if anim_player:
		anim_player.play("Jumpscare1")
		print("DOOR! Pocong muncul.")
		getar_kontinyu(4.0)
		print("Geter")
		shake_base = 5.0
	print("Salarik Saji gagal! Mengulang ritual dalam 3 detik...")
	
	await get_tree().create_timer(4.0).timeout
	if canvas_game_over:
		canvas_game_over.visible = true
	if canvas_ui:
		canvas_ui.visible = false
	
	

func susun_ulang_tangan():
	var kartu_di_tangan = []
	
	for child in get_children():
		if child.has_method("cek_aturan"):
			var sedang_hancur = "is_destroying" in child and child.is_destroying
			
			if child.slot_saat_ini == null and not child.dragging and not child.is_queued_for_deletion() and not sedang_hancur:
				kartu_di_tangan.append(child)

	var jumlah = kartu_di_tangan.size()
	if jumlah == 0: return
	
	kartu_di_tangan.sort_custom(func(a, b): return a.get_index() < b.get_index())

	var pusat_x = posisi_tangan.global_position.x
	var pusat_y = posisi_tangan.global_position.y
	
	var spasi = 100.0
	var lengkungan = 10.0 
	var kemiringan = 0.05 

	for i in range(jumlah):
		var kartu = kartu_di_tangan[i]
		var offset = float(i) - (float(jumlah - 1) / 2.0)
		
		var target_pos = Vector2(pusat_x + (offset * spasi), pusat_y + (pow(offset, 2) * lengkungan))
		var target_rot = offset * kemiringan
		
		if "rotasi_dasar" in kartu:
			kartu.rotasi_dasar = target_rot
		
		var t_move = create_tween().set_parallel(true)
		t_move.tween_property(kartu, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t_move.tween_property(kartu, "global_rotation", target_rot, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
		kartu.z_index = i

func proses_hitung_poin_berurutan():
	sedang_menghitung = true
	var kartu_di_meja = []
	
	for child in get_children():
		if child.has_method("cek_aturan") and child.slot_saat_ini != null:
			kartu_di_meja.append(child)
	kartu_di_meja.sort_custom(func(a, b):
		var r_a = a.slot_saat_ini.get_meta("pos_r")
		var r_b = b.slot_saat_ini.get_meta("pos_r")
		var c_a = a.slot_saat_ini.get_meta("pos_c")
		var c_b = b.slot_saat_ini.get_meta("pos_c")
		
		if r_a != r_b:
			return r_a < r_b 
		return c_a < c_b
	)
	
	for kartu in kartu_di_meja:
		await kartu.animasikan_hitung_poin()
		skor_total += kartu.poin
		update_tampilan_ui()
		
	await get_tree().create_timer(0.5).timeout
	sedang_menghitung = false

func _bebaskan_slot_dari_kartu(kartu):
	if kartu.slot_saat_ini:
		var s = kartu.slot_saat_ini
		s.set_meta("ditempati", false)
		s.set_meta("kartu_di_sini", null)

var slot_highlight_aktif = null

func update_slot_highlight(kartu: Node) -> Node:
	var kartu_posisi = kartu.global_position
	var slot_terdekat = null
	var jarak_terdekat = 100.0 

	for kunci in semua_slot:
		var slot = semua_slot[kunci]
		var jarak = kartu_posisi.distance_to(slot.global_position)
		
		if jarak < jarak_terdekat:
			if kartu.jenis_roh == "Tengkorak":
				slot_terdekat = slot
				jarak_terdekat = jarak
			else:
				var is_slot_sendiri = (kartu.slot_saat_ini == slot)
				if not slot.get_meta("ditempati") or is_slot_sendiri:
					slot_terdekat = slot
					jarak_terdekat = jarak
					
	if slot_highlight_aktif and slot_highlight_aktif != slot_terdekat:
		slot_highlight_aktif.set_highlight(false)

	if slot_terdekat:
		slot_terdekat.set_highlight(true)
		slot_highlight_aktif = slot_terdekat
	else:
		slot_highlight_aktif = null
	
	return slot_terdekat

func matikan_semua_highlight():
	if slot_highlight_aktif:
		slot_highlight_aktif.set_highlight(false)
		slot_highlight_aktif = null

func kelola_seleksi_kartu(kartu_target):
	if kartu_terpilih_saat_ini and is_instance_valid(kartu_terpilih_saat_ini):
		var b_lama = kartu_terpilih_saat_ini.find_child("select", true, false)
		if b_lama: b_lama.visible = false
	
	kartu_terpilih_saat_ini = kartu_target
	
	if kartu_terpilih_saat_ini:
		var b_baru = kartu_terpilih_saat_ini.find_child("select", true, false)
		if b_baru: b_baru.visible = true

func paksa_reset_info():
	kartu_terpilih_saat_ini = null
	reset_semua_seleksi()
	update_tampilan_ui()
	
func _on_arena_klik_di_luar():
	if is_instance_valid(kartu_terpilih_saat_ini):
		var b = kartu_terpilih_saat_ini.find_child("select", true, false)
		if b:
			b.visible = false
	
	kartu_terpilih_saat_ini = null
	update_tampilan_ui()

func update_tombol_lock():
	tombol_selesai.disabled = ada_kartu_di_tangan()

func getar_kontinyu(durasi_total: float):
	var waktu_mulai = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waktu_mulai < durasi_total * 1000:
		Input.vibrate_handheld(500)
		await get_tree().create_timer(0.4).timeout
		
		if not game_over: 
			break

func cek_papan_penuh():
	var jumlah_terisi = 0
	var total_slot = semua_slot.size()
	
	for kunci in semua_slot:
		if semua_slot[kunci].get_meta("ditempati") == true:
			jumlah_terisi += 1
	
	print("Logika Papan: ", jumlah_terisi, "/", total_slot)
	
	if jumlah_terisi >= total_slot:
		print("SISTEM: Papan Terdeteksi Penuh! Memulai Eksekusi...")
		eksekusi_pembersihan_total()
		
func eksekusi_pembersihan_total():
	print("Papan penuh! Melakukan pembersihan ritual...")
	
	skor_total += 150
	
	guncang_layar(25.0)
	
	for child in get_children():
		if child.has_method("cek_aturan") and child.slot_saat_ini != null:
			_bebaskan_slot_dari_kartu(child)
			child.hancurkan_kartu()
	
	update_tampilan_ui()
	
	await get_tree().process_frame
	update_semua_logika_kartu()
	
func _on_tombol_pause_pressed():
	if canvas_pause:
		SoundManager.play_sfx(sfx_klik)
		canvas_pause.visible = true
		$CanvasLayer/HUD/PauseButton.visible = false
		$CanvasLayer/HUD/PauseButton.disabled = true

		get_tree().paused = true

func _on_tombol_resume_pressed():
	SoundManager.play_sfx(sfx_klik)
	canvas_pause.visible = false
	$CanvasLayer/HUD/PauseButton.visible = true
	$CanvasLayer/HUD/PauseButton.disabled = false

	get_tree().paused = false
	
func _on_tombol_restart_pressed():
	SoundManager.play_sfx(sfx_klik)
	get_tree().paused = false 

	RitualArena.auto_start = true 
	
	get_tree().reload_current_scene()

func _on_tombol_home_pressed():
	SoundManager.play_sfx(sfx_klik)
	
	get_tree().paused = false 
	
	RitualArena.auto_start = false 
	
	get_tree().reload_current_scene()
