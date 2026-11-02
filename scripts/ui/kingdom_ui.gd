class_name KingdomUI
extends Control
## Bureau royal : gestion du royaume par catégories (Économie, Population, Territoire, Bâtiments, Armée,
## Diplomatie, Personnages, Missions, Rapports). Le jeu est en pause tant que le bureau est ouvert.

static var inst: KingdomUI

const TABS := [
	["economie", "Économie"], ["population", "Population"], ["territoire", "Territoire"], ["batiments", "Bâtiments"],
	["armee", "Armée"], ["diplomatie", "Diplomatie"], ["personnages", "Personnages"], ["missions", "Missions"], ["rapports", "Rapports"],
]
const RES_NAMES := {"tresor": "Or", "nourriture": "Nourriture", "bois": "Bois", "pierre": "Pierre", "minerai": "Minerai"}
const ACCENT := Color(1, 0.82, 0.45)

var tab := "economie"
var _panel: Panel
var _tabs: VBoxContainer
var _tab_btns := {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _header: HBoxContainer
var _title: Label
var _toast: Label
var _toast_t := 0.0
var _sel_mission := ""

static func is_open() -> bool:
	return inst != null and is_instance_valid(inst) and inst.visible

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.075, 0.09, 0.97), ACCENT, 3, 16))
	add_child(_panel)
	_title = _label("", 34, ACCENT)
	_title.clip_text = true
	_panel.add_child(_title)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 18)
	_panel.add_child(_header)
	var close := _button("Fermer", Color(0.9, 0.4, 0.35))
	close.name = "Fermer"
	close.pressed.connect(close_ui)
	_panel.add_child(close)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_panel.add_child(_tabs)
	for t in TABS:
		var b := Button.new()
		b.text = "      " + t[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(230, 54)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		var ic := UiIcon.new().setup(t[0], 30)
		ic.position = Vector2(12, 12)
		b.add_child(ic)
		var id: String = t[0]
		b.pressed.connect(func(): show_tab(id))
		_tabs.add_child(b)
		_tab_btns[id] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_toast = _label("", 24, Color(1, 0.9, 0.6))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)

func _box(bg: Color, border: Color, bw := 0, r := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _label(t: String, fs := 22, c := Color(0.92, 0.92, 0.9), wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(t: String, c := ACCENT, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_stylebox_override("normal", _box(Color(0.16, 0.15, 0.17), c, 2, 8))
	b.add_theme_stylebox_override("hover", _box(Color(0.24, 0.21, 0.18), c, 2, 8))
	b.add_theme_stylebox_override("pressed", _box(Color(0.3, 0.26, 0.2), c, 2, 8))
	b.add_theme_stylebox_override("disabled", _box(Color(0.12, 0.12, 0.12), Color(0.35, 0.35, 0.35), 2, 8))
	b.disabled = not enabled
	return b

func _layout() -> void:
	var s := get_viewport_rect().size
	_panel.position = Vector2(24, 18)
	_panel.size = s - Vector2(48, 36)
	_title.position = Vector2(26, 12)
	_title.size = Vector2(_panel.size.x - 220, 46)
	_header.position = Vector2(26, 62)
	var close := _panel.get_node("Fermer") as Button
	close.position = Vector2(_panel.size.x - 160, 14)
	close.size = Vector2(140, 50)
	_tabs.position = Vector2(20, 118)
	_tabs.size = Vector2(240, _panel.size.y - 130)
	_scroll.position = Vector2(280, 118)
	_scroll.size = Vector2(_panel.size.x - 300, _panel.size.y - 134)
	_content.custom_minimum_size = Vector2(_scroll.size.x - 24, 0)
	_toast.position = Vector2(0, s.y - 70)
	_toast.size = Vector2(s.x, 40)

func open(t := "") -> void:
	if t != "":
		tab = t
	visible = true
	get_tree().paused = true
	GameState.get_inst().set_flag("bureau_ouvert")
	if Hud.inst:
		Hud.inst.pulse(null)
		Hud.inst.clear_hint("royaume")
	refresh()

func close_ui() -> void:
	visible = false
	get_tree().paused = false
	GameState.get_inst().save_game()

func show_tab(t: String) -> void:
	tab = t
	_scroll.scroll_vertical = 0
	refresh()

func toast(t: String, good := false) -> void:
	_toast.text = t
	_toast.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if good else Color(1, 0.65, 0.5))
	_toast_t = 2.5
	Sfx.play("ok" if good else "erreur", -8.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0, 1)

## Reconstruit le contenu de l'onglet (appelé après chaque action)
func refresh() -> void:
	var s := Kingdom.k()
	var gs := GameState.get_inst()
	_title.text = "Bureau royal de Valmont — Jour %d — %s" % [s["jour"], gs.titre]
	for c in _header.get_children():
		c.queue_free()
	for r in ["tresor", "nourriture", "bois", "pierre", "minerai"]:
		_header.add_child(_stat(r, str(int(s[r]))))
	_header.add_child(_stat("population", "%d/%d" % [s["population"], Kingdom.max_pop()]))
	_header.add_child(_stat("moral", "%d %%" % int(s["moral"])))
	_header.add_child(_stat("soldats", str(s["soldats"])))
	for id in _tab_btns:
		var b: Button = _tab_btns[id]
		b.add_theme_stylebox_override("normal", _box(Color(0.22, 0.19, 0.14) if id == tab else Color(0.12, 0.115, 0.13), ACCENT if id == tab else Color(0.3, 0.3, 0.32), 2, 8))
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match tab:
		"economie": _tab_economie()
		"population": _tab_population()
		"territoire": _tab_territoire()
		"batiments": _tab_batiments()
		"armee": _tab_armee()
		"diplomatie": _tab_diplomatie()
		"personnages": _tab_personnages()
		"missions": _tab_missions()
		"rapports": _tab_rapports()

func _stat(icon: String, v: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UiIcon.new().setup(icon, 28))
	h.add_child(_label(v, 22))
	return h

func _section(title: String, icon := "") -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.13, 0.125, 0.14), Color(0.32, 0.3, 0.28), 1, 10))
	_content.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if icon != "":
		h.add_child(UiIcon.new().setup(icon, 30))
	h.add_child(_label(title, 25, ACCENT))
	v.add_child(h)
	return v

