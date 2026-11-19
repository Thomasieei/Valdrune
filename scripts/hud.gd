class_name Hud
extends CanvasLayer





var ville: Node
var _racine: Control
var _doigts := {}
var _joy_centre := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_actif := false
const JOY_R := 85.0
var _b_frapper: Control
var _b_eveil: Control
var _b_comp := {}
var _hex := {}
var _haut: Control
var _droite: Control
var _cadre: Control
var _msg: Label
var _msg_t := 0.0
var _taille := Vector2(1280, 720)
var _toasts: VBoxContainer
var _nouveaux := 0

var _panneau: Control
var _type := ""
var _onglet := "arme"
var _page := 0
var _tri := "rarete"
var _detail: Control
var _choix: Array = []

var _b_action: Control
var _action := {}
var _annonce: Control
var _fondu: ColorRect
var _evt: Button
var _donj: Control
var _quitter: Button
var _fleche: Control
var _aff_j := 0.0
var _aff_o := 0.0

var _autel := "ombres"
var _bande: Array = []
var _roll_actif := false
var _roll_t := 0.0
var _roll_res := {}
var _roll_txt := ""
var _roll_serie := 0
var _roll_case := -1
var _roll_auto := false
const ROLL_DUREE := 2.6
const ROLL_CASE := 132.0
const ROLL_CIBLE := 34

func _ready() -> void:
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.theme = Ui.preparer()
	add_child(_racine)
	var joy := Control.new()
	joy.name = "Joy"
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.draw.connect(func ():
		joy.draw_circle(_joy_centre, JOY_R, Color(0, 0, 0, 0.28))
		joy.draw_arc(_joy_centre, JOY_R, 0, TAU, 48, Color(0.45, 0.7, 1.0, 0.6), 3.0, true)
		joy.draw_circle(_joy_pos, 38, Color(0.55, 0.75, 1.0, 0.8 if _joy_actif else 0.55)))
	_racine.add_child(joy)
	_haut = Control.new()
	_haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haut.size = Vector2(420, 140)
	_haut.draw.connect(_dessiner_haut)
	_racine.add_child(_haut)
	_droite = Control.new()
	_droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_droite.size = Vector2(330, 300)
	_droite.draw.connect(_dessiner_droite)
	_racine.add_child(_droite)
	for d in [["inventaire", "Inventaire", "sac"], ["ombres", "Ombres", "ombres"], ["stats", "Compétences", "q_skills"], ["index", "Index", "q_kills"], ["boutique", "Boutique", "potion"]]:
		var h := Ui.hexagone(d[1], d[2], 96.0)
		var type: String = d[0]
		h.pressed.connect(func (): ouvrir(type))
		_racine.add_child(h)
		_hex[type] = h
	_msg = Ui.label("", 28, Color.WHITE, 9)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_racine.add_child(_msg)
	_b_frapper = _rond("FRAPPER", "attack", 150.0, Color(0.15, 0.3, 0.85))
	_b_eveil = _rond("ÉVEIL", "arise", 128.0, Color(0.35, 0.1, 0.7))
	_b_eveil.visible = false
	for k in Partie.COMPETENCES:
		var d: Dictionary = Partie.COMPETENCES[k]
		_b_comp[k] = _rond(d["nom"], d["icone"], 104.0, {"esquive": Color(0.1, 0.5, 0.45), "brise": Color(0.15, 0.4, 0.75), "cri": Color(0.4, 0.15, 0.7)}[k])
	_cadre = Control.new()
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.size = Vector2(560, 118)
	_cadre.draw.connect(_dessiner_cadre)
	_racine.add_child(_cadre)
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	_racine.add_child(_toasts)
	_b_action = _rond("PARLER", "interact", 112.0, Color(0.1, 0.55, 0.4))
	_b_action.visible = false
	_evt = Button.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		_evt.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_evt.size = Vector2(330, 44)
	_evt.draw.connect(_dessiner_evt)
	_evt.pressed.connect(func ():
		if ville.boss_evt and not ville.boss_evt.mort:
			ville.joueur.viser(ville.boss_evt)
			dire("En route vers Baran !", Color(1.0, 0.5, 0.55)))
	_racine.add_child(_evt)
	_donj = Control.new()
	_donj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_donj.size = Vector2(560, 74)
	_donj.draw.connect(_dessiner_donjon)
	_donj.visible = false
	_racine.add_child(_donj)
	_quitter = Ui.bouton("Quitter le donjon", Ui.ROUGE, Vector2(220, 46), 19)
	_quitter.pressed.connect(func (): ville.quitter_donjon())
	_quitter.visible = false
	_racine.add_child(_quitter)
	_fleche = Control.new()
	_fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleche.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fleche.draw.connect(_dessiner_fleche)
	_racine.add_child(_fleche)
	_annonce = Control.new()
	_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_annonce.modulate.a = 0.0
	_racine.add_child(_annonce)
	var at := Ui.label("", 58, Color.WHITE, 12)
	at.name = "Titre"
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.add_child(at)
	var asous := Ui.label("", 26, Color.WHITE, 8)
	asous.name = "Sous"
	asous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.add_child(asous)
	_fondu = ColorRect.new()
	_fondu.color = Color(0, 0, 0, 0)
	_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.add_child(_fondu)
	Partie.change.connect(_maj)
	Partie.message.connect(dire)
	Partie.butin.connect(_sur_butin)
	Partie.monnaie_gagnee.connect(_sur_monnaie)
	Partie.niveau_gagne.connect(func (n):
		annonce("NIVEAU %d" % n, "+%d points de compétence à répartir" % Partie.POINTS_PAR_NIVEAU, Color(1.0, 0.82, 0.3))
		Fx.anneau(ville.joueur.global_position, Color(1.0, 0.8, 0.3), 4.0)
		Fx.son("levelup", -2.0))
	get_viewport().size_changed.connect(_disposer)
	_disposer()
	_maj()

