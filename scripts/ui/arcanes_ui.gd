class_name ArcanesUI
extends Control
## Chambre des Arcanes (bibliothèque du château) : découvrir, débloquer, améliorer et équiper les pouvoirs
## dans les 4 emplacements actifs. On ne peut changer d'équipement qu'ici. Le jeu est en pause tant que
## la fenêtre est ouverte ; « Essayer » renvoie dans la chambre avec des mannequins et le mana gratuit.

const CENTER := Vector3(-15.0, 13.0, -137.0)
const ACCENT := Color(0.65, 0.5, 1.0)
static var inst: ArcanesUI

var sel := "main_invisible"
var cat := "telekinesie"
var _panel: Panel
var _title: Label
var _slots_box: HBoxContainer
var _cats: HBoxContainer
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _toast: Label
var _toast_t := 0.0
var _slot_btns: Array = []

static func is_open() -> bool:
	return inst != null and is_instance_valid(inst) and inst.visible

static func near(p: Vector3) -> bool:
	return p.distance_to(CENTER) < 3.4

## Joueur dans la chambre (entraînement libre)
static func in_chamber(p: Vector3) -> bool:
	return p.x > -21.0 and p.x < -9.0 and p.z > -145.0 and p.z < -128.0 and absf(p.y - 13.0) < 1.5

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.04, 0.09, 0.97), ACCENT, 3, 16))
	add_child(_panel)
	_title = _label("Chambre des Arcanes", 32, Color(0.85, 0.75, 1.0))
	_panel.add_child(_title)
	var close := _button("Fermer", Color(0.9, 0.4, 0.35))
	close.name = "Fermer"
	close.pressed.connect(close_ui)
	_panel.add_child(close)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 14)
	_panel.add_child(_slots_box)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		var ic := ActionButton.new().setup("feu", 22.0, Color.WHITE)
		ic.position = Vector2(6, 9)
		b.add_child(ic)
		var k := i
		b.pressed.connect(func(): _equip(k))
		_slots_box.add_child(b)
		_slot_btns.append(b)
	_cats = HBoxContainer.new()
	_cats.add_theme_constant_override("separation", 8)
	_panel.add_child(_cats)
	for c in SpellDB.CATS:
		var b := _button(SpellDB.CATS[c], ACCENT)
		var cc: String = c
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func():
			cat = cc
			refresh())
		b.set_meta("cat", c)
		_cats.add_child(b)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail)
	_toast = _label("", 24, Color(1, 0.9, 0.6))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)

func _box(bg: Color, border: Color, bw := 0, r := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _label(t: String, fs := 20, c := Color(0.92, 0.92, 0.95), wrap := false) -> Label:
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
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_stylebox_override("normal", _box(Color(0.12, 0.1, 0.16), c, 2, 8))
	b.add_theme_stylebox_override("hover", _box(Color(0.2, 0.16, 0.26), c, 2, 8))
	b.add_theme_stylebox_override("pressed", _box(Color(0.26, 0.2, 0.34), c, 2, 8))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3), 2, 8))
	b.disabled = not enabled
	return b

func _layout() -> void:
	var s := get_viewport_rect().size
	_panel.position = Vector2(20, 14)
	_panel.size = s - Vector2(40, 28)
	_title.position = Vector2(24, 10)
	var close := _panel.get_node("Fermer") as Button
	close.position = Vector2(_panel.size.x - 150, 12)
	close.size = Vector2(130, 48)
	_slots_box.position = Vector2(24, 64)
	_cats.position = Vector2(24, 138)
	_list_scroll.position = Vector2(24, 194)
	_list_scroll.size = Vector2(_panel.size.x * 0.42, _panel.size.y - 206)
	_list.custom_minimum_size = Vector2(_list_scroll.size.x - 16, 0)
	_detail_scroll.position = Vector2(_panel.size.x * 0.42 + 44, 194)
	_detail_scroll.size = Vector2(_panel.size.x * 0.58 - 68, _panel.size.y - 206)
	_detail.custom_minimum_size = Vector2(_detail_scroll.size.x - 16, 0)
	_toast.position = Vector2(0, s.y - 64)
	_toast.size = Vector2(s.x, 40)

func open() -> void:
	visible = true
	get_tree().paused = true
	refresh()

func close_ui() -> void:
	visible = false
	get_tree().paused = false
	Progression.get_inst().save_if_dirty()

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