func _row(parent: Control, text: String, btns: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(text, 21, Color(0.92, 0.92, 0.9), true)
	l.custom_minimum_size.x = 200
	h.add_child(l)
	for b in btns:
		h.add_child(b)
	parent.add_child(h)
	return h

func _act(b: Button, f: Callable) -> Button:
	b.pressed.connect(func():
		var err = f.call()
		if typeof(err) == TYPE_STRING and err != "":
			toast(err)
		else:
			Sfx.play("ok", -10.0)
		refresh())
	return b

func _bar(parent: Control, frac: float, col: Color) -> void:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 14)
	pb.show_percentage = false
	pb.value = clampf(frac, 0, 1) * 100.0
	pb.add_theme_stylebox_override("fill", _box(col, col, 0, 6))
	pb.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 6))
	parent.add_child(pb)

# ------------------------------------------------------------------ onglets
func _tab_economie() -> void:
	var s := Kingdom.k()
	var bal := Kingdom.daily_balance()
	var v := _section("Bilan quotidien", "economie")
	for r in ["tresor", "nourriture", "bois", "pierre", "minerai"]:
		var d: float = bal[r]
		_row(v, "%s : %d   (%s%.0f / jour)" % [RES_NAMES[r], int(s[r]), "+" if d >= 0 else "", d])
	_row(v, "Impôts : +%.0f  ·  Marché : +%.0f  ·  Solde de l'armée : -%.0f  ·  Nourriture consommée : %.0f / jour" % [Kingdom.tax_income(), Kingdom.production("marche"), Kingdom.army_upkeep(), Kingdom.food_need()])
	var t := _section("Impôt", "tresor")
	_row(t, "Un impôt lourd remplit le trésor mais fait chuter le moral (et la confiance des habitants).")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for i in 4:
		var lv := i
		var b := _button(Kingdom.IMPOTS[i], ACCENT if int(s["impot"]) == i else Color(0.4, 0.4, 0.42))
		b.custom_minimum_size = Vector2(150, 50)
		_act(b, func(): Kingdom.set_tax(lv))
		h.add_child(b)
	t.add_child(h)
	if bal["nourriture"] < 0:
		_row(v, "Attention : La nourriture baisse : affectez des ouvriers aux fermes ou améliorez-les.")