func _rond(texte: String, icone: String, taille: float, fond: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(taille, taille)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("appuye", 0.0)
	c.draw.connect(func ():
		var ctr := c.size / 2.0
		var app: float = c.get_meta("appuye")
		var r := taille / 2.0 * (1.0 - app * 0.07)
		var pulse: float = c.get_meta("pulse", 0.0)
		if pulse > 0.0:
			c.draw_circle(ctr, r + 8 + 6 * pulse, Color(0.7, 0.4, 1.0, 0.35 * pulse))
		c.draw_circle(ctr, r, Color(fond.r, fond.g, fond.b, 0.92))
		c.draw_circle(ctr, r - 7, fond.lightened(0.12))
		c.draw_arc(ctr, r - 1, 0, TAU, 56, Color(0.7, 0.9, 1.0, 0.95), 4.0, true)
		var tex := Ui.tex(icone)
		var ti := r * 1.0
		c.draw_texture_rect(tex, Rect2(ctr - Vector2(ti, ti) / 2.0 - Vector2(0, r * 0.14), Vector2(ti, ti)), false)
		var fs := int(clampf(taille * 0.15, 15, 22))
		var tx: String = c.get_meta("texte", texte)
		var w := Ui.police.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := ctr + Vector2(- w / 2.0, r * 0.66)
		c.draw_string_outline(Ui.police, p, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
		c.draw_string(Ui.police, p, tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var cdf: float = c.get_meta("cd", 0.0)
		if cdf > 0.0:
			c.draw_circle(ctr, r, Color(0, 0, 0, 0.55))
			c.draw_arc(ctr, r - 4, -PI / 2.0, -PI / 2.0 + TAU * cdf, 48, Color(1, 1, 1, 0.85), 6.0, true)
			var ct := "%.0f" % ceilf(c.get_meta("cds", 0.0))
			var cw := Ui.police.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			c.draw_string_outline(Ui.police, ctr + Vector2(- cw / 2.0, 10), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color.BLACK)
			c.draw_string(Ui.police, ctr + Vector2(- cw / 2.0, 10), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		elif c.get_meta("pauvre", false):
			c.draw_circle(ctr, r, Color(0.05, 0.1, 0.4, 0.5)))
	_racine.add_child(c)
	return c

func _disposer() -> void:
	_taille = _racine.get_viewport_rect().size
	var w := _taille.x
	var h := _taille.y
	_joy_centre = Vector2(170, h - 160)
	_joy_pos = _joy_centre
	_b_frapper.position = Vector2(w - 200, h - 200)
	_b_eveil.position = Vector2(w - 500, h - 300)
	_b_action.position = Vector2(w - 480, h - 150)
	_b_comp["esquive"].position = Vector2(w - 330, h - 118)
	_b_comp["brise"].position = Vector2(w - 318, h - 250)
	_b_comp["cri"].position = Vector2(w - 196, h - 318)
	_haut.position = Vector2(16, 10)
	_droite.position = Vector2(w - 340, 120)
	_evt.position = Vector2(w - 340, 68)
	_quitter.position = Vector2(w - 240, 68)
	_donj.position = Vector2(w / 2.0 - 280, 6)
	_annonce.position = Vector2(w / 2.0 - 500, h * 0.22)
	_annonce.size = Vector2(1000, 120)
	for n in ["Titre", "Sous"]:
		var lb: Label = _annonce.get_node(n)
		lb.size = Vector2(1000, 70)
		lb.position = Vector2(0, 0 if n == "Titre" else 70)

	var o := Vector2(20, 150)
	var pos := {"inventaire": o, "ombres": o + Vector2(86, 50), "stats": o + Vector2(0, 100), "index": o + Vector2(86, 150), "boutique": o + Vector2(0, 200)}
	for k in _hex:
		_hex[k].position = pos[k]
	_msg.position = Vector2(w / 2.0 - 450, h * 0.62)
	_msg.size = Vector2(900, 40)
	_cadre.position = Vector2(w / 2.0 - 280, 8)
	_toasts.position = Vector2(w / 2.0 - 230, 140)
	_toasts.size = Vector2(460, 0)
	if _panneau:
		_placer_panneau()

func _maj() -> void:
	_haut.queue_redraw()
	_droite.queue_redraw()
	_hex["stats"].set_meta("alerte", Partie.points_libres() > 0)
	_hex["inventaire"].set_meta("alerte", _nouveaux > 0)
	for k in _hex:
		_hex[k].queue_redraw()
	if _panneau and not _roll_actif and _type != "mort":
		_construire()

func dire(t: String, c: Color = Color.WHITE) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", c)
	_msg_t = 3.2

func _sur_butin(o: Dictionary) -> void:
	_nouveaux += 1
	var b := Partie.base(o)
	var c: Color = Partie.COULEURS_RARETE[o["rarete"]]
	var p := Panel.new()
	p.custom_minimum_size = Vector2(460, 62)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Ui.boite(Color(0.04, 0.06, 0.16, 0.92), c, 3, 10))
	var ic := TextureRect.new()
	ic.texture = Ui.tex(b["icone"])
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(8, 4)
	ic.size = Vector2(54, 54)
	p.add_child(ic)
	var t := Ui.label("Nouvel objet !", 16, Color(0.75, 0.85, 1.0), 5)
	t.position = Vector2(72, 4)
	p.add_child(t)
	var n := Ui.label("%s  [%s]" % [b["nom"], Partie.RARETES[o["rarete"]]], 22, c.lightened(0.2), 6)
	n.position = Vector2(72, 24)
	p.add_child(n)
	_toasts.add_child(p)
	Fx.son("chest", -2.0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	_maj()


func annonce(titre: String, sous: String, c: Color) -> void:
	var t: Label = _annonce.get_node("Titre")
	var so: Label = _annonce.get_node("Sous")
	t.text = titre
	t.add_theme_color_override("font_color", c.lightened(0.15))
	so.text = sous
	var tw_a: Tween = _annonce.get_meta("tw") if _annonce.has_meta("tw") else null
	if tw_a and tw_a.is_valid():
		tw_a.kill()
	_annonce.pivot_offset = _annonce.size / 2.0
	_annonce.scale = Vector2.ONE * 1.25
	_annonce.modulate.a = 0.0
	var tw := _annonce.create_tween()
	_annonce.set_meta("tw", tw)
	tw.tween_property(_annonce, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_annonce, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(_annonce, "modulate:a", 0.0, 0.5)

func ecran_mort(r: Dictionary) -> void:
	fermer()
	_type = "mort"
	_panneau = Ui.panneau("Tu es mort" + ("  ×%d" % r["facteur"] if r["facteur"] > 1 else ""), "close", Vector2(820, 520), fermer)
	_ajouter(Ui.label("-%s pièces  (%d %% de ton or)" % [Fx.court(r["or"]), mini(10 * int(r["facteur"]), 80)], 28, Color(1.0, 0.8, 0.3), 7), Vector2(40, 84))
	var perdus: Array = r["objets"]
	if perdus.is_empty():
		_ajouter(Ui.label("Aucun objet perdu (rien de non équipé dans le sac).", 20, Color(0.8, 0.85, 1.0)), Vector2(40, 140))
	else:
		_ajouter(Ui.label("Objets perdus :", 22, Color(1.0, 0.5, 0.5), 6), Vector2(40, 134))
		for k in mini(perdus.size(), 4):
			var o: Dictionary = perdus[k]
			var b := Partie.base(o)
			var c := Ui.carte(b["nom"], b["icone"], Partie.SIGLES[o["rarete"]], Partie.COULEURS_RARETE[o["rarete"]], false, "Niv. %d" % o["niv"], Vector2(150, 166), b.get("effet", ""))
			c.disabled = true
			_ajouter(c, Vector2(40 + k * 166, 172))
	var l := Ui.label("", 20, Color(1.0, 0.55, 0.5), 6)
	l.position = Vector2(40, 372)
	_panneau.add_child(l)
	var maj := func ():
		var f := Partie.fenetre_mort()
		l.text = "Pénalité doublée si tu meurs encore dans %d:%02d" % [int(f) / 60, int(f) % 60] if f > 0.0 else "Pénalité revenue à la normale."
	maj.call()
	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(maj)
	_panneau.add_child(tm)
	var ok := Ui.bouton("Repartir", Ui.VERT, Vector2(240, 56))
	ok.pressed.connect(fermer)
	_ajouter(ok, Vector2(290, 430))
	_racine.add_child(_panneau)
	_placer_panneau()

func fondu(noir: bool) -> void:
	var tw := _fondu.create_tween()
	tw.tween_property(_fondu, "color:a", 1.0 if noir else 0.0, 0.35)
	await tw.finished

func _sur_monnaie(m: String, n: int) -> void:
	var d: Dictionary = Partie.MONNAIES[m]
	var p := Panel.new()
	p.custom_minimum_size = Vector2(460, 44)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Ui.boite(Color(0.04, 0.06, 0.16, 0.9), d["couleur"], 2, 10))
	var ic := Control.new()
	ic.position = Vector2(10, 6)
	ic.size = Vector2(32, 32)
	ic.draw.connect(func (): _jeton(ic, Vector2(16, 16), 14.0, m))
	p.add_child(ic)
	var l := Ui.label("+%d  %s" % [n, d["pluriel"] if n > 1 else d["nom"]], 22, (d["couleur"] as Color).lightened(0.3), 6)
	l.position = Vector2(52, 8)
	p.add_child(l)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	Fx.son("orb", -6.0)


func _jeton(c: Control, ctr: Vector2, r: float, m: String) -> void:
	var col: Color = Partie.MONNAIES[m]["couleur"]
	c.draw_circle(ctr, r, col.darkened(0.55))
	c.draw_circle(ctr, r - 2.5, col.darkened(0.15))
	match m:
		"eclat":
			var pts := PackedVector2Array([ctr + Vector2(0, -r * 0.75), ctr + Vector2(r * 0.4, 0), ctr + Vector2(0, r * 0.75), ctr + Vector2(- r * 0.4, 0)])
			c.draw_colored_polygon(pts, Color(0.95, 0.85, 1.0))
		"insigne":

			var bl := Color(1, 0.93, 0.86)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -r * 0.78), ctr + Vector2(r * 0.14, -r * 0.55), ctr + Vector2(r * 0.12, r * 0.25), ctr + Vector2(- r * 0.12, r * 0.25), ctr + Vector2(- r * 0.14, -r * 0.55)]), bl)
			c.draw_line(ctr + Vector2(- r * 0.42, r * 0.28), ctr + Vector2(r * 0.42, r * 0.28), Color(1.0, 0.8, 0.35), 3.0, true)
			c.draw_line(ctr + Vector2(0, r * 0.3), ctr + Vector2(0, r * 0.62), Color(0.55, 0.3, 0.2), 3.0, true)
			c.draw_circle(ctr + Vector2(0, r * 0.68), r * 0.1, Color(1.0, 0.8, 0.35))
		"trefle":
			for k in 4:
				var a := k * PI / 2.0 + PI / 4.0
				c.draw_circle(ctr + Vector2(cos(a), sin(a)) * r * 0.3, r * 0.28, Color(0.85, 1.0, 0.85))
	c.draw_arc(ctr, r, 0, TAU, 32, col.lightened(0.4), 2.0, true)

func _process(dt: float) -> void:
	_maj_action()
	_donj.visible = ville.donjon != null
	_quitter.visible = ville.donjon != null and ville.donjon.actif
	_evt.visible = ville.donjon == null
	_cadre.position.y = 86.0 if ville.donjon else 8.0
	if _donj.visible:
		_donj.queue_redraw()
	_evt.queue_redraw()
	_fleche.queue_redraw()
	var dj: Array = Partie.direct()
	_aff_j = lerpf(_aff_j, dj[0], minf(1.0, dt * 4.0))
	_aff_o = lerpf(_aff_o, dj[1], minf(1.0, dt * 4.0))
	_droite.queue_redraw()
	_haut.queue_redraw()
	if _roll_actif:
		_avancer_roll(dt)
	_msg_t -= dt
	_msg.modulate.a = clampf(_msg_t / 0.5, 0.0, 1.0)
	var eveil: Monstre = ville.monstre_eveillable()
	_b_eveil.visible = eveil != null
	_b_eveil.set_meta("pulse", 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0))
	_b_eveil.queue_redraw()
	for k in _b_comp:
		var bc: Control = _b_comp[k]
		var rc: float = ville.joueur.recharges[k]
		bc.set_meta("cd", rc / float(Partie.COMPETENCES[k]["cd"]))
		bc.set_meta("cds", rc)
		bc.set_meta("pauvre", Partie.mana < float(Partie.COMPETENCES[k]["mana"]))
		bc.queue_redraw()
	for b in [_b_frapper, _b_eveil, _b_action] + _b_comp.values():
		var a: float = b.get_meta("appuye")
		if a > 0.0:
			b.set_meta("appuye", maxf(0.0, a - dt * 5.0))
			b.queue_redraw()
	_cadre.queue_redraw()
	ville.joueur.entree = (_joy_pos - _joy_centre) / JOY_R * Vector2(1, -1) if _joy_actif else Vector2.ZERO
	_racine.get_node("Joy").queue_redraw()


func _texte(c: Control, p: Vector2, t: String, taille: int, coul: Color, contour := 6) -> void:
	c.draw_string_outline(Ui.police, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, contour, Color.BLACK)
	c.draw_string(Ui.police, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, coul)

