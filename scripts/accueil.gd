extends Control

var _entree: Button

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pilote="):
			get_tree().change_scene_to_file.call_deferred("res://scenes/ville.tscn")
			return
	theme = Ui.preparer()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	centre.add_child(colonne)
	var titre := Ui.label("ARISE VILLE", 64, Color("#edf1ff"), 5)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(titre)
	var contexte := "L’Association · Ta première chasse" if Partie.chapitre < 2 else "Chasseur %s   ·   Niveau %d   ·   %d ombres" % [Partie.RANGS[Partie.rang_chasseur], Partie.niveau, Partie.ombres.size()]
	var ligne := Ui.label(contexte, 24, Color("#b3c4fa"), 3)
	ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(ligne)
	_entree = Ui.bouton("ENTRER EN VILLE", Ui.VIOLET, Vector2(400, 74), 28)
	colonne.add_child(_entree)
	_entree.pressed.connect(_entrer)
	var leger := CheckButton.new()
	leger.text = "Rendu léger"
	leger.custom_minimum_size.y = 58
	leger.button_pressed = Partie.opts["rendu_leger"]
	colonne.add_child(leger)
	leger.toggled.connect(func (actif: bool):
		Partie.opts["rendu_leger"] = actif
		Partie.sauver())

func _entrer() -> void:
	if _entree.disabled:
		return
	_entree.disabled = true
	_entree.text = "CHARGEMENT…"
	await get_tree().process_frame
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file("res://scenes/ville.tscn")
	if err != OK:
		_entree.disabled = false
		_entree.text = "RÉESSAYER"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10182b"))
	var foyer := Vector2(size.x * 0.5, size.y * 0.5)
	var rayon := minf(size.y * 0.67, size.x * 0.4)
	for k in 12:
		var r := rayon * (1.0 - k / 19.0)
		draw_circle(foyer, r, Color(0.14, 0.18, 0.33, 0.15))
	for k in 3:
		draw_arc(foyer, rayon * (0.88 + k * 0.06), -2.8 + k * 0.2, 2.5 + k * 0.2, 100, Color(0.44, 0.50, 0.90, 0.24), 2.0, true)