func _tab_population() -> void:
	var s := Kingdom.k()
	var gs := GameState.get_inst()
	var v := _section("Habitants", "population")
	_row(v, "Population : %d / %d (logements)" % [s["population"], Kingdom.max_pop()])
	_row(v, "Soldats : %d  ·  Ouvriers : %d  ·  Sans emploi : %d" % [s["soldats"], Kingdom.workers_total(), Kingdom.idle_people()])
	var m := _section("Moral : %d %%  (tendance : %d %%)" % [int(s["moral"]), int(Kingdom.moral_target())], "moral")
	_bar(m, float(s["moral"]) / 100.0, Color(0.4, 0.8, 0.4) if float(s["moral"]) >= 50 else Color(0.9, 0.5, 0.3))
	_row(m, "Le moral dépend de l'impôt, de la nourriture, de la sécurité (soldats, muraille, territoires libérés) et de la confiance des habitants. Au-dessus de 60 %, de nouvelles familles s'installent ; sous 30 %, des habitants partent.")
	var r := _section("Votre réputation", "personnages")
	_row(r, "Ce que le peuple pense de vous : %s" % {"adore": "il vous adore", "bon": "il vous apprécie", "neutre": "il vous observe", "craint": "il vous craint", "deteste": "il vous déteste"}[Vie.tier()])
	for k in [["reputation", "Réputation"], ["confiance_habitants", "Confiance des habitants"], ["bienveillance", "Bienveillance"], ["crainte", "Crainte inspirée"], ["arrogance", "Arrogance"], ["autorite", "Autorité"], ["mefiance", "Méfiance"]]:
		_row(r, "%s : %d" % [k[1], gs.val(k[0])])
		_bar(r, (gs.val(k[0]) + 50.0) / 100.0, Color(0.55, 0.7, 1.0))

func _tab_territoire() -> void:
	var s := Kingdom.k()
	var td: Dictionary = Kingdom.data()["territoires"]
	var v := _section("Terres de Valmont", "territoire")
	for id in td:
		var st: String = s["territoires"].get(id, "controle")
		var txt := "%s — %s" % [td[id]["nom"], {"controle": "sous contrôle", "menace": "menacé", "infeste": "aux mains des monstres"}.get(st, st)]
		if td[id].has("note") and st != "controle":
			txt += "\n" + String(td[id]["note"])
		var btns := []
		if st != "controle" and td[id].has("mission"):
			var mid: String = td[id]["mission"]
			var b := _button("Mission de conquête")
			b.pressed.connect(func():
				_sel_mission = mid
				show_tab("missions"))
			btns.append(b)
		_row(v, txt, btns)
	_row(v, "Un territoire libéré ne voit plus de créatures apparaître : une bannière de Valmont y est plantée.")

func _tab_batiments() -> void:
	var bd: Dictionary = Kingdom.data()["batiments"]
	for id in bd:
		var d: Dictionary = bd[id]
		var b := Kingdom.bld(id)
		var v := _section("%s — niveau %d" % [d["nom"], b["niv"]], "batiments")
		var info: String = d["desc"]
		if String(d["prod"]) != "":
			info += "  Production : %.1f %s / jour." % [Kingdom.production(id), RES_NAMES.get(d["prod"], d["prod"]).to_lower()]
		_row(v, info)
		if int(d["ouvriers_max"]) > 0:
			var mx := int(d["ouvriers_max"]) + (int(b["niv"]) - 1) * 2
			var bid: String = id
			_row(v, "Ouvriers : %d / %d" % [b["ouvriers"], mx], [
				_act(_button("  −  "), func(): Kingdom.set_workers(bid, -1)),
				_act(_button("  +  ", ACCENT, Kingdom.idle_people() > 0), func(): Kingdom.set_workers(bid, 1)),
			])
		var cost := Kingdom.cost_of(id)
		var parts := []
		for r in cost:
			parts.append("%d %s" % [cost[r], RES_NAMES.get(r, r).to_lower()])
		var why := Kingdom.upgrade_block_reason(id)
		var uid: String = id
		_row(v, "Amélioration : " + ", ".join(parts) + ("" if why == "" else "  (%s)" % why), [_act(_button("Améliorer", ACCENT, why == ""), func(): Kingdom.upgrade(uid))])