func _dessiner_haut() -> void:
	var c := _haut
	c.draw_circle(Vector2(46, 46), 42, Color(0.04, 0.06, 0.2, 0.9))
	c.draw_arc(Vector2(46, 46), 42, 0, TAU, 48, Ui.CYAN, 4.0, true)
	var frac := float(Partie.xp) / float(Partie.xp_requise())
	c.draw_arc(Vector2(46, 46), 35, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(0.55, 0.4, 1.0), 6.0, true)
	var nv := str(Partie.niveau)
	var w := Ui.police.get_string_size(nv, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_texte(c, Vector2(46 - w / 2.0, 58), nv, 32, Color.WHITE, 7)
	_texte(c, Vector2(100, 34), "Chasseur  ·  Niveau %d" % Partie.niveau, 22, Color(0.8, 0.9, 1.0))
	c.draw_texture_rect(Ui.tex("r1"), Rect2(98, 44, 36, 36), false)
	_texte(c, Vector2(140, 74), Fx.court(Partie.pieces), 30, Color(1.0, 0.85, 0.3), 7)
	for k in 2:
		var y := 100.0 + k * 20.0
		var fr: float = Partie.pv / Partie.pv_max() if k == 0 else Partie.mana / Partie.mana_max()
		var col := Color(0.95, 0.25, 0.3) if k == 0 else Color(0.35, 0.55, 1.0)
		c.draw_rect(Rect2(8, y, 300, 14), Color(0.05, 0.05, 0.12, 0.85))
		c.draw_rect(Rect2(8, y, 300 * clampf(fr, 0.0, 1.0), 14), col)
		c.draw_rect(Rect2(8, y, 300, 14), Color(1, 1, 1, 0.5), false, 1.5)
		var t := "PV %d / %d" % [int(Partie.pv), int(Partie.pv_max())] if k == 0 else "Mana %d / %d" % [int(Partie.mana), int(Partie.mana_max())]
		_texte(c, Vector2(316, y + 13), t, 15, col.lightened(0.35), 4)


func _dessiner_droite() -> void:
	var c := _droite
	var r := Rect2(0, 0, c.size.x, 112)
	c.draw_style_box(Ui.boite(Color(0.03, 0.05, 0.14, 0.8), Color(0.2, 0.45, 1.0, 0.8), 2, 10), r)
	var total := _aff_j + _aff_o
	_texte(c, Vector2(14, 26), "DÉGÂTS EN DIRECT", 16, Color(0.6, 0.85, 1.0), 5)
	var pt := "Puissance %s/s" % Fx.court(Partie.dps_total())
	var pw := Ui.police.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_texte(c, Vector2(r.size.x - pw - 12, 26), pt, 15, Color(0.7, 0.75, 0.9), 5)
	_texte(c, Vector2(14, 62), "%s /s" % Fx.court(total), 34, Color.WHITE if total > 0.5 else Color(0.6, 0.65, 0.8), 8)
	var bx := Rect2(14, 72, r.size.x - 28, 10)
	c.draw_rect(bx, Color(0.1, 0.12, 0.25))
	if total > 0.5:
		var fj := _aff_j / total
		c.draw_rect(Rect2(bx.position, Vector2(bx.size.x * fj, bx.size.y)), Color(0.3, 0.85, 1.0))
		c.draw_rect(Rect2(bx.position + Vector2(bx.size.x * fj, 0), Vector2(bx.size.x * (1.0 - fj), bx.size.y)), Color(0.62, 0.35, 1.0))
	_texte(c, Vector2(14, 102), "Toi  %s" % Fx.court(_aff_j), 19, Color(0.45, 0.9, 1.0), 6)
	var ot := "Ombres  %s" % Fx.court(_aff_o)
	var ow := Ui.police.get_string_size(ot, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	_texte(c, Vector2(r.size.x - ow - 14, 102), ot, 19, Color(0.75, 0.55, 1.0), 6)
	var y := 140.0
	var couleurs := {"eveil": Color(0.35, 1.0, 0.45), "ombres": Color(0.7, 0.45, 1.0), "arme": Color(1.0, 0.35, 0.35),
		"pieces": Color(1.0, 0.8, 0.25), "xp": Color(0.4, 0.8, 1.0), "vitesse": Color(0.5, 1.0, 0.9), "crit": Color(1.0, 0.6, 0.2)}
	for k in ["eveil", "ombres", "arme", "pieces", "xp", "vitesse", "crit"]:
		var b := Partie.bonus(k)
		if b <= 0.0:
			continue
		var t := "%s : +%s%%" % [Partie.NOMS_STATS[k], ("%.1f" % b) if b < 100 else Fx.court(b)]
		var tw := Ui.police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		_texte(c, Vector2(c.size.x - tw - 6, y), t, 21, couleurs[k])
		y += 30.0

func _dessiner_cadre() -> void:
	var m: Monstre = ville.joueur.cible
	if m == null or not is_instance_valid(m):
		return
	var c := _cadre
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_style_box(Ui.boite(Color(0.06, 0.05, 0.2, 0.92), Ui.CYAN, 3, 10), r)
	c.draw_rect(Rect2(6, 6, r.size.x - 12, r.size.y - 12), Color(0.5, 0.3, 1.0, 0.5), false, 2.0)
	var ctr := Vector2(60, 59)
	var pts := PackedVector2Array()
	for k in 6:
		var a := k * TAU / 6.0
		pts.append(ctr + Vector2(cos(a), sin(a)) * 44)
	c.draw_colored_polygon(pts, Color(0.1, 0.2, 0.55))
	pts.append(pts[0])
	c.draw_polyline(pts, Ui.CYAN, 3.0, true)
	c.draw_texture_rect(Ui.tex(m.e["icone"]), Rect2(ctr - Vector2(36, 36), Vector2(72, 72)), false)
	var rang: int = m.e["rang"]
	var v := Partie.verdict(m.espece, m.elite, m.mult)
	var tete := "★ ÉLITE  ·  " if m.elite else ""
	if m.sans_chrono:
		_texte(c, Vector2(118, 32), "%sRANG %s  ·  DONJON" % [tete, Partie.RANGS[rang]], 18, Color(1.0, 0.5, 0.55))
	else:
		_texte(c, Vector2(118, 32), "%sRANG %s  ·  %s" % [tete, Partie.RANGS[rang], String(v["texte"]).to_upper()], 18, Monstre.OR_ELITE if m.elite else v["couleur"])
	_texte(c, Vector2(118, 66), m.e["nom"], 32, Color.WHITE, 8)
	if not m.sans_chrono:
		var tr: float = m.temps_restant()
		var tt := "%02d:%02d" % [int(tr) / 60, int(tr) % 60] if not m.enrage else "RAGE"
		var tw := Ui.police.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		var urgent: bool = m.enrage or (m.chrono >= 0.0 and tr / m.temps_max < 0.3)
		_texte(c, Vector2(r.size.x - tw - 16, 62), tt, 38, Color(1, 0.35, 0.3) if urgent else Color.WHITE, 8)
		_texte(c, Vector2(r.size.x - tw - 16, 26), "CHRONO", 15, Color(0.4, 0.9, 1.0))
	var bx := 118.0
	var bw := r.size.x - bx - 16
	var frac: float = clampf(m.pv / m.pv_max, 0, 1)
	var n := 10
	for k in n:
		var seg := Rect2(bx + k * bw / n, 80, bw / n - 4, 20)
		c.draw_rect(seg, Color(0.12, 0.08, 0.2))
		var plein := clampf(frac * n - k, 0.0, 1.0)
		if plein > 0.0:
			c.draw_rect(Rect2(seg.position, Vector2(seg.size.x * plein, seg.size.y)), Color(0.95, 0.25, 0.35))
			c.draw_rect(Rect2(seg.position, Vector2(seg.size.x * plein, 6)), Color(1, 0.6, 0.65, 0.6))
	var pt := "%s / %s" % [Fx.court(maxf(m.pv, 0)), Fx.court(m.pv_max)]
	var pw := Ui.police.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_texte(c, Vector2(bx + (bw - pw) / 2.0, 96), pt, 16, Color.WHITE, 5)


func ouvrir(type: String) -> void:
	if _panneau and _type == type:
		fermer()
		return
	fermer()
	_type = type
	_page = 0
	if type == "inventaire":
		_nouveaux = 0
		_maj()
	_construire()

func fermer() -> void:
	if _panneau:
		_panneau.queue_free()
	_panneau = null
	_detail = null
	_choix = []
	_type = ""

func _placer_panneau() -> void:
	var k := minf(1.0, minf((_taille.x - 20) / _panneau.size.x, (_taille.y - 20) / _panneau.size.y))
	_panneau.scale = Vector2.ONE * k
	_panneau.position = (_taille - _panneau.size * k) / 2.0

func _construire() -> void:
	if _type == "":
		return
	if _panneau:
		_panneau.queue_free()
	_detail = null
	match _type:
		"inventaire":
			_panneau = Ui.panneau("Inventaire", "sac", Vector2(1060, 610), fermer)
			_inventaire()
		"ombres":
			_panneau = Ui.panneau("Ombres", "ombres", Vector2(1060, 610), fermer)
			_ombres()
		"stats":
			_panneau = Ui.panneau("Compétences du chasseur", "q_skills", Vector2(760, 610), fermer)
			_stats()
		"index":
			_panneau = Ui.panneau("Index des monstres", "q_kills", Vector2(900, 610), fermer)
			_index()
		"boutique":
			_panneau = Ui.panneau("Boutique", "potion", Vector2(820, 600), fermer)
			_boutique()
		"autel":
			_panneau = Ui.panneau(Partie.ROLLS[_autel]["autel"], {"ombres": "ombres", "arme": "attack", "chance": "best"}[_autel], Vector2(1000, 610), fermer)
			_autel_panneau()
		"donjon":
			_panneau = Ui.panneau("Portail du donjon", "tele", Vector2(820, 600), fermer)
			_donjon_panneau()
		"recompenses":
			_panneau = Ui.panneau("Donjon terminé !", "best", Vector2(760, 560), fermer)
			_recompenses_panneau()
	_racine.add_child(_panneau)
	_placer_panneau()
	if _choix.size() == 2:
		_montrer_detail(_choix[0], _choix[1])

func _grille(elements: Array, origine: Vector2, colonnes: int, lignes: int, taille: Vector2, fabrique: Callable) -> void:
	var par_page := colonnes * lignes
	var pages := maxi(1, ceili(elements.size() / float(par_page)))
	_page = clampi(_page, 0, pages - 1)
	for k in par_page:
		var i := _page * par_page + k
		var pos := origine + Vector2((k % colonnes) * (taille.x + 14), (k / colonnes) * (taille.y + 14))
		if i >= elements.size():
			var vide := Panel.new()
			vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vide.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.08, 0.2, 0.6), Color(0.2, 0.3, 0.6, 0.4), 2, 10))
			vide.position = pos
			vide.size = taille
			_panneau.add_child(vide)
			continue
		var carte: Button = fabrique.call(elements[i])
		carte.set_meta("carte", true)
		carte.position = pos
		carte.size = taille
		_panneau.add_child(carte)
	if pages > 1:
		var y := origine.y + lignes * (taille.y + 14) - 2
		var gx := origine.x + colonnes * (taille.x + 14) / 2.0
		var g := Ui.bouton("◀", Ui.BLEU, Vector2(56, 44), 22)
		g.position = Vector2(gx - 120, y)
		g.disabled = _page == 0
		g.pressed.connect(func ():
			_page -= 1
			_construire())
		_panneau.add_child(g)
		var d := Ui.bouton("▶", Ui.BLEU, Vector2(56, 44), 22)
		d.position = Vector2(gx + 64, y)
		d.disabled = _page >= pages - 1
		d.pressed.connect(func ():
			_page += 1
			_construire())
		_panneau.add_child(d)
		var l := Ui.label("%d / %d" % [_page + 1, pages], 22, Color.WHITE)
		l.position = Vector2(gx - 26, y + 8)
		_panneau.add_child(l)

