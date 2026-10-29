extends Area2D

#KONFIGURASI DI INSPECTOR
@export_enum("Pocong", "Tuyul", "Kunti", "Kuyang", "Leak", "SundelBolong", "GundulPeringis", "Genderuwo", "Banaspati", "Tengkorak", "SusterNgesot") var jenis_roh: String = "Pocong"
@export var tekstur_pocong: Texture2D
@export var tekstur_tuyul: Texture2D
@export var tekstur_kunti: Texture2D
@export var tekstur_kuyang: Texture2D
@export var tekstur_leak: Texture2D
@export var tekstur_sundel: Texture2D
@export var tekstur_genderuwo: Texture2D
@export var tekstur_gundul: Texture2D
@export var tekstur_banaspati: Texture2D
@export var tekstur_tengkorak: Texture2D
@export var tekstur_susterngesot: Texture2D
@onready var label_poin = $LabelPoin

@onready var box = $Sprite2D/select

@export var sfx_ambil: AudioStream
@export var sfx_masuk_slot: AudioStream 
@export var sfx_tengkorak: AudioStream 
@export var sfx_suster: AudioStream 
@export var sfx_banaspati: AudioStream 

var slot_terakhir_ronde_lalu = null


@onready var anim = $AnimKartu
@onready var animm = $LabelPoin/AnimKartu2
@onready var animmm = $AnimKartu3

#DATA INTERNAL
var poin: int = 0
var marah: bool = false
var slot_saat_ini = null

#LOGIKA DRAG & DROP
var dragging = false
var offset = Vector2.ZERO
var posisi_asal: Vector2
var ditenangkan_suster: bool = false

var deskripsi_aturan: String = ""
var waktu_klik = 0.0
var is_moved = false
var is_destroying: bool = false

var waktu_layang: float = 0.0
@export var tinggi_layang: float = 9.0
@export var kecepatan_layang: float = 2.0

var kecepatan_mouse: float = 0.0
@export var intensitas_miring: float = 0.02
@export var kehalusan_miring: float = 10.0

var rotasi_dasar: float = 0.0

@onready var shadow = $Shadow


func _ready():
	setup_kartu()
	var arena = get_parent()
	set_shadow_height("hand")
	if arena.has_signal("klik_di_luar"):
		arena.klik_di_luar.connect(_on_arena_klik_di_luar)

func _on_arena_klik_di_luar():
	var b = find_child("box")
	if b:
		b.visible = false

func setup_kartu():
	deskripsi_aturan = tr("KEY_" + jenis_roh.to_upper() + "_RULES")
	
	var sprite = $Sprite2D
	if jenis_roh == "Pocong":
		sprite.texture = tekstur_pocong
		poin = 6
	elif jenis_roh == "Tuyul":
		sprite.texture = tekstur_tuyul
		poin = 4
	elif jenis_roh == "Kunti":
		sprite.texture = tekstur_kunti
		poin = 7
	elif jenis_roh == "Kuyang":
		sprite.texture = tekstur_kuyang
		poin = 8
	elif jenis_roh == "Leak":
		sprite.texture = tekstur_leak
		poin = 9
	elif jenis_roh == "SundelBolong":
		sprite.texture = tekstur_sundel
		poin = 5
	elif jenis_roh == "GundulPeringis":
		sprite.texture = tekstur_gundul
		poin = 7
	elif jenis_roh == "Genderuwo":
		sprite.texture = tekstur_genderuwo
		poin = 10
	if jenis_roh == "Banaspati":
		sprite.texture = tekstur_banaspati 
		poin = 0
	if jenis_roh == "Tengkorak":
		sprite.texture = tekstur_tengkorak
		poin = 0
	if jenis_roh == "SusterNgesot":
		sprite.texture = tekstur_susterngesot
		poin = 0
		
	update_label_poin()
	
	if get_parent().has_method("update_tampilan_ui"):
		get_parent().update_tampilan_ui()

func update_label_poin():
	if has_node("LabelPoin"):
		$LabelPoin.text = "+" + str(poin)
		
		$LabelPoin.add_theme_color_override("font_color", Color.YELLOW)

func _process(delta):
	if dragging:
		if animmm.current_animation == "calm":
			animmm.play("non_calm")
		var pergerakan_x = get_global_mouse_position().x - global_position.x - offset.x
		global_position = get_global_mouse_position() - offset
		get_parent().update_slot_highlight(self)
		
		var target_rotasi = clamp(pergerakan_x * intensitas_miring, -0.5, 0.5)
		rotation = lerp_angle(rotation, target_rotasi, delta * kehalusan_miring)
		$Sprite2D.position.y = 0
		
	elif slot_saat_ini == null and not is_destroying:
		rotation = lerp_angle(rotation, rotasi_dasar, delta * kehalusan_miring)
		
		waktu_layang += delta * kecepatan_layang
		$Sprite2D.position.y = sin(waktu_layang) * tinggi_layang
	else:
		if slot_saat_ini != null:
			rotation = lerp_angle(rotation, slot_saat_ini.rotation, delta * kehalusan_miring)
		else:
			rotation = lerp_angle(rotation, 0, delta * kehalusan_miring)
			
		$Sprite2D.position.y = 0