func _tab_armee() -> void:
	var s := Kingdom.k()
	var v := _section("Garde de Valmont", "armee")
	_row(v, "Soldats : %d / %d (caserne niv. %d)  ·  Équipement : niveau %d  ·  Puissance : %d" % [s["soldats"], Kingdom.max_soldiers(), Kingdom.bld("caserne")["niv"], s["equipement"], Kingdom.army_power()])
	_row(v, "Les soldats en plus de la garnison d'origine patrouillent visiblement dans le bourg. La puissance aide les missions de conquête et la diplomatie de la menace.")
	_row(v, "Recruter un soldat (%d or, un habitant sans emploi)" % Kingdom.recruit_cost(), [_act(_button("Recruter"), func(): return Kingdom.recruit())])
	var ec := Kingdom.equip_cost()
	_row(v, "Améliorer l'équipement : %d or, %d minerai" % [ec["tresor"], ec["minerai"]], [_act(_button("Forger", ACCENT, int(s["equipement"]) < 5), func(): return Kingdom.equip())])
	_row(v, "Solde : %.0f or / jour." % Kingdom.army_upkeep())
	var e := _section("Garde rapprochée (%d / %d)" % [Escort.members.size(), Escort.MAX], "armee")
	_row(e, "Vos gardes du corps vous suivent partout, combattent à vos côtés et peuvent ouvrir la marche ou garder un lieu. Vous pouvez aussi prendre un garde à son poste en lui parlant.")
	for sd in Escort.members.duplicate():
		if not is_instance_valid(sd):
			continue
		var s2: Soldier = sd
		_row(e, "%s — %s — %d PV" % [s2.nom, Escort.mode_name(s2.mode), int(s2.cbt.hp)], [
			_act(_button("Escorte"), func(): Escort.set_mode(s2, Soldier.M.ESCORTE)),
			_act(_button("Éclaireur"), func(): Escort.set_mode(s2, Soldier.M.ECLAIREUR)),
			_act(_button("Renvoyer"), func(): Escort.dismiss(s2)),
		])
	_row(e, "Appeler deux gardes depuis le château (%d disponibles)" % Escort.available(), [_act(_button("Appeler", ACCENT, Escort.available() > 0), func():
		if Escort.call_guards(2) == 0:
			return "Aucun soldat disponible (la garnison garde toujours deux hommes)"
		return "")])
	if Escort.members.size() > 0:
		_row(e, "", [_act(_button("Renvoyer toute la garde"), func(): Escort.dismiss_all())])
	var pr: Array = Kingdom.k()["prisonniers"]
	var j := _section("Prison du château (%d)" % pr.size(), "armee")
	if pr.is_empty():
		_row(j, "Aucun prisonnier. La prison se trouve dans la cour, près de la caserne.")
	for p in pr:
		_row(j, "%s — %s — depuis le jour %d. Allez lui parler à la prison pour décider de son sort." % [p["nom"], p["raison"], p["jour"]])

func _tab_diplomatie() -> void:
	var gs := GameState.get_inst()
	var fd: Dictionary = Kingdom.data()["factions"]
	for f in fd:
		var val := int(gs.factions.get(f, 0))
		var v := _section("%s — %s (%+d)" % [fd[f]["nom"], _stance(val), val], "diplomatie")
		_row(v, String(fd[f]["desc"]))
		_bar(v, (val + 100.0) / 200.0, Color(0.4, 0.8, 0.45) if val >= 0 else Color(0.9, 0.4, 0.35))
		var fid: String = f
		if f == "nains" and not gs.flag("portail_etudie"):
			_row(v, "Royaume inconnu : faites d'abord étudier le portail (mission de recherche).")
			continue
		if f == "vargas":
			_row(v, "Vargas refuse toute négociation. Seule la force le fera reculer." + ("\nRenseignements : il paie ses hommes avec l'or volé aux nains." if gs.flag("info_vargas") else ""))
			continue
		_row(v, "Actions directes (une fois par jour)", [
			_act(_button("Présents (30 or)"), func(): return Kingdom.faction_action(fid, "cadeau")),
			_act(_button("Menacer"), func(): return Kingdom.faction_action(fid, "menace")),
		])
	_row(_content, "Les ambassades (effets plus forts) se lancent depuis l'onglet Missions, catégorie diplomatique.")

func _stance(v: int) -> String:
	if v >= 50: return "allié"
	if v >= 15: return "amical"
	if v > -15: return "neutre"
	if v > -50: return "hostile"
	return "ennemi juré"