func _ajouter(c: Control, p: Vector2) -> Control:
	c.position = p
	_panneau.add_child(c)
	return c


const ONGLETS := [["arme", "Armes", "tab_w"], ["accessoire", "Accessoires", "tab_a"], ["relique", "Reliques", "tab_r"], ["sac", "Sac", "cash"]]
const TYPES_ACC := ["tete", "cape", "armure", "bottes"]
const NOMS_EMPL := {"tete": "Tête", "cape": "Cape", "armure": "Armure", "bottes": "Bottes"}

func _inventaire() -> void:
	for k in ONGLETS.size():
		var o: Array = ONGLETS[k]
		var h := Ui.hexagone(o[1], o[2], 104.0, Ui.CYAN if _onglet == o[0] else Ui.BLEU)
		h.position = Vector2(936, 86 + k * 118)
		var id: String = o[0]
		h.pressed.connect(func ():
			_onglet = id
			_page = 0
			_choix = []
			_construire())
		_panneau.add_child(h)
	if _onglet == "sac":
		_sac()
		return
	var nom_onglet: String = {"arme": "ARMES", "accessoire": "ACCESSOIRES", "relique": "RELIQUES"}[_onglet]
	_ajouter(Ui.label(nom_onglet, 34, Color.WHITE, 8), Vector2(36, 80))
	var tri := Ui.bouton("Ordre : %s" % ("Rareté" if _tri == "rarete" else "Puissance"), Ui.BLEU, Vector2(230, 46), 20)
	tri.pressed.connect(func ():
		_tri = "puissance" if _tri == "rarete" else "rarete"
		_construire())
	_ajouter(tri, Vector2(680, 80))
	var types: Array = ["arme"] if _onglet == "arme" else(TYPES_ACC if _onglet == "accessoire" else["relique"])
	var l := Partie.inventaire.filter(func (o): return Partie.base(o)["type"] in types)
	l.sort_custom(func (a, b):
		if Partie.est_equipe(a) != Partie.est_equipe(b):
			return Partie.est_equipe(a)
		if _tri == "rarete" and a["rarete"] != b["rarete"]:
			return a["rarete"] > b["rarete"]
		return Partie.valeur(a) > Partie.valeur(b))
	_ajouter(Ui.label("%d objet%s" % [l.size(), "s" if l.size() > 1 else ""], 20, Color(0.7, 0.8, 1.0)), Vector2(270, 92))
	var origine := Vector2(36, 140)
	var col := 5
	if _onglet != "arme":
		var empl: Array = TYPES_ACC if _onglet == "accessoire" else["relique1", "relique2", "relique3"]
		for k in empl.size():
			var e: String = empl[k]
			var o := Partie.objet(Partie.equipe.get(e, -1))
			var nom_e: String = NOMS_EMPL.get(e, "Relique %d" % (k + 1))
			var couleur: Color = Partie.COULEURS_RARETE[o["rarete"]] if not o.is_empty() else Color(0.3, 0.4, 0.7)
			var case_e := Ui.carte(nom_e, Partie.base(o)["icone"] if not o.is_empty() else "", "", couleur, false, "", Vector2(112, 112))
			case_e.position = Vector2(36 + (k % 2) * 124, 140 + (k / 2) * 124) if empl.size() == 4 else Vector2(36, 140 + k * 124)
			if not o.is_empty():
				case_e.pressed.connect(func (): _montrer_detail("objet", o))
			_panneau.add_child(case_e)
		origine = Vector2(310, 140) if empl.size() == 4 else Vector2(170, 140)
		col = 4
	_grille(l, origine, col, 2, Vector2(150, 166), func (o):
		var b := Partie.base(o)
		var c := Ui.carte(b["nom"], b["icone"], Partie.SIGLES[o["rarete"]], Partie.COULEURS_RARETE[o["rarete"]],
			Partie.est_equipe(o), ("Niv. %d · " % o["niv"]) + _resume(o), Vector2(150, 166), b.get("effet", ""))
		c.pressed.connect(func (): _montrer_detail("objet", o))
		return c)
	var meilleur := Ui.bouton("Équiper le meilleur", Ui.VERT, Vector2(260, 54))
	meilleur.pressed.connect(func ():
		Partie.equiper_le_meilleur(types)
		Fx.son("confirm", -4.0))
	_ajouter(meilleur, Vector2(36, 532))
	var communs := l.filter(func (o): return o["rarete"] == 0 and not Partie.est_equipe(o))
	var vendre := Ui.bouton("Vendre les communs (%d)" % communs.size(), Ui.ROUGE, Vector2(300, 54))
	vendre.disabled = communs.is_empty()
	vendre.pressed.connect(func ():
		var gain := 0
		for o in communs:
			gain += Partie.prix_vente(o)
			Partie.vendre(o)
		Fx.son("coins", -2.0)
		dire("+%s pièces" % Fx.court(gain), Color(1, 0.85, 0.3)))
	_ajouter(vendre, Vector2(312, 532))

func _resume(o: Dictionary) -> String:
	if Partie.base(o)["type"] == "arme":
		return "%s/s" % Fx.court(Partie.valeur(o))
	return "+%.0f%%" % Partie.valeur(o)

func _montrer_detail(genre: String, o: Dictionary) -> void:
	if _detail:
		_detail.queue_free()
	_detail = null
	_choix = [genre, o]
	var p: Panel
	if genre == "objet":
		if not Partie.inventaire.has(o):
			_choix = []
			return
		var b := Partie.base(o)
		var c: Color = Partie.COULEURS_RARETE[o["rarete"]]
		var lignes := [[Partie.RARETES[o["rarete"]], c.lightened(0.2)], ["Niveau : %d" % o["niv"], Color(0.5, 1.0, 0.5)]]
		if b["type"] == "arme":
			lignes.append(["Dégâts : %s / s" % Fx.court(Partie.valeur(o)), Color(1.0, 0.4, 0.4)])
			for at in Partie.attrs_texte(o):
				lignes.append([at, Color(0.95, 0.75, 1.0)])
		else:
			lignes.append(["%s : +%.1f %%" % [Partie.NOMS_STATS[b["stat"]], Partie.valeur(o)], Color(0.6, 0.85, 1.0)])
		var eq := Partie.est_equipe(o)
		var cout := Partie.cout_amelioration(o)
		var boutons := []
		if eq:
			boutons.append(["DÉSÉQUIPER", Ui.VERT, func (): Partie.desequiper(o), b["type"] == "arme"])
		else:
			boutons.append(["ÉQUIPER", Ui.VERT, func ():
				_choix = []
				Partie.equiper(o)
				Fx.son("sheath", -2.0)])
		boutons.append(["AMÉLIORER  (%s)" % Fx.court(cout), Ui.VIOLET, func ():
			if Partie.ameliorer(o):
				Fx.son("levelup", -4.0), Partie.pieces < cout])
		boutons.append(["VENDRE  (%s)" % Fx.court(Partie.prix_vente(o)), Ui.OR, func ():
			_choix = []
			if Partie.vendre(o):
				Fx.son("coins", -2.0), eq])
		boutons.append(["ANNULER", Ui.ROUGE, func (): _fermer_detail()])
		p = Ui.detail(b["nom"], c, lignes, boutons)
	else:
		if not Partie.ombres.has(o):
			_choix = []
			return
		var e: Dictionary = Partie.ESPECES[o["espece"]]
		var rang: int = Partie.rang_ombre(o)
		var lignes2 := [["Rang : %s" % Partie.RANGS[rang], Partie.COULEURS_RANG[rang]],
			["Étoiles : %s" % ("★".repeat(o["etoiles"]) if o["etoiles"] > 0 else "aucune"), Color(0.8, 0.6, 1.0)],
			["Dégâts : %s / s" % Fx.court(Partie.dps_ombre(o)), Color(1.0, 0.4, 0.4)],
			["Fusion : %d / 3 identiques" % Partie.ombres.filter(func (x): return x["espece"] == o["espece"] and int(x["etoiles"]) == int(o["etoiles"])).size(), Color(0.75, 0.6, 1.0)],
			["Rappel : %d mana" % int(Partie.cout_rappel(o)), Color(0.45, 0.65, 1.0)]]
		if e.has("competence"):
			var cp: Dictionary = e["competence"]
			lignes2.append(["%s : toutes les %d s" % [cp["nom"], int(cp["cd"])], Color(1.0, 0.45, 0.45)])
			lignes2.append(["frappe à ×%d ses dégâts" % int(cp["mult"]), Color(1.0, 0.6, 0.55)])
		var boutons2 := []
		if o["eq"]:
			boutons2.append(["DÉSÉQUIPER", Ui.VERT, func (): Partie.equiper_ombre(o, false)])
		else:
			var plein := Partie.ombres_equipees().size() >= Partie.places_ombres()
			boutons2.append(["ÉQUIPER" if not plein else "ÉQUIPE PLEINE", Ui.VERT, func ():
				_choix = []
				Partie.equiper_ombre(o, true), plein])
		boutons2.append(["LIBÉRER  (%s)" % Fx.court(Partie.prix_ombre(o)), Ui.OR, func ():
			_choix = []
			Partie.liberer_ombre(o)
			Fx.son("coins", -2.0)])
		boutons2.append(["ANNULER", Ui.ROUGE, func (): _fermer_detail()])
		p = Ui.detail(e["nom"], Partie.COULEURS_RANG[rang], lignes2, boutons2)
	p.position = Vector2(_panneau.size.x / 2.0 - 150, 96)
	_panneau.add_child(p)
	_detail = p