func _input_event(_viewport, event, _shape_idx):
	var arena = get_parent()
	if is_destroying or get_parent().has_method("proses_hitung_poin_berurutan") and get_parent().sedang_menghitung or arena.game_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if sfx_ambil:
				SoundManager.play_sfx(sfx_ambil)
			get_parent().kelola_seleksi_kartu(self)
			box.visible = true
			z_index = 100
			waktu_klik = Time.get_ticks_msec()
			if animmm.is_playing() and animmm.current_animation == "calm":
				animmm.play("non_calm")
				print("h")
			
			if arena.boleh_hapus:
				if slot_saat_ini != null:
					arena.eksekusi_hapus_kartu(self)
				return 
			
			get_viewport().set_input_as_handled()
			posisi_asal = global_position
			dragging = true
			set_shadow_height("drag")
			
			var tween = create_tween() 
			tween.kill()
			offset = get_global_mouse_position() - global_position
			z_index = 100
		else:
			if dragging:
				var durasi = Time.get_ticks_msec() - waktu_klik
				if durasi < 200: 
					arena.tampilkan_info(self, deskripsi_aturan)
				
				dragging = false
				z_index = 0
				lepas_kartu()

func lepas_kartu():
	dragging = false
	var arena = get_parent()
	var slot_target = arena.slot_highlight_aktif
	
	arena.matikan_semua_highlight()
	
	if slot_target:
		if sfx_masuk_slot:
			SoundManager.play_sfx(sfx_masuk_slot)
		set_shadow_height("slot")
		_bebaskan_slot_lama()
		
		var t = create_tween().set_parallel(true)
		t.tween_property(self, "global_position", slot_target.global_position, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "global_rotation", slot_target.rotation, 0.2)
		rotation = slot_target.rotation
		slot_saat_ini = slot_target
		
		slot_saat_ini.set_meta("ditempati", true)
		slot_saat_ini.set_meta("kartu_di_sini", self)
		
		await get_tree().create_timer(0.15).timeout
		
		if jenis_roh == "Tengkorak":
			SoundManager.play_sfx(sfx_tengkorak)
			if has_node("LabelPoin/AnimKartu2"):
				animm.play("tengkorak")
			z_index = 150
			
			arena.eksekusi_tengkorak(slot_target) 
			
			hancurkan_kartu()
			
			arena.cek_papan_penuh()
			return
			
		if jenis_roh == "Banaspati":
			SoundManager.play_sfx(sfx_banaspati)
			if has_node("LabelPoin/AnimKartu2"):
				animm.play("banaspati")
			arena.ledakan_banaspati(slot_target)
			hancurkan_kartu()
			return
		
		if jenis_roh == "SusterNgesot":
			SoundManager.play_sfx(sfx_suster)
			if has_node("LabelPoin/AnimKartu2"):
				animm.play("suster")
			if arena.has_method("guncang_layar"):
				arena.guncang_layar(5.0)
				animmm.play("calm")
				arena.update_semua_logika_kartu()
				
			
			
		arena.update_semua_logika_kartu()
		arena.susun_ulang_tangan()
		arena.cek_papan_penuh()
		
	else:
		set_shadow_height("hand")
		global_position = posisi_asal
		rotation = 0
		if has_node("AnimKartu3"):
			animmm.play("non_calm")
			print("k")

func _bebaskan_slot_lama():
	if slot_saat_ini != null:
		slot_saat_ini.set_meta("ditempati", false)
		slot_saat_ini.set_meta("kartu_di_sini", null)
		slot_saat_ini = null

func cek_ulang_slot_lama():
	var areas = get_overlapping_areas()
	for area in areas:
		if area.name == "DetektorKartu":
			var s = area.get_parent()
			if s.global_position == global_position:
				slot_saat_ini = s
				slot_saat_ini.set_meta("ditempati", true)
				slot_saat_ini.set_meta("kartu_di_sini", self)
				break