func _tab_personnages() -> void:
	var gs := GameState.get_inst()
	for id in gs.companions:
		var c: Dictionary = gs.companions[id]
		var etat: String = c.get("etat", "present")
		if etat == "mort":
			var v0 := _section("%s — tombé en mission" % c["nom"], "personnages")
			_row(v0, "Mort au service de Valmont.")
			continue
		var st: String = {"present": "disponible", "mission": "en mission", "blesse": "blessé"}.get(etat, etat)
		if etat == "blesse":
			st += " (encore %d min)" % maxi(1, int((float(c.get("blessure_fin", 0)) - Time.get_unix_time_from_system()) / 60.0) + 1)
		var v := _section("%s — %s — niveau %d (%s)" % [c["nom"], c.get("role", ""), c["niveau"], st], "personnages")
		if String(c.get("personnalite", "")) != "":
			_row(v, "Caractère : %s" % c["personnalite"])
		if String(c.get("apparence", "")) != "":
			_row(v, "Apparence : %s" % c["apparence"])
		_row(v, "Expérience : %d / %d" % [c["xp"], Companion.xp_to_next(int(c["niveau"]))])
		_bar(v, float(c["xp"]) / Companion.xp_to_next(int(c["niveau"])), Color(1, 0.8, 0.3))
		_row(v, "Loyauté : %d  ·  Relation : %d" % [c.get("loyaute", 0), c.get("relation", 0)])
		var comp: Dictionary = c["competences"]
		var parts := []
		for k in comp:
			parts.append("%s %d" % [String(k).capitalize(), comp[k]])
		_row(v, "Compétences : " + "  ·  ".join(parts))
	var r := _section("Cour royale", "personnages")
	_row(r, "Aldric III, roi de Valmont — relation : %d" % int(gs.mem("roi").get("relation", 0)))
	_row(r, "Recrutez des agents en parlant aux habitants et aux gardes (option « Rejoins-moi »).")

func _tab_missions() -> void:
	var gs := GameState.get_inst()
	var now := Time.get_unix_time_from_system()
	var cur := _section("Missions en cours", "missions")
	var any := false
	for r in gs.missions:
		if r["statut"] != "en_cours":
			continue
		any = true
		var m := Kingdom.mission_def(String(r["tpl"]))
		var left := maxf(0.0, float(r["fin"]) - now)
		_row(cur, "%s — %s — %d %% de réussite — retour dans %d min %02d s" % [m["nom"], gs.companions[r["agent"]]["nom"], int(float(r["chance"]) * 100), int(left) / 60, int(left) % 60])
		_bar(cur, 1.0 - left / maxf(1.0, float(r["fin"]) - float(r["debut"])), Color(0.55, 0.75, 1.0))
	if not any:
		_row(cur, "Aucune mission en cours.")
	var cats := {"conquete": "Conquête", "recherche": "Recherche", "diplomatique": "Diplomatie", "recolte": "Récolte", "generale": "Générales"}
	for cat in cats:
		var v := _section("Missions — " + cats[cat], "missions")
		var n := 0
		for m in Kingdom.data()["missions"]:
			if m["cat"] != cat or not Kingdom.mission_available(m):
				continue
			n += 1
			var mid: String = m["id"]
			var txt := "%s  (difficulté %d, %d min, compétence : %s)\n%s\nRisques : %s\nRécompenses : %s" % [m["nom"], m["difficulte"], int(m["duree"]) / 60, m["competence"], m["desc"], m["risques"], Kingdom._fx_text(m["recompenses"])]
			if _sel_mission == mid:
				txt = "» " + txt
			_row(v, txt)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			for aid in Kingdom.agents():
				if not Kingdom.agent_free(aid):
					continue
				var ag: String = aid
				var b := _button("%s (%d %%)" % [gs.companions[aid]["nom"], int(Kingdom.chance(m, aid) * 100)])
				_act(b, func():
					_sel_mission = ""
					var e := Kingdom.start_mission(mid, ag)
					if e == "":
						toast("Mission lancée", true)
					return e)
				h.add_child(b)
			if h.get_child_count() == 0:
				h.add_child(_label("Aucun agent disponible.", 20, Color(0.7, 0.7, 0.7)))
			v.add_child(h)
		if n == 0:
			_row(v, "Aucune mission disponible pour l'instant.")

func _tab_rapports() -> void:
	var gs := GameState.get_inst()
	var v := _section("Rapports et chroniques", "rapports")
	if gs.reports.is_empty():
		_row(v, "Aucun rapport pour l'instant.")
	for r in gs.reports:
		_row(v, "Jour %d — %s" % [r.get("jour", 1), r["t"]])