func _fermer_detail() -> void:
	if _detail:
		_detail.queue_free()
	_detail = null
	_choix = []


func _ombres() -> void:
	var eq := Partie.ombres_equipees().size()
	_ajouter(Ui.label("ARMÉE", 34, Color.WHITE, 8), Vector2(36, 80))
	_ajouter(Ui.label("%d ombre%s" % [Partie.ombres.size(), "s" if Partie.ombres.size() > 1 else ""], 22, Color(0.75, 0.8, 1.0)), Vector2(170, 90))
	_ajouter(Ui.label("Au combat : %d / %d" % [eq, Partie.places_ombres()], 26, Color(0.4, 1.0, 0.45), 7), Vector2(330, 86))
	_ajouter(Ui.label("Éveils ratés : %d / %d" % [Partie.echecs_eveil, Partie.PITIE + 1], 18, Color(0.75, 0.65, 1.0)), Vector2(640, 92))
	var l := Partie.ombres.duplicate()
	l.sort_custom(func (a, b):
		if a["eq"] != b["eq"]:
			return a["eq"]
		return Partie.dps_ombre(a) > Partie.dps_ombre(b))
	if l.is_empty():
		_ajouter(Ui.label("Aucune ombre pour l'instant.\nAprès une victoire, touche ÉVEIL pour lever le monstre vaincu.", 24, Color(0.85, 0.85, 1.0)), Vector2(60, 240))
	else:
		_grille(l, Vector2(36, 140), 6, 2, Vector2(150, 166), func (o):
			var e: Dictionary = Partie.ESPECES[o["espece"]]
			var rang: int = Partie.rang_ombre(o)
			var c := Ui.carte(e["nom"], e["icone"], Partie.RANGS[rang], Partie.COULEURS_RANG[rang], o["eq"],
				("★".repeat(o["etoiles"]) + " " if o["etoiles"] > 0 else "") + "%s/s" % Fx.court(Partie.dps_ombre(o)),
				Vector2(150, 166), "rouge" if Partie.ombre_rouge(o) else "")
			c.pressed.connect(func (): _montrer_detail("ombre", o))
			return c)
	var m := Ui.bouton("Équiper le meilleur", Ui.VERT, Vector2(260, 54))
	m.pressed.connect(func ():
		Partie.meilleures_ombres()
		Fx.son("confirm", -4.0))
	_ajouter(m, Vector2(36, 532))
	var t := Ui.bouton("Tout déséquiper", Color(0.1, 0.6, 0.75), Vector2(240, 54))
	t.pressed.connect(func ():
		for o in Partie.ombres:
			o["eq"] = false
		Partie.change.emit())
	_ajouter(t, Vector2(312, 532))
	_ajouter(Ui.label("3 ombres identiques fusionnent\nen une ombre ★ plus puissante.", 17, Color(0.7, 0.7, 0.95)), Vector2(580, 534))


const COULEURS_POINTS := {"ombres": Color(0.62, 0.35, 1.0), "arme": Color(1.0, 0.25, 0.3), "vitesse": Color(0.3, 0.95, 0.9),
	"legion": Color(0.85, 0.55, 1.0), "pieces": Color(1.0, 0.78, 0.2), "eveil": Color(0.3, 0.95, 0.45),
	"vie": Color(1.0, 0.4, 0.45), "mana": Color(0.4, 0.6, 1.0), "portee": Color(0.75, 0.45, 1.0), "vit_ombre": Color(0.55, 0.85, 1.0)}
const DESC_POINTS := {"ombres": "+0,1 % de dégâts des ombres par point", "arme": "+0,1 % de dégâts de l'arme par point",
	"vitesse": "+0,1 % de vitesse de course par point (max 250)", "legion": "+1 ombre au combat tous les 5 points (max 20)",
	"pieces": "+0,1 % de pièces gagnées par point", "eveil": "+0,1 point de chance d'éveil par point (max 300)",
	"vie": "+0,1 % de points de vie (toi et tes ombres)", "mana": "+0,1 % de mana max et de régénération",
	"portee": "+0,1 m de portée d'attaque des ombres (max 120)", "vit_ombre": "+0,1 % de vitesse des ombres (max 500)"}
const ICONES_POINTS := {"ombres": "ombres", "arme": "attack", "vitesse": "sprint", "legion": "q_skills", "pieces": "cash", "eveil": "arise",
	"vie": "role_heal", "mana": "essence", "portee": "cmd_attack", "vit_ombre": "q_run"}
var _defil_stats := 0

func _stats() -> void:
	_ajouter(Ui.label("Niveau %d" % Partie.niveau, 30, Color.WHITE, 8), Vector2(40, 80))
	var libres := Partie.points_libres()
	_ajouter(Ui.label("Points à répartir : %d" % libres, 26, Color(0.4, 1.0, 0.45) if libres > 0 else Color(0.7, 0.7, 0.8), 7), Vector2(230, 84))
	_ajouter(Ui.label("+%d par niveau" % Partie.POINTS_PAR_NIVEAU, 18, Color(0.7, 0.75, 1.0)), Vector2(560, 92))
	var sc := ScrollContainer.new()
	sc.size = Vector2(700, 404)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 14
	_ajouter(sc, Vector2(30, 126))
	var zone := Control.new()
	zone.custom_minimum_size = Vector2(690, Partie.ORDRE_POINTS.size() * 68.0 + 4.0)
	sc.add_child(zone)
	var y := 2.0
	for k in Partie.ORDRE_POINTS:
		var c: Color = COULEURS_POINTS[k]
		var ligne := Panel.new()
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.07, 0.18), c.darkened(0.2), 2, 10))
		ligne.size = Vector2(680, 62)
		ligne.position = Vector2(4, y)
		zone.add_child(ligne)
		var ic := TextureRect.new()
		ic.texture = Ui.tex(ICONES_POINTS[k])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(48, 48)
		ic.position = Vector2(10, 7)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(ic)
		var nom := Ui.label(Partie.POINTS[k], 24, c, 7)
		nom.position = Vector2(68, 2)
		ligne.add_child(nom)
		var desc := Ui.label(DESC_POINTS[k], 15, Color(0.85, 0.85, 0.95), 4)
		desc.position = Vector2(68, 36)
		ligne.add_child(desc)
		var val := str(Partie.points[k])
		if k == "legion":
			val += "  (+%d)" % (Partie.points[k] / Partie.LEGION_PAR_PLACE)
		elif Partie.MAX_POINTS.has(k):
			val += "/%d" % Partie.MAX_POINTS[k]
		var lv := Ui.label(val, 22, c, 8)
		lv.position = Vector2(410, 14)
		ligne.add_child(lv)
		var plein: bool = Partie.MAX_POINTS.has(k) and Partie.points[k] >= Partie.MAX_POINTS[k]
		var cle: String = k
		var x := 524.0
		for n in [1, 10]:
			var b := Ui.bouton("+%d" % n, Ui.VERT if n == 1 else Color(0.1, 0.55, 0.25), Vector2(68, 50), 22 if n == 1 else 20)
			b.disabled = libres <= 0 or plein
			var nb: int = n
			b.pressed.connect(func (): Partie.depenser_point(cle, nb))
			b.position = Vector2(x, 6)
			ligne.add_child(b)
			x += 76.0
		y += 68.0
	sc.get_v_scroll_bar().value_changed.connect(func (v): _defil_stats = int(v))
	sc.set_deferred("scroll_vertical", _defil_stats)
	var r := Ui.bouton("Réinitialiser les points", Ui.ROUGE, Vector2(300, 48), 20)
	r.pressed.connect(func (): Partie.reinitialiser_points())
	_ajouter(r, Vector2(40, 542))
	_ajouter(Ui.label("Ombres : %d  ·  Portée %.1f m" % [Partie.places_ombres(), Partie.portee_ombres()], 20, Color(0.8, 0.65, 1.0)), Vector2(360, 554))


func _boutique() -> void:
	_ajouter(Ui.label("BOUTIQUE", 34, Color.WHITE, 8), Vector2(36, 80))
	var offres := [
		["auto", "Instinct de meute", "Tes ombres frappent seules tout ennemi dans leur portée,\nsans que tu aies à cibler. Achat définitif.", 60000, "cmd_attack"],
		["soin", "Potion de soin", "Rend tous tes points de vie.", 150 * Partie.niveau, "role_heal"],
		["mana", "Fiole de mana", "Remplit ta réserve de mana (rappel des ombres).", 250 * Partie.niveau, "essence"],
	]
	var y := 140.0
	for of in offres:
		var id: String = of[0]
		var prix: int = of[3]
		var ligne := Panel.new()
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.07, 0.18), Color(0.4, 0.5, 1.0), 2, 10))
		ligne.size = Vector2(740, 112)
		_ajouter(ligne, Vector2(36, y))
		var ic := TextureRect.new()
		ic.texture = Ui.tex(of[4])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(72, 72)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ajouter(ic, Vector2(50, y + 20))
		_ajouter(Ui.label(of[1], 26, Color(0.85, 0.9, 1.0), 7), Vector2(136, y + 8))
		_ajouter(Ui.label(of[2], 16, Color(0.8, 0.82, 0.95), 4), Vector2(136, y + 46))
		if id == "auto" and Partie.achats_boutique.has("auto"):
			var t := Ui.bouton("ACTIVÉ" if Partie.auto_ombres else "DÉSACTIVÉ", Ui.VERT if Partie.auto_ombres else Ui.ROUGE, Vector2(170, 56), 20)
			t.pressed.connect(func ():
				Partie.auto_ombres = not Partie.auto_ombres
				Partie.change.emit())
			_ajouter(t, Vector2(590, y + 28))
		else:
			var b := Ui.bouton(Fx.court(prix), Ui.OR, Vector2(170, 56), 22)
			b.disabled = Partie.pieces < prix
			b.pressed.connect(func ():
				if Partie.pieces < prix:
					return
				Partie.pieces -= prix
				match id:
					"auto":
						Partie.achats_boutique["auto"] = true
						Partie.auto_ombres = true
					"soin":
						Partie.pv = Partie.pv_max()
					"mana":
						Partie.mana = Partie.mana_max()
				Fx.son("coins", -2.0)
				Partie.sauver()
				Partie.change.emit())
			_ajouter(b, Vector2(590, y + 28))
		y += 126.0


