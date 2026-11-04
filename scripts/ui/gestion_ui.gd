class_name GestionUI
extends Control
## Gouverner façon Age of Empires : TRAVAIL (qui va au bois, aux champs, à la mine, au marché),
## ARMÉE (déployer tout ou partie de la garnison, garder, patrouiller, attaquer sur la mini-carte),
## GENS (appeler, duel, prison, bannissement, exécution). Le jeu continue derrière.

static var inst: GestionUI
var tab := "travail"
var _panel: PanelContainer
var _body: VBoxContainer
var _tabs: HBoxContainer
var _map: Minimap
var _sel_n := 5
var _pick := ""               # "garder" / "attaquer" / "patrouille" : en attente d'un point sur la carte
var _route: Array = []
var _duel_a: Node3D = null
var _filter := "tous"
var _status: Label
const GOLD := Color(1.0, 0.82, 0.45)

static func is_open() -> bool:
	return inst != null and inst.visible

func _ready() -> void:
	inst = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.055, 0.045, 0.94)
	sb.border_color = Color(0.75, 0.58, 0.3, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_panel.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var t := _label("Gouverner Valmont", 28, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var x := _btn("Fermer", Color(0.85, 0.5, 0.4))
	x.pressed.connect(close)
	top.add_child(x)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	root.add_child(_tabs)
	for tb in [["travail", "Travail"], ["armee", "Armée"], ["gens", "Gens du royaume"]]:
		var b := _btn(tb[1], GOLD)
		b.custom_minimum_size = Vector2(190, 46)
		var id: String = tb[0]
		b.pressed.connect(func():
			tab = id
			_pick = ""
			_route.clear()
			_duel_a = null
			refresh())
		_tabs.add_child(b)
	_status = _label("", 17, Color(0.85, 0.85, 0.9))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	root.add_child(hb)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 440)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(sc)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	_map = Minimap.new()
	_map.custom_minimum_size = Vector2(400, 400)
	_map.picked.connect(_on_pick)
	hb.add_child(_map)

func _label(s: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _btn(s: String, c := Color(0.9, 0.9, 0.95), enabled := true) -> Button:
	var b := Button.new()
	b.text = s
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 19)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.16, 0.12, 0.09)
	n.border_color = c * Color(1, 1, 1, 0.8)
	n.set_border_width_all(2)
	n.set_corner_radius_all(8)
	n.content_margin_left = 12
	n.content_margin_right = 12
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	var h := n.duplicate()
	h.bg_color = Color(0.26, 0.19, 0.12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", c)
	return b

func open(t := "") -> void:
	if t != "":
		tab = t
	visible = true
	refresh()

func close() -> void:
	visible = false
	_pick = ""
	_route.clear()
	_map.marks.clear()

func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()

func _row(items: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	for it in items:
		r.add_child(it)
	_body.add_child(r)
	return r

func refresh() -> void:
	var vs := get_viewport_rect().size
	_panel.position = Vector2(20, 16)
	_panel.size = Vector2(vs.x - 40, vs.y - 32)
	for i in _tabs.get_child_count():
		var b: Button = _tabs.get_child(i)
		b.modulate = Color(1, 1, 1) if ["travail", "armee", "gens"][i] == tab else Color(0.65, 0.65, 0.7)
	_clear()
	_map.marks = _route.duplicate()
	match tab:
		"travail": _travail()
		"armee": _armee()
		"gens": _gens()

# ------------------------------------------------------------------ TRAVAIL
func _travail() -> void:
	if Kingdom.inst == null:
		_status.text = "Le royaume n'est pas encore à vous."
		return
	var s := Kingdom.k()
	var cf := _btn("Appeler Gauthier, le contremaître (ordres chiffrés, rassemblement)", Color(1.0, 0.85, 0.5))
	cf.pressed.connect(func():
		close()
		Talk.call_foreman())
	_body.add_child(cf)
	_status.text = "Population %d · Au travail %d · Sans emploi %d · Nourriture %d · Bois %d · Pierre %d · Trésor %d" % [int(s["population"]), Kingdom.workers_total(), Kingdom.idle_people(), int(s["nourriture"]), int(s["bois"]), int(s["pierre"]), int(s["tresor"])]
	var jobs := [["ferme", "Champs (nourriture)", Color(0.95, 0.85, 0.4)], ["scierie", "Bûcherons (bois)", Color(0.6, 0.85, 0.45)], ["mine", "Mine (pierre et minerai)", Color(0.75, 0.78, 0.85)], ["marche", "Marché (or)", Color(1.0, 0.75, 0.3)]]
	for j in jobs:
		var bid: String = j[0]
		var d: Dictionary = Kingdom.data()["batiments"][bid]
		var b := Kingdom.bld(bid)
		var mx := int(d["ouvriers_max"]) + (int(b["niv"]) - 1) * 2
		var card := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.12, 0.09, 0.07)
		st.border_color = j[2]
		st.border_width_left = 6
		st.set_corner_radius_all(8)
		st.content_margin_left = 14
		st.content_margin_right = 10
		st.content_margin_top = 8
		st.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_label("%s — niveau %d" % [j[1], int(b["niv"])], 21, j[2]))
		var bar := ProgressBar.new()
		bar.max_value = mx
		bar.value = int(b["ouvriers"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 14)
		v.add_child(bar)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		v.add_child(r)
		r.add_child(_label("%d / %d ouvriers · +%.1f/min" % [int(b["ouvriers"]), mx, Kingdom.production(bid) * 60.0 / Kingdom.TICK], 18, Color(0.9, 0.9, 0.9)))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(sp)
		for delta in [-5, -1, 1, 5]:
			var bt := _btn(("%+d" % delta), GOLD, delta < 0 or Kingdom.idle_people() > 0)
			bt.custom_minimum_size = Vector2(62, 42)
			var dd: int = delta
			bt.pressed.connect(func():
				for k in absi(dd):
					Kingdom.set_workers(bid, 1 if dd > 0 else -1)
				refresh())
			r.add_child(bt)
		_body.add_child(card)
	_body.add_child(_label("Les ouvriers apparaissent sur leur chantier, outils et tenue de leur métier.", 16, Color(0.7, 0.7, 0.75)))

# ------------------------------------------------------------------ ARMÉE
func _armee() -> void:
	var dep := Army.alive()
	var total := int(Kingdom.res("soldats")) if Kingdom.inst else 0
	_status.text = "Soldats du royaume : %d · Déployés : %d · Garde rapprochée : %d · En réserve : %d" % [total, dep.size(), Escort.members.size(), Army.reserve()]
	if _pick != "":
		_status.text = {"garder": "Touchez la carte : où vos soldats doivent-ils tenir position ?", "attaquer": "Touchez la carte : quel camp attaquer ?", "patrouille": "Touchez la carte pour poser les points de la ronde (%d posés), puis « Valider la ronde »." % _route.size()}[_pick]
	_sel_n = clampi(_sel_n, 1, maxi(1, dep.size() + Army.reserve()))
	var minus := _btn("−", GOLD)
	minus.custom_minimum_size = Vector2(56, 46)
	minus.pressed.connect(func():
		_sel_n = maxi(1, _sel_n - 1)
		refresh())
	var lab := _label("  %d soldat%s  " % [_sel_n, "s" if _sel_n > 1 else ""], 22, Color.WHITE)
	var plus := _btn("+", GOLD)
	plus.custom_minimum_size = Vector2(56, 46)
	plus.pressed.connect(func():
		_sel_n += 1
		refresh())
	var ten := _btn("10", GOLD)
	ten.pressed.connect(func():
		_sel_n = 10
		refresh())
	var all := _btn("Toute l'armée", GOLD)
	all.pressed.connect(func():
		_sel_n = 999
		refresh())
	_row([_label("Sélection :", 19, GOLD), minus, lab, plus, ten, all])
	var orders := [["deployer", "Sortir de la caserne"], ["suivre", "Me suivre"], ["garder", "Tenir un point (carte)"], ["patrouille", "Patrouiller (carte)"], ["attaquer", "Attaquer (carte)"], ["passif", "Ne pas attaquer"], ["rentrer", "Rentrer à la caserne"]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for o in orders:
		var b := _btn(o[1], Color(0.75, 0.88, 1.0))
		b.custom_minimum_size = Vector2(290, 52)
		var oid: String = o[0]
		b.pressed.connect(func(): _army_order(oid))
		grid.add_child(b)
	_body.add_child(grid)
	if _pick == "patrouille" and _route.size() >= 2:
		var ok := _btn("Valider la ronde (%d points)" % _route.size(), Color(0.6, 1.0, 0.6))
		ok.custom_minimum_size = Vector2(300, 52)
		ok.pressed.connect(func():
			Army.order(_selection(), "patrouille", _route.duplicate())
			_route.clear()
			_pick = ""
			refresh())
		_body.add_child(ok)
	_body.add_child(_label("Les soldats sortis de la caserne arrivent par un portail près de vous si vous êtes loin du château.", 16, Color(0.7, 0.7, 0.75)))

func _selection() -> Array:
	var dep := Army.alive()
	if dep.size() < _sel_n:
		dep += Army.deploy(_sel_n - dep.size())
	return dep.slice(0, mini(_sel_n, dep.size()))

func _army_order(o: String) -> void:
	match o:
		"deployer":
			var made := Army.deploy(_sel_n)
			if Hud.inst:
				Hud.inst.show_message("%d soldats sortent de la caserne" % made.size() if made.size() > 0 else "Plus personne en réserve", Color(0.75, 0.88, 1.0))
		"garder", "attaquer", "patrouille":
			_pick = o
			_route.clear()
		_:
			Army.order(_selection(), o)
	refresh()

func _on_pick(w: Vector2) -> void:
	if tab != "armee" or _pick == "":
		return
	var p3 := Vector3(w.x, Terrain.height_at(w.x, w.y), w.y)
	if _pick == "patrouille":
		_route.append(p3)
		refresh()
		return
	if _pick == "attaquer":
		# on s'accroche au camp le plus proche du point touché
		var best := p3
		var bd := 40.0
		for z in Spawner.ZONES:
			var d := (z["pos"] as Vector2).distance_to(w)
			if d < bd:
				bd = d
				best = Vector3(z["pos"].x, Terrain.height_at(z["pos"].x, z["pos"].y), z["pos"].y)
		p3 = best
	Army.order(_selection(), _pick, [p3])
	_route = [p3]
	_pick = ""
	refresh()

# ------------------------------------------------------------------ GENS
func _gens() -> void:
	var p := Combat.player
	var everyone := People.all()
	var filters := [["tous", "Tous"], ["armes", "Gardes et soldats"], ["ouvriers", "Ouvriers"], ["habitants", "Habitants"], ["marchands", "Marchands"]]
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	for f in filters:
		var b := _btn(f[1], GOLD if _filter == f[0] else Color(0.7, 0.7, 0.75))
		var fid: String = f[0]
		b.pressed.connect(func():
			_filter = fid
			refresh())
		fr.add_child(b)
	_body.add_child(fr)
	var list := everyone.filter(func(n):
		var r := People.role(n)
		match _filter:
			"armes": return r in ["garde", "soldat"]
			"ouvriers": return r in ["bucheron", "mineur", "paysan"]
			"habitants": return r in ["habitant", "crieur"]
			"marchands": return r == "marchand"
		return true)
	list.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	_status.text = "%d personnes dans votre royaume." % everyone.size()
	if _duel_a != null:
		_status.text = "Duel : choisissez l'adversaire de %s (bouton « Contre lui »)." % People.nom(_duel_a)
	for n in list.slice(0, 40):
		var r := People.role(n)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var nm := _label("%s · %s · %d m" % [People.nom(n), People.role_label(r), int(n.global_position.distance_to(p.global_position))], 18, Color(0.95, 0.92, 0.85))
		nm.custom_minimum_size = Vector2(330, 0)
		row.add_child(nm)
		var nn: Node3D = n
		if _duel_a != null and _duel_a != n:
			var vs := _btn("Contre lui", Color(1.0, 0.7, 0.4))
			vs.pressed.connect(func(): _duel_choose(nn))
			row.add_child(vs)
		else:
			var a1 := _btn("Appeler", Color(0.7, 0.9, 1.0))
			a1.pressed.connect(func():
				People.summon(nn)
				refresh())
			row.add_child(a1)
			if nn.has_meta("retour_pos"):
				var a0 := _btn("Au travail", Color(0.7, 1.0, 0.7))
				a0.pressed.connect(func():
					People.send_back(nn)
					refresh())
				row.add_child(a0)
			var a2 := _btn("Duel", Color(1.0, 0.75, 0.4))
			a2.pressed.connect(func():
				_duel_a = nn
				refresh())
			row.add_child(a2)
			if n is Villager:
				var a3 := _btn("Prison", Color(0.85, 0.85, 0.6))
				a3.pressed.connect(func():
					Justice.arrest(nn, "sur ordre du souverain")
					refresh())
				row.add_child(a3)
				var a4 := _btn("Bannir", Color(0.9, 0.7, 0.5))
				a4.pressed.connect(func():
					Justice.banish(nn, "sur ordre du souverain")
					refresh())
				row.add_child(a4)
			var a5 := _btn("Exécuter", Color(1.0, 0.45, 0.4))
			a5.pressed.connect(func():
				People.execute(nn)
				refresh())
			row.add_child(a5)
		_body.add_child(row)

func _duel_choose(b: Node3D) -> void:
	var a := _duel_a
	_duel_a = null
	_clear()
	_status.text = "%s contre %s : quel duel ?" % [People.nom(a), People.nom(b)]
	var c1 := _btn("Au premier sang", Color(1.0, 0.85, 0.5))
	c1.custom_minimum_size = Vector2(280, 56)
	c1.pressed.connect(func():
		close()
		People.duel(a, b, false))
	var c2 := _btn("À mort", Color(1.0, 0.4, 0.35))
	c2.custom_minimum_size = Vector2(280, 56)
	c2.pressed.connect(func():
		close()
		People.duel(a, b, true))
	var c3 := _btn("Annuler", Color(0.7, 0.7, 0.75))
	c3.pressed.connect(refresh)
	_row([c1, c2, c3])