func cek_aturan():
	if is_destroying: return
	if slot_saat_ini == null: return
	
	var r = slot_saat_ini.get_meta("pos_r")
	var c = slot_saat_ini.get_meta("pos_c")
	var arena = get_parent()
	var ada_suster_disebelah = false
	
	if jenis_roh == "SusterNgesot":
		ada_suster_disebelah = true
	else:
		var koordinat_cek = [[r-1, c], [r+1, c], [r, c-1], [r, c+1]]
		for k in koordinat_cek:
			var kunci_k = str(k[0]) + "," + str(k[1])
			if arena.semua_slot.has(kunci_k):
				var slot_t = arena.semua_slot[kunci_k]
				var kartu_t = slot_t.get_meta("kartu_di_sini")
				if kartu_t and is_instance_valid(kartu_t) and kartu_t.jenis_roh == "SusterNgesot":
					ada_suster_disebelah = true
					break
					
	if ada_suster_disebelah:
		ditenangkan_suster = true
		if animmm.current_animation != "calm":
			animmm.play("calm")
			animmm.seek(0, true)
	else:
		ditenangkan_suster = false
		if animmm.current_animation == "calm":
			animmm.play("non_calm")
	marah = false
	
	if jenis_roh == "Pocong":
		if not (r == 0 or r == 2 or c == 0 or c == 5):
			marah = true
			
	elif jenis_roh == "Kunti":
		if c < 5:
			var kunci_kanan = str(r) + "," + str(c + 1)
			if arena.semua_slot.has(kunci_kanan):
				if arena.semua_slot[kunci_kanan].get_meta("ditempati"):
					marah = true
					
	elif jenis_roh == "Tuyul":
		var tetangga = [[r-1, c], [r+1, c], [r, c-1], [r, c+1]]
		for t in tetangga:
			var kunci_t = str(t[0]) + "," + str(t[1])
			if arena.semua_slot.has(kunci_t):
				var s_t = arena.semua_slot[kunci_t]
				if s_t.get_meta("ditempati"):
					var kartu_lain = s_t.get_meta("kartu_di_sini")
					if kartu_lain and kartu_lain.jenis_roh == "Tuyul":
						marah = true
						
	elif jenis_roh == "Kuyang":
		var kunci_atas = str(r -1) + "," + str(c)
		if arena.semua_slot.has(kunci_atas):
			if arena.semua_slot[kunci_atas].get_meta("ditempati"):
				marah = true
			else:
				marah = false
		else:
			marah = false
			
	elif jenis_roh == "Leak":
		var jumlah_kosong = 0
		var tetangga = [
			[r - 1, c], [r + 1, c], 
			[r, c - 1], [r, c + 1]
		]
		
		for t in tetangga:
			var kunci_t = str(t[0]) + "," + str(t[1])
			if not arena.semua_slot.has(kunci_t):
				jumlah_kosong += 1
			elif not arena.semua_slot[kunci_t].get_meta("ditempati"):
				jumlah_kosong += 1
				
		if jumlah_kosong < 2:
			marah = true
		else:
			marah = false
			
	elif jenis_roh == "SundelBolong":
		var kunci_kanan = str(r) + "," + str(c+1)
		
		if arena.semua_slot.has(kunci_kanan):
			if arena.semua_slot[kunci_kanan].get_meta("ditempati"):
				marah = false
			else:
				marah = true
		
		else:
			marah = true
			
	
	elif jenis_roh == "GundulPeringis":
		if slot_saat_ini != null and slot_saat_ini == slot_terakhir_ronde_lalu:
			marah = true
		else:
			marah = false
			
	elif jenis_roh == "Genderuwo":
		marah = true
		
	if ditenangkan_suster:
		marah = false
			
			
			
	if marah:
		print("KARTU ", jenis_roh.to_upper(), " MARAH! [cite: 17]")
		anim.play("Marah")
	
	else:
		anim.play("Diem")

func animasikan_hitung_poin():
	z_index = 100
	
	if has_node("LabelPoin/AnimKartu2"):
		$LabelPoin/AnimKartu2.play("Count")
		await $LabelPoin/AnimKartu2.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
		
	z_index = 0

func hancurkan_kartu():
	if is_destroying: return
	is_destroying = true
	var arena = get_parent()
	if arena.has_method("paksa_reset_info"):
		arena.paksa_reset_info()
	
	_bebaskan_slot_lama()
	
	if has_node("select"): $select.visible = false
	if has_node("LabelPoin"): $LabelPoin.visible = false
	
	if has_node("AnimKartu"):
		anim.play("destroy")
		await anim.animation_finished
	print("sudah hapus")
	queue_free()

func set_shadow_height(state: String):
	if not shadow: return
	
	var t = create_tween().set_parallel(true)
	
	match state:
		"drag":
			t.tween_property(shadow, "position", Vector2(56, 48), 0.2)
			t.tween_property($Sprite2D, "scale", Vector2(1.1, 1.1), 0.2)
		"hand":
			t.tween_property(shadow, "position", Vector2(36, 28), 0.2)
			t.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.2)
		"slot":
			t.tween_property(shadow, "position", Vector2(0, 0), 0.2)
			t.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.2)
			