func _index() -> void:
	var y := 86.0
	var toutes: Array = Partie.ESPECES.keys()
	var pages := ceili(toutes.size() / 5.0)
	_page = clampi(_page, 0, pages - 1)
	if pages > 1:
		var g := Ui.bouton("◀", Ui.BLEU, Vector2(64, 48), 30)
		g.disabled = _page == 0
		g.pressed.connect(func ():
			_page -= 1
			_construire())
		_ajouter(g, Vector2(600, 12))
		_ajouter(Ui.label("%d / %d" % [_page + 1, pages], 24, Color.WHITE, 7), Vector2(676, 22))
		var d := Ui.bouton("▶", Ui.BLEU, Vector2(64, 48), 30)
		d.disabled = _page >= pages - 1
		d.pressed.connect(func ():
			_page += 1
			_construire())
		_ajouter(d, Vector2(740, 12))
	for esp in toutes.slice(_page * 5, _page * 5 + 5):
		var e: Dictionary = Partie.ESPECES[esp]
		var rang: int = e["rang"]
		var c: Color = Partie.COULEURS_RANG[rang]
		var ligne := Panel.new()
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.07, 0.18), c.darkened(0.25), 2, 10))
		ligne.size = Vector2(840, 90)
		_ajouter(ligne, Vector2(30, y))
		var ic := TextureRect.new()
		ic.texture = Ui.tex(e["icone"])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(78, 78)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ajouter(ic, Vector2(40, y + 6))
		_ajouter(Ui.label("[%s] %s" % [Partie.RANGS[rang], e["nom"]], 26, c, 7), Vector2(130, y + 8))
		var ch := Partie.chance_eveil(esp) * 100.0
		var lieu: String = {"donjon": "  ·  Donjon E", "evenement": "  ·  Événement"}.get(e.get("lieu", ""), "")
		var chrono := "Chrono global" if e.get("lieu", "") == "donjon" else "Chrono %d s" % int(e["temps"])
		_ajouter(Ui.label("Vie %s  ·  %s  ·  Éveil %s %%%s" % [Fx.court(e["pv"]), chrono, ("%.2f" % ch) if ch < 1.0 else str(int(round(ch))), lieu], 18, Color(0.85, 0.88, 1.0), 4), Vector2(130, y + 52))
		var v := Partie.verdict(esp)
		if e.get("lieu", "") != "donjon":
			_ajouter(Ui.label(v["texte"], 26, v["couleur"], 7), Vector2(650, y + 10))
		var pq := Partie.palier_quete(esp)
		var qt := "Levés : %d / %d" % [int(Partie.arises.get(esp, 0)), pq] if pq > 0 else "Quête d'éveil finie"
		_ajouter(Ui.label("Vaincus : %d  ·  %s" % [int(Partie.tues.get(esp, 0)), qt], 16, Color(0.8, 0.8, 0.9)), Vector2(560, y + 54))
		var mo: Dictionary = Partie.MONNAIES[e.get("monnaie", "eclat")]
		_ajouter(Ui.label(mo["nom"], 15, mo["couleur"], 4), Vector2(560, y + 34))
		y += 100.0


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_poser(ev.index, ev.position)
		else:
			_lever(ev.index, ev.position)
	elif ev is InputEventScreenDrag:
		_glisser(ev.index, ev.position, ev.relative)

func _sur_interface(p: Vector2) -> bool:
	if _panneau and _panneau.get_global_rect().has_point(p):
		return true
	for k in _hex:
		if _hex[k].get_global_rect().has_point(p):
			return true
	for c in [_evt, _quitter]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false

func _dans(c: Control, p: Vector2) -> bool:
	return c.visible and p.distance_to(c.position + c.size / 2.0) < c.size.x / 2.0 + 8.0

func _poser(i: int, p: Vector2) -> void:
	if _sur_interface(p):
		_doigts[i] = {"role": "ui"}
		return
	if _panneau:
		_doigts[i] = {"role": "ui"}
		fermer()
		return
	for k in _b_comp:
		if _dans(_b_comp[k], p):
			_doigts[i] = {"role": "bouton"}
			_b_comp[k].set_meta("appuye", 1.0)
			Input.vibrate_handheld(10)
			var err: String = ville.joueur.competence(k)
			if err != "":
				dire(err, Color(1.0, 0.6, 0.5))
				Fx.son("error", -8.0)
			return
	for pair in [[_b_frapper, "frapper"], [_b_eveil, "eveil"], [_b_action, "action"]]:
		if _dans(pair[0], p):
			_doigts[i] = {"role": "bouton"}
			pair[0].set_meta("appuye", 1.0)
			pair[0].queue_redraw()
			Input.vibrate_handheld(10)
			if pair[1] == "frapper":
				ville.frapper()
			elif pair[1] == "action":
				agir()
			else:
				ville.eveiller()
			return
	if p.x < _taille.x * 0.42 and p.y > _taille.y * 0.4:
		_doigts[i] = {"role": "joy"}
		_joy_actif = true
		_joy_centre = p
		_joy_pos = p
		return
	_doigts[i] = {"role": "camera", "depart": p, "t": Time.get_ticks_msec()}

func _glisser(i: int, p: Vector2, rel: Vector2) -> void:
	var d: Dictionary = _doigts.get(i, {})
	match d.get("role", ""):
		"joy":
			_joy_pos = _joy_centre + (p - _joy_centre).limit_length(JOY_R)
		"camera":
			ville.tourner_camera(rel)

func _lever(i: int, p: Vector2) -> void:
	var d: Dictionary = _doigts.get(i, {})
	if d.get("role", "") == "joy":
		_joy_actif = false
		_joy_centre = Vector2(170, _taille.y - 160)
		_joy_pos = _joy_centre
	elif d.get("role", "") == "camera":
		if p.distance_to(d["depart"]) < 18.0 and Time.get_ticks_msec() - int(d["t"]) < 350:
			ville.toucher_monde(p)
	_doigts.erase(i)