func refresh() -> void:
	var prog := Progression.get_inst()
	_title.text = "Chambre des Arcanes — %d or — niveau %d" % [prog.gold, prog.level]
	for i in 4:
		var id: String = prog.slots[i]
		var b: Button = _slot_btns[i]
		b.text = "        %d. %s" % [i + 1, SpellDB.DEFS[id]["nom"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var ic: ActionButton = b.get_child(0)
		ic.icon = SpellDB.DEFS[id]["icone"]
		ic.accent = SpellDB.DEFS[id]["couleur"]
		ic._sig = ""
		ic.queue_redraw()
		b.add_theme_stylebox_override("normal", _box(Color(0.1, 0.09, 0.14), ACCENT, 2, 8))
	for b in _cats.get_children():
		b.add_theme_stylebox_override("normal", _box(Color(0.24, 0.18, 0.34) if b.get_meta("cat") == cat else Color(0.1, 0.09, 0.13), ACCENT if b.get_meta("cat") == cat else Color(0.3, 0.3, 0.35), 2, 8))
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for id in SpellDB.DEFS:
		var d: Dictionary = SpellDB.DEFS[id]
		if d.get("cat", "base") != cat:
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		var st := _state(id)
		b.text = "          %s   %s" % [d["nom"], st]
		var on: bool = id == sel
		b.add_theme_stylebox_override("normal", _box(Color(0.2, 0.15, 0.3) if on else Color(0.09, 0.08, 0.12), d["couleur"] if on else Color(0.25, 0.25, 0.3), 2, 8))
		var ic := ActionButton.new().setup(d["icone"], 24.0, d["couleur"])
		ic.position = Vector2(6, 6)
		ic.locked_text = "" if _owned(id) else " "
		b.add_child(ic)
		var sid: String = id
		b.pressed.connect(func():
			sel = sid
			refresh())
		_list.add_child(b)
	_fill_detail()

func _owned(id: String) -> bool:
	var pc: PlayerCombat = Combat.player.combat if Combat.player else null
	return pc != null and pc.spell_unlocked(id)

func _state(id: String) -> String:
	var prog := Progression.get_inst()
	if prog.slots.has(id):
		return "· équipé"
	if _owned(id):
		return "· rang %d" % prog.rank(id)
	var d: Dictionary = SpellDB.DEFS[id]
	return "· niv. %d" % d["niveau"]

func _fill_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var d: Dictionary = SpellDB.DEFS[sel]
	var prog := Progression.get_inst()
	var pc: PlayerCombat = Combat.player.combat
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var big := ActionButton.new().setup(d["icone"], 40.0, d["couleur"])
	big.custom_minimum_size = Vector2(84, 84)
	head.add_child(big)
	var tv := VBoxContainer.new()
	tv.add_child(_label(String(d["nom"]), 28, d["couleur"]))
	tv.add_child(_label(String(SpellDB.CATS.get(d.get("cat", "base"), "")), 18, Color(0.7, 0.68, 0.8)))
	head.add_child(tv)
	_detail.add_child(head)
	_detail.add_child(_label(String(d["desc"]), 20, Color(0.9, 0.9, 0.95), true))
	var rk := prog.rank(sel)
	var power := (float(d.get("degats", 0.0)) + prog.spell_power() * float(d["ratio"])) * (1.0 + 0.25 * (rk - 1))
	var lines := []
	lines.append("Mana : %d  (chargé à fond : %d)" % [int(pc.mana_cost(sel, 0.0) if not PlayerCombat.practice else d["mana"]), int(float(d["mana"]) * 1.6)])
	lines.append("Recharge : %.1f s" % (float(d["recharge"]) * (1.0 - 0.1 * (rk - 1))))
	if float(d["portee"]) > 0.0:
		lines.append("Portée : %d m" % int(d["portee"]))
	if d.has("rayon"):
		lines.append("Zone : %.1f m de rayon (plus large chargé)" % float(d["rayon"]))
	if float(d.get("duree", 0.0)) > 0.0:
		lines.append("Durée : %.1f s" % float(d["duree"]))
	if power > 0.0:
		lines.append("Puissance actuelle : %d (×2,2 chargé à fond)" % int(power))
	lines.append("Élément : %s" % String(d.get("element", "arcane")).capitalize())
	if SpellDB.is_power(sel):
		lines.append("Rang : %d / 3" % rk)
	_detail.add_child(_label("\n".join(lines), 19, Color(0.82, 0.86, 1.0), true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if not _owned(sel):
		if SpellDB.is_power(sel):
			var ok: bool = prog.level >= int(d["niveau"]) and prog.gold >= int(d["cout_or"])
			var b := _button("Débloquer (%d or, niveau %d)" % [d["cout_or"], d["niveau"]], ACCENT, ok)
			b.pressed.connect(_unlock)
			row.add_child(b)
		else:
			row.add_child(_label("S'apprend au niveau %d." % d["niveau"], 19, Color(1, 0.8, 0.5)))
	else:
		if SpellDB.is_power(sel) and rk < 3:
			var cost := 150 * rk
			var b2 := _button("Améliorer au rang %d (%d or)" % [rk + 1, cost], ACCENT, prog.gold >= cost)
			b2.pressed.connect(func(): _upgrade(cost))
			row.add_child(b2)
		row.add_child(_label("Touchez un emplacement 1-4 en haut pour l'équiper.", 18, Color(0.8, 0.95, 0.8), true))
	_detail.add_child(row)
	var demo := _button("Essayer dans la chambre (mannequins, mana gratuit)", Color(0.5, 0.85, 1.0), _owned(sel))
	demo.pressed.connect(_try)
	_detail.add_child(demo)

func _unlock() -> void:
	var d: Dictionary = SpellDB.DEFS[sel]
	var prog := Progression.get_inst()
	if prog.level < int(d["niveau"]) or prog.gold < int(d["cout_or"]):
		toast("Conditions non remplies")
		return
	prog.add_gold(-int(d["cout_or"]))
	prog.pouvoirs.append(sel)
	prog.mark()
	prog.save_if_dirty()
	toast("%s débloqué !" % d["nom"], true)
	GameState.get_inst().report("Pouvoir appris à la Chambre des Arcanes : %s." % d["nom"], "pouvoir")
	refresh()

func _upgrade(cost: int) -> void:
	var prog := Progression.get_inst()
	if prog.gold < cost:
		toast("Pas assez d'or")
		return
	prog.add_gold(-cost)
	prog.rangs[sel] = prog.rank(sel) + 1
	prog.mark()
	prog.save_if_dirty()
	toast("%s : rang %d" % [SpellDB.DEFS[sel]["nom"], prog.rank(sel)], true)
	refresh()

## Équipe le pouvoir sélectionné dans l'emplacement i (échange si déjà équipé ailleurs)
func _equip(i: int) -> void:
	if not _owned(sel):
		toast("Ce pouvoir n'est pas encore débloqué")
		return
	equip(sel, i)
	toast("%s → emplacement %d" % [SpellDB.DEFS[sel]["nom"], i + 1], true)
	refresh()

static func equip(id: String, i: int) -> void:
	var prog := Progression.get_inst()
	var j := prog.slots.find(id)
	if j >= 0:
		prog.slots[j] = prog.slots[i]
	prog.slots[i] = id
	prog.mark()
	prog.save_if_dirty()
	if Hud.inst:
		Hud.inst.refresh_slots()

func _try() -> void:
	close_ui()
	spawn_dummies()
	if Hud.inst:
		Hud.inst.show_message("Entraînement : mana gratuit dans la chambre", Color(0.7, 0.6, 1.0))

static func spawn_dummies() -> void:
	var w: Node3D = (Engine.get_main_loop() as SceneTree).current_scene
	for m in Combat.monsters.duplicate():
		if is_instance_valid(m) and m.kind == "mannequin":
			m.queue_free()
	for p in [Vector3(-15.0, 13.1, -141.5), Vector3(-12.0, 13.1, -140.5), Vector3(-18.0, 13.1, -140.5)]:
		var m := Monster.new()
		m.kind = "mannequin"
		m.no_respawn = true
		m.position = p
		w.add_child(m)
		m.rotation.y = 0.0

## Décor de la chambre : cercle runique lumineux, runes flottantes, enseigne
static func build_chamber(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ChambreArcanes"
	parent.add_child(root)
	root.global_position = CENTER + Vector3(0, 0.03, 0)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.0, 5.0)
	ring.mesh = q
	ring.material_override = FX.pmat("symbol_01", true, false, Color(0.6, 0.45, 1.0))
	ring.rotation = Vector3(-PI / 2.0, 0, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var tw := ring.create_tween()
	tw.set_loops()
	tw.tween_property(ring, "rotation:y", TAU, 20.0).from(0.0)
	var motes := FX.particles("star_06", 16, 3.0, [Color(0.7, 0.55, 1, 0), Color(0.8, 0.7, 1, 0.9), Color(0.6, 0.4, 1, 0)], 0.18, false)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 2.0
	motes.direction = Vector3.UP
	motes.initial_velocity_min = 0.2
	motes.initial_velocity_max = 0.5
	motes.gravity = Vector3.ZERO
	root.add_child(motes)
	motes.position.y = 1.0
	motes.emitting = true
	var lbl := Label3D.new()
	lbl.text = "Chambre des Arcanes"
	lbl.font_size = 64
	lbl.outline_size = 14
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.85, 0.75, 1.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.6, 0)
	root.add_child(lbl)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.45, 1.0)
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.shadow_enabled = false
	l.position.y = 1.5
	root.add_child(l)
	Castle.interior_lights.append(l)