func _maj_action() -> void:
	_action = ville.action_proche() if _panneau == null else {}
	var v := not _action.is_empty()
	if v:
		var t: String = {"autel": "PARLER", "donjon": "ENTRER", "sortir": "SORTIR"}[_action["type"]]
		_b_action.set_meta("texte", t)
	if v != _b_action.visible:
		_b_action.visible = v
		if v:
			_b_action.scale = Vector2.ONE * 0.6
			var tw := _b_action.create_tween()
			tw.tween_property(_b_action, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_b_action.queue_redraw()

func agir() -> void:
	match _action.get("type", ""):
		"autel":
			_autel = _action["autel"]
			_bande = []
			_roll_txt = ""
			ouvrir("autel")
			Fx.son("open", -4.0)
		"donjon":
			ouvrir("donjon")
			Fx.son("portal", -6.0)
		"sortir":
			fermer()
			ville.quitter_donjon()


func _dessiner_evt() -> void:
	var c := _evt
	var r := Rect2(Vector2.ZERO, c.size)
	var b: Monstre = ville.boss_evt
	var actif := b != null and is_instance_valid(b)
	var t: float = ville.evt_restant() if actif else ville.temps_avant_evt()
	var tt := "%02d:%02d" % [int(maxf(t, 0)) / 60, int(maxf(t, 0)) % 60]
	if actif:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		c.draw_style_box(Ui.boite(Color(0.25, 0.02, 0.08, 0.9), Color(1.0, 0.25, 0.35).lerp(Color(1, 0.8, 0.8), pulse * 0.4), 3, 12), r)
		c.draw_texture_rect(Ui.tex("sh_baran"), Rect2(6, 2, 40, 40), false)
		_texte(c, Vector2(52, 20), "ÉVÉNEMENT  ·  BARAN" if not b.mort else "BARAN VAINCU", 17, Color(1.0, 0.75, 0.75), 5)
		_texte(c, Vector2(52, 38), ("Touche pour y aller  ·  " + tt) if not b.mort else "Lève son ombre !", 15, Color(1.0, 0.9, 0.9), 5)
	else:
		c.draw_style_box(Ui.boite(Color(0.06, 0.03, 0.14, 0.82), Color(0.6, 0.3, 0.9, 0.8), 2, 12), r)
		c.draw_texture_rect(Ui.tex("sh_baran"), Rect2(6, 2, 40, 40), false)
		_texte(c, Vector2(52, 20), "Roi des démons", 17, Color(0.85, 0.7, 1.0), 5)
		_texte(c, Vector2(52, 38), "Prochain événement dans " + tt, 15, Color(0.85, 0.85, 0.95), 5)


func _dessiner_fleche() -> void:
	var b: Monstre = ville.boss_evt
	if b == null or not is_instance_valid(b) or b.mort or ville.donjon != null:
		return
	var cam: Camera3D = ville.camera
	var p3 := b.global_position + Vector3(0, 3.0, 0)
	var derriere := cam.is_position_behind(p3)
	var p := cam.unproject_position(p3)
	var marge := 70.0
	var dedans := not derriere and p.x > marge and p.x < _taille.x - marge and p.y > marge and p.y < _taille.y - marge
	if dedans:
		return
	var ctr := _taille / 2.0
	var d := (p - ctr)
	if derriere:
		d = -d
	if d.length() < 1.0:
		d = Vector2(0, -1)
	d = d.normalized()
	var k := minf((ctr.x - marge) / maxf(absf(d.x), 0.001), (ctr.y - marge) / maxf(absf(d.y), 0.001))
	var pos := ctr + d * k

	pos.y = clampf(pos.y, 120.0, _taille.y - 250.0)
	pos.x = clampf(pos.x, 230.0, _taille.x - 120.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	var a := d.angle()
	var pts := PackedVector2Array([pos + Vector2.from_angle(a) * 30, pos + Vector2.from_angle(a + 2.5) * 22, pos + Vector2.from_angle(a - 2.5) * 22])
	_fleche.draw_colored_polygon(pts, Color(1.0, 0.25, 0.35, 0.7 + 0.3 * pulse))
	pts.append(pts[0])
	_fleche.draw_polyline(pts, Color(1, 0.9, 0.9), 3.0, true)
	var dist := int(ville.joueur.global_position.distance_to(b.global_position))
	var txt := "Baran  %d m" % dist
	var w := Ui.police.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_texte(_fleche, pos - d * 46 - Vector2(w / 2.0, -6), txt, 18, Color(1.0, 0.75, 0.75), 6)


func _dessiner_donjon() -> void:
	var dj: Donjon = ville.donjon
	if dj == null:
		return
	var c := _donj
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_style_box(Ui.boite(Color(0.08, 0.02, 0.14, 0.92), Color(0.75, 0.3, 1.0), 3, 12), r)
	var n := mini(dj.salle + 1, 6)
	_texte(c, Vector2(16, 28), "DONJON RANG E  ·  SALLE %d / 6" % n, 19, Color(0.85, 0.65, 1.0), 6)
	_texte(c, Vector2(16, 58), Donjon.NOMS_SALLES[mini(dj.salle, 5)], 24, Color.WHITE, 7)
	for k in 6:
		var col := Color(0.35, 0.2, 0.5)
		if k < dj.salle or (k == 5 and not dj.actif and dj.sortie):
			col = Color(0.45, 1.0, 0.5)
		elif k == dj.salle:
			col = Color(1.0, 0.75, 0.3)
		c.draw_circle(Vector2(300 + k * 22, 50), 8, col)
	var t := dj.temps
	var tt := "%d:%02d" % [int(t) / 60, int(t) % 60]
	var urgent := t < 45.0
	var tw := Ui.police.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_texte(c, Vector2(r.size.x - tw - 16, 56), tt, 40, Color(1, 0.3, 0.3) if urgent else Color.WHITE, 8)
	_texte(c, Vector2(r.size.x - 120, 22), "CHRONO", 14, Color(0.7, 0.85, 1.0), 4)
	if dj.actif:
		_texte(c, Vector2(300 - 8, 26), "Restants : %d" % dj.restants(), 16, Color(1.0, 0.6, 0.6), 5)

func _donjon_panneau() -> void:
	var puissance := Partie.dps_total()
	_ajouter(Ui.label("Repaire du roi gobelin", 32, Color(0.7, 0.85, 1.0), 8), Vector2(36, 82))
	_ajouter(Ui.label("DONJON DE RANG E", 22, Partie.COULEURS_RANG[0].lightened(0.2), 6), Vector2(36, 124))
	var lignes := ["6 salles à vider, une barrière s'ouvre à chaque salle nettoyée.",
		"Un seul chronomètre pour tout le donjon : 4 min 30.",
		"Salle 6 : Kargash, le roi gobelin.",
		"Les monstres du donjon ne se régénèrent pas."]
	var y := 160.0
	for l in lignes:
		_ajouter(Ui.label("•  " + l, 19, Color(0.88, 0.9, 1.0), 4), Vector2(40, y))
		y += 30.0
	var conseil := Donjon.PUISSANCE_CONSEILLEE
	var ok := puissance >= conseil
	_ajouter(Ui.label("Puissance conseillée : %s/s" % Fx.court(conseil), 21, Color(1.0, 0.8, 0.4), 6), Vector2(40, y + 12))
	_ajouter(Ui.label("Ta puissance : %s/s" % Fx.court(puissance), 21, Color(0.45, 1.0, 0.5) if ok else Color(1.0, 0.4, 0.4), 6), Vector2(40, y + 44))
	var rec := "Meilleur temps : %d:%02d" % [int(Partie.record_donjon) / 60, int(Partie.record_donjon) % 60] if Partie.record_donjon > 0 else "Pas encore terminé"
	_ajouter(Ui.label(rec + "   ·   Terminé %d fois" % Partie.donjons, 18, Color(0.75, 0.75, 0.9)), Vector2(40, y + 84))

	var b: Dictionary = Partie.OBJETS["croc_roi"]
	var carte := Ui.carte(b["nom"], b["icone"], "U", Partie.COULEURS_RARETE[Partie.UNIQUE], false, "%s/s" % Fx.court(b["dps"]), Vector2(190, 210), "unique")
	_ajouter(carte, Vector2(588, 84))
	_ajouter(Ui.label("Butin du boss", 18, Color(1.0, 0.8, 0.4), 5), Vector2(624, 300))
	var yy := 326.0
	for k in b["attrs"]:
		_ajouter(Ui.label("+%d %% %s" % [int(b["attrs"][k]), Partie.NOMS_STATS[k].to_lower()], 16, Color(0.95, 0.75, 1.0), 4), Vector2(596, yy))
		yy += 22.0
	var e := Ui.bouton("ENTRER", Ui.VERT, Vector2(300, 60), 26)
	e.pressed.connect(func ():
		fermer()
		ville.entrer_donjon())
	_ajouter(e, Vector2(40, 512))
	var a := Ui.bouton("Annuler", Ui.ROUGE, Vector2(200, 60), 22)
	a.pressed.connect(fermer)
	_ajouter(a, Vector2(360, 512))

var _gains := {}
func recompenses_donjon(g: Dictionary) -> void:
	_gains = g
	annonce("DONJON TERMINÉ", "Temps : %d:%02d%s" % [int(g["temps"]) / 60, int(g["temps"]) % 60, "  ·  NOUVEAU RECORD !" if g["record"] else ""], Color(1.0, 0.8, 0.3))
	await get_tree().create_timer(2.2).timeout
	ouvrir("recompenses")

func _recompenses_panneau() -> void:
	var g := _gains
	_ajouter(Ui.label("Kargash est vaincu !", 32, Color(1.0, 0.82, 0.35), 8), Vector2(36, 82))
	_ajouter(Ui.label("Temps : %d:%02d%s" % [int(g.get("temps", 0)) / 60, int(g.get("temps", 0)) % 60, "   NOUVEAU RECORD !" if g.get("record", false) else ""], 22, Color.WHITE, 6), Vector2(36, 130))
	_ajouter(Ui.label("+%s pièces" % Fx.court(g.get("pieces", 0)), 26, Color(1.0, 0.85, 0.3), 7), Vector2(40, 180))
	var y := 226.0
	for mn in g.get("monnaies", []):
		var d: Dictionary = Partie.MONNAIES[mn[0]]
		var ic := Control.new()
		ic.size = Vector2(36, 36)
		var cle: String = mn[0]
		ic.draw.connect(func (): _jeton(ic, Vector2(18, 18), 16.0, cle))
		_ajouter(ic, Vector2(40, y))
		_ajouter(Ui.label("+%d  %s" % [mn[1], d["pluriel"]], 22, (d["couleur"] as Color).lightened(0.3), 6), Vector2(86, y + 2))
		y += 46.0
	if g.get("unique", false):
		var b: Dictionary = Partie.OBJETS["croc_roi"]
		_ajouter(Ui.carte(b["nom"], b["icone"], "U", Partie.COULEURS_RARETE[Partie.UNIQUE], false, "ARME UNIQUE", Vector2(200, 220), "unique"), Vector2(510, 90))
		_ajouter(Ui.label("Équipe-la dans l'inventaire !", 18, Color(0.95, 0.75, 1.0), 5), Vector2(496, 320))
	else:
		_ajouter(Ui.label("Le Croc du roi n'est pas tombé cette fois\n(1 chance sur 3 après la première).", 18, Color(0.8, 0.75, 0.9), 5), Vector2(400, 200))
	_ajouter(Ui.label("Le portail de sortie s'est ouvert derrière toi.", 19, Color(0.6, 0.85, 1.0), 5), Vector2(40, 420))
	var ok := Ui.bouton("CONTINUER", Ui.VERT, Vector2(280, 58), 24)
	ok.pressed.connect(fermer)
	_ajouter(ok, Vector2(40, 470))


func _autel_panneau() -> void:
	var r: Dictionary = Partie.ROLLS[_autel]
	var m: String = r["monnaie"]
	var md: Dictionary = Partie.MONNAIES[m]
	var c: Color = Pnj.COULEURS[_autel]
	_ajouter(Ui.label(r["pnj"], 28, c.lightened(0.3), 8), Vector2(36, 80))
	var quoi := "dégâts des ombres" if _autel == "ombres" else("dégâts de l'arme" if _autel == "arme" else "chance d'éveil et pièces")
	_ajouter(Ui.label("Fais tourner la roue : un bonus permanent de %s, du rang E au rang A (A : 0,1 %)." % quoi, 17, Color(0.85, 0.85, 0.95), 4), Vector2(36, 118))

	var act: int = Partie.rolls[_autel]
	var cadre := Panel.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.07, 0.2), Partie.COULEURS_RANG[act] if act >= 0 else Color(0.3, 0.35, 0.6), 3, 12))
	cadre.size = Vector2(260, 92)
	_ajouter(cadre, Vector2(700, 76))
	_ajouter(Ui.label("Bonus équipé", 16, Color(0.75, 0.8, 1.0), 4), Vector2(716, 80))
	if act >= 0:
		_ajouter(Ui.label(Partie.RANGS[act], 50, Partie.COULEURS_RANG[act], 10), Vector2(718, 98))
		_ajouter(Ui.label(_texte_roll(_autel, act), 17, Color.WHITE, 5), Vector2(770, 116))
	else:
		_ajouter(Ui.label("Aucun", 30, Color(0.6, 0.6, 0.75), 7), Vector2(718, 110))

	if _bande.is_empty():
		_preparer_bande(-1)
	var bande := Control.new()
	bande.name = "Bande"
	bande.size = Vector2(920, 150)
	bande.clip_contents = true
	bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bande.draw.connect(_dessiner_bande.bind(bande))
	_ajouter(bande, Vector2(40, 182))

	var x := 40.0
	for k in Partie.PROBA_ROLL.size():
		var pr: float = Partie.PROBA_ROLL[k] * 100.0
		var t := "%s  %s%%" % [Partie.RANGS[k], ("%.1f" % pr) if pr < 1.0 else str(snappedf(pr, 0.1))]
		if pr >= 1.0 and pr == floor(pr):
			t = "%s  %d%%" % [Partie.RANGS[k], int(pr)]
		_ajouter(Ui.label(t, 19, Partie.COULEURS_RANG[k], 5), Vector2(x, 344))
		_ajouter(Ui.label(_texte_roll(_autel, k, true), 14, Color(0.8, 0.82, 0.95), 4), Vector2(x, 370))
		x += 184.0

	if _roll_txt != "":
		var lr := Ui.label(_roll_txt, 24, _roll_res.get("couleur", Color.WHITE), 7)
		lr.name = "Resultat"
		_ajouter(lr, Vector2(40, 404))

	var ic := Control.new()
	ic.size = Vector2(44, 44)
	ic.draw.connect(func (): _jeton(ic, Vector2(22, 22), 20.0, m))
	_ajouter(ic, Vector2(40, 452))
	_ajouter(Ui.label("%s : %d" % [md["pluriel"], int(Partie.monnaies[m])], 24, (md["couleur"] as Color).lightened(0.3), 7), Vector2(94, 458))
	var t1 := Ui.bouton("TOURNER  (1)", Ui.VERT, Vector2(250, 62), 24)
	t1.disabled = _roll_actif or int(Partie.monnaies[m]) <= 0
	t1.pressed.connect(func (): _lancer_roll(1))
	_ajouter(t1, Vector2(40, 518))
	var t10 := Ui.bouton("×10 AUTO", Ui.VIOLET, Vector2(190, 62), 22)
	t10.disabled = _roll_actif or int(Partie.monnaies[m]) < 2
	t10.pressed.connect(func (): _lancer_roll(mini(10, int(Partie.monnaies[m]))))
	_ajouter(t10, Vector2(304, 518))
	var prix := Partie.prix_monnaie(m)
	var ach := Ui.bouton("Acheter 1  (%s ●)" % Fx.court(prix), Ui.OR, Vector2(300, 62), 21)
	ach.disabled = _roll_actif or Partie.pieces < prix
	ach.pressed.connect(func ():
		if Partie.acheter_monnaie(m):
			Fx.son("coins", -4.0))
	_ajouter(ach, Vector2(508, 518))
	_ajouter(Ui.label("Ton meilleur rang\nest toujours gardé.", 15, Color(0.7, 0.75, 0.95), 4), Vector2(826, 524))

func _texte_roll(k: String, rang: int, court := false) -> String:
	var r: Dictionary = Partie.ROLLS[k]
	var v: float = r["valeurs"][rang]
	if k == "chance":
		return ("+%.1f éveil · +%d%% ●" if court else "+%.1f pt d'éveil · +%d %% pièces") % [v, int(r["valeurs2"][rang])]
	return ("+%d%%" if court else "+%d %% " + Partie.NOMS_STATS[r["stat"]].to_lower()) % int(v)


func _preparer_bande(resultat: int) -> void:
	_bande = []
	for k in 44:
		var x := Partie.tirer_rang()

		if randf() < 0.18:
			x = randi_range(3, 5)
		_bande.append(x)
	if resultat >= 0:
		_bande[ROLL_CIBLE] = resultat

func _decalage_roll() -> float:
	var fin := ROLL_CIBLE * ROLL_CASE - 460.0 + ROLL_CASE / 2.0
	if not _roll_actif:
		return fin if not _roll_res.is_empty() else 3.0 * ROLL_CASE
	var u := clampf(_roll_t / ROLL_DUREE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.4)
	return lerpf(2.0 * ROLL_CASE, fin + float(_roll_res.get("ecart", 0.0)), e)

func _dessiner_bande(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_style_box(Ui.boite(Color(0.02, 0.03, 0.1), Color(0.3, 0.45, 0.9, 0.8), 2, 12), r)
	var dec := _decalage_roll()
	for k in _bande.size():
		var x := k * ROLL_CASE - dec
		if x < -ROLL_CASE or x > r.size.x:
			continue
		var rg: int = _bande[k]
		var col: Color = Partie.COULEURS_RANG[rg]
		var box := Rect2(x + 6, 15, ROLL_CASE - 12, 120)
		c.draw_style_box(Ui.boite(col.darkened(0.72), col, 3, 10), box)
		for j in 6:
			var hh := 120.0 * 0.5 * (j + 1) / 6.0
			c.draw_rect(Rect2(box.position.x + 3, box.end.y - hh, box.size.x - 6, hh / 6.0 + 1), Color(col.r, col.g, col.b, 0.06 * (6 - j)))
		var lt: String = Partie.RANGS[rg]
		var w := Ui.police.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		_texte(c, Vector2(box.position.x + (box.size.x - w) / 2.0, 92), lt, 58, col.lightened(0.25), 9)
		var vt := _texte_roll(_autel, rg, true).split(" · ")[0]
		var w2 := Ui.police.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_texte(c, Vector2(box.position.x + (box.size.x - w2) / 2.0, 124), vt, 18, Color.WHITE, 5)

	var cx := r.size.x / 2.0
	c.draw_line(Vector2(cx, 4), Vector2(cx, r.size.y - 4), Color(1, 0.9, 0.4, 0.9), 3.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, 0), Vector2(cx + 12, 0), Vector2(cx, 14)]), Color(1, 0.85, 0.3))
	c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, r.size.y), Vector2(cx + 12, r.size.y), Vector2(cx, r.size.y - 14)]), Color(1, 0.85, 0.3))

	for k in 12:
		var a := 0.08 * (12 - k)
		c.draw_rect(Rect2(k * 6, 0, 6, r.size.y), Color(0.02, 0.03, 0.1, a))
		c.draw_rect(Rect2(r.size.x - (k + 1) * 6, 0, 6, r.size.y), Color(0.02, 0.03, 0.1, a))

func _lancer_roll(n: int) -> void:
	if _roll_actif:
		return
	var res := Partie.roll(_autel)
	if res.is_empty():
		return
	_roll_auto = n > 1 or _roll_serie > 0
	_roll_serie = n - 1
	_roll_res = res
	_roll_res["ecart"] = randf_range(- ROLL_CASE * 0.38, ROLL_CASE * 0.38)
	_preparer_bande(res["rang"])
	_roll_actif = true
	_roll_t = 0.0
	_roll_case = -1
	_roll_txt = ""
	_construire()

func _avancer_roll(dt: float) -> void:
	_roll_t += dt * (1.9 if _roll_auto else 1.0)
	if _panneau == null or _type != "autel":
		_roll_actif = false
		return
	var b: Control = _panneau.get_node_or_null("Bande")
	if b:
		b.queue_redraw()
	var idx := int((_decalage_roll() + 460.0) / ROLL_CASE)
	if idx != _roll_case:
		_roll_case = idx
		Fx.son("click", -14.0, 0.9 + 0.5 * clampf(_roll_t / ROLL_DUREE, 0, 1))
	if _roll_t >= ROLL_DUREE:
		_roll_actif = false
		var rg: int = _roll_res["rang"]
		var col: Color = Partie.COULEURS_RANG[rg]
		_roll_res["couleur"] = col.lightened(0.2)
		if _roll_res["mieux"]:
			_roll_txt = "Rang %s !  %s  —  nouveau bonus équipé" % [Partie.RANGS[rg], _texte_roll(_autel, rg)]
			Fx.son("levelup", -2.0 if rg >= 3 else -6.0)
			if rg >= 4:
				annonce("RANG %s !" % Partie.RANGS[rg], _texte_roll(_autel, rg), col)
		else:
			_roll_txt = "Rang %s — ton rang %s est conservé" % [Partie.RANGS[rg], Partie.RANGS[Partie.rolls[_autel]]]
			_roll_res["couleur"] = Color(0.75, 0.75, 0.85)
			Fx.son("select", -8.0)
		_construire()
		if _roll_serie > 0 and int(Partie.monnaies[Partie.ROLLS[_autel]["monnaie"]]) > 0:
			var reste := _roll_serie
			await get_tree().create_timer(0.55).timeout
			if _type == "autel" and not _roll_actif:
				_lancer_roll(reste)


func _sac() -> void:
	_ajouter(Ui.label("SAC", 34, Color.WHITE, 8), Vector2(36, 80))
	_ajouter(Ui.label("Bonus des autels : actifs en permanence", 20, Color(0.7, 0.8, 1.0)), Vector2(130, 92))
	var x := 36.0
	for k in ["ombres", "arme", "chance"]:
		var r: Dictionary = Partie.ROLLS[k]
		var rg: int = Partie.rolls[k]
		var col: Color = Partie.COULEURS_RANG[rg] if rg >= 0 else Color(0.3, 0.35, 0.6)
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", Ui.boite(Color(0.05, 0.07, 0.2), col, 3, 12))
		p.size = Vector2(280, 230)
		_ajouter(p, Vector2(x, 140))
		_ajouter(Ui.label(r["autel"], 22, Pnj.COULEURS[k].lightened(0.3), 6), Vector2(x + 16, 150))
		_ajouter(Ui.label(r["pnj"], 15, Color(0.75, 0.75, 0.9), 4), Vector2(x + 16, 180))
		if rg >= 0:
			_ajouter(Ui.label(Partie.RANGS[rg], 72, col, 12), Vector2(x + 110, 196))
			var lt := Ui.label(_texte_roll(k, rg), 16, Color.WHITE, 5)
			lt.size = Vector2(250, 40)
			lt.autowrap_mode = TextServer.AUTOWRAP_WORD
			lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_ajouter(lt, Vector2(x + 15, 300))
		else:
			_ajouter(Ui.label("Pas encore de bonus", 20, Color(0.6, 0.6, 0.75), 5), Vector2(x + 40, 250))
		x += 296.0
	var y := 394.0
	_ajouter(Ui.label("Monnaies", 24, Color.WHITE, 7), Vector2(36, y))
	var xx := 36.0
	for m in ["eclat", "insigne", "trefle"]:
		var d: Dictionary = Partie.MONNAIES[m]
		var ic := Control.new()
		ic.size = Vector2(40, 40)
		var cle: String = m
		ic.draw.connect(func (): _jeton(ic, Vector2(20, 20), 18.0, cle))
		_ajouter(ic, Vector2(xx, y + 40))
		_ajouter(Ui.label("%s : %d" % [d["pluriel"], int(Partie.monnaies[m])], 20, (d["couleur"] as Color).lightened(0.3), 6), Vector2(xx + 48, y + 46))
		xx += 296.0
	_ajouter(Ui.label("Les monnaies tombent des monstres (beaucoup plus des élites et des boss).\nVa voir les trois gardiens au pôle des chasseurs, en face du départ, pour tourner les roues.", 16, Color(0.78, 0.8, 0.95), 4), Vector2(36, 508))
