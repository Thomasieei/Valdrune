class_name ActionButton
extends Control
## Bouton d'action tactile rond, dessiné en vectoriel (net sur tous les écrans) :
## icône, recharge en camembert, verrou de niveau, compteur (potions), manque de mana.

signal pressed

var icon := "epee"
var radius := 50.0
var accent := Color(1, 0.85, 0.4)
var cooldown := 0.0          # 0..1 restant
var cd_text := ""
var locked_text := ""
var count := -1
var dim := false
var held := false
var pulse := false           # mise en avant (tutoriel)
var label := ""              # petite légende sous le bouton
var charge := 0.0            # charge du sort maintenu (0..1)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(ic: String, r: float, col: Color) -> ActionButton:
	icon = ic
	radius = r
	accent = col
	size = Vector2(r * 2, r * 2)
	return self

var _sig := ""

## Ne redessine que si l'état affiché a changé (économise le processeur du téléphone).
func refresh() -> void:
	var sig := "%d|%s|%s|%d|%s|%s|%s|%d" % [int(cooldown * 80.0), cd_text, locked_text, count, dim, held, label, int(charge * 30.0)]
	if pulse:
		sig += str(Time.get_ticks_msec() / 50)
	if sig != _sig:
		_sig = sig
		queue_redraw()

func hit(p: Vector2) -> bool:
	return visible and p.distance_to(global_position + size * 0.5) <= radius * 1.15

func _draw() -> void:
	var c := size * 0.5
	if pulse:
		var k := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		draw_arc(c, radius * (1.05 + k * 0.45), 0, TAU, 48, Color(1, 0.9, 0.45, 0.9 * (1.0 - k)), 5.0, true)
		draw_arc(c, radius + 3.0, 0, TAU, 48, Color(1, 0.9, 0.45, 0.8), 3.0, true)
	var bg := Color(0.06, 0.07, 0.10, 0.62 if not held else 0.8)
	draw_circle(c, radius, bg)
	var ring := accent if locked_text == "" else Color(0.5, 0.5, 0.5)
	if dim:
		ring = Color(0.45, 0.55, 0.85)
	if cooldown > 0.0 and locked_text == "":
		ring = Color(0.3, 0.3, 0.32)
	draw_arc(c, radius - 2.0, 0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.95), 3.0, true)
	if charge > 0.0:
		draw_arc(c, radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * charge, 40, Color(1, 0.95, 0.6, 0.95), 6.0, true)
	var ic := Color(1, 1, 1, 0.95) if locked_text == "" and not dim else Color(0.75, 0.75, 0.8, 0.55)
	_icon(c, radius * 0.52, ic)
	if cooldown > 0.0 and locked_text == "":
		# secteur sombre dessiné triangle par triangle : un seul polygone en éventail devient invalide
		# près de 100 % (le centre touche le bord) et n'était alors plus dessiné du tout
		var n := maxi(2, int(40 * cooldown))
		var prev := c + Vector2(0, -(radius - 3.0))
		for i in range(1, n + 1):
			var a := -PI / 2.0 + TAU * minf(cooldown, 0.999) * i / n
			var cur := c + Vector2(cos(a), sin(a)) * (radius - 3.0)
			draw_colored_polygon(PackedVector2Array([c, prev, cur]), Color(0, 0, 0, 0.55))
			prev = cur
		# anneau de progression : se remplit jusqu'au bout quand le sort est prêt
		draw_arc(c, radius - 2.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cooldown), 40, Color(accent.r, accent.g, accent.b, 0.95), 4.0, true)
		if cd_text != "":
			_text(c, cd_text, int(radius * 0.5), Color.WHITE)
	if locked_text != "":
		draw_circle(c, radius - 3.0, Color(0, 0, 0, 0.45))
		_text(c + Vector2(0, radius * 0.35), locked_text, int(radius * 0.32), Color(1, 0.85, 0.5))
	if label != "":
		_text(c + Vector2(0, radius + 16), label, 18, Color(1, 0.95, 0.85))
	if count >= 0:
		var bc := c + Vector2(radius * 0.68, radius * 0.68)
		draw_circle(bc, radius * 0.34, Color(0.12, 0.1, 0.08, 0.95))
		draw_arc(bc, radius * 0.34, 0, TAU, 20, accent, 2.0)
		_text(bc, str(count), int(radius * 0.38), Color.WHITE)

func _text(p: Vector2, t: String, fs: int, col: Color) -> void:
	var f := get_theme_default_font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, p + Vector2(-w * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
	draw_string(f, p + Vector2(-w * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _icon(c: Vector2, s: float, col: Color) -> void:
	match icon:
		"grimoire":
			# cercle runique : anneau, six gemmes, étoile intérieure
			draw_arc(c, s * 0.82, 0, TAU, 32, col, s * 0.1, true)
			for k in 6:
				var a := TAU * k / 6.0 - PI / 2.0
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.82, s * 0.16, col)
			for k in 3:
				var a1 := TAU * k / 3.0 - PI / 2.0
				var a2 := a1 + PI
				draw_line(c + Vector2(cos(a1), sin(a1)) * s * 0.5, c + Vector2(cos(a1 + TAU / 3.0), sin(a1 + TAU / 3.0)) * s * 0.5, col, s * 0.08, true)
				draw_line(c + Vector2(cos(a2), sin(a2)) * s * 0.5, c + Vector2(cos(a2 + TAU / 3.0), sin(a2 + TAU / 3.0)) * s * 0.5, col, s * 0.08, true)
		"epee":
			draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.75, -0.75) * s, col, s * 0.2, true)
			draw_line(c + Vector2(-0.75, 0.25) * s, c + Vector2(-0.25, 0.75) * s, col, s * 0.16, true)
			draw_circle(c + Vector2(-0.82, 0.82) * s, s * 0.14, col)
		"esquive":
			draw_arc(c, s * 0.7, PI * 0.15, PI * 1.35, 20, col, s * 0.16, true)
			var tip := c + Vector2(cos(PI * 0.15), sin(PI * 0.15)) * s * 0.7
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0.35, -0.2) * s, tip + Vector2(-0.25, -0.35) * s, tip + Vector2(0.05, 0.35) * s]), col)
		"feu":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var r := s * (0.55 + 0.35 * maxf(0.0, -sin(a)))
				pts.append(c + Vector2(cos(a) * s * 0.55, sin(a) * r + s * 0.15))
			draw_colored_polygon(pts, Color(1.0, 0.55, 0.15, col.a))
			draw_circle(c + Vector2(0, s * 0.3), s * 0.25, Color(1, 0.9, 0.5, col.a))
		"bouclier":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7, -0.75) * s, c + Vector2(0.7, -0.75) * s, c + Vector2(0.62, 0.15) * s, c + Vector2(0, 0.85) * s, c + Vector2(-0.62, 0.15) * s]), Color(0.35, 0.8, 1.0, col.a))
			draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.6) * s, Color(1, 1, 1, col.a * 0.8), s * 0.1)
		"givre":
			for k in 3:
				var a := PI * k / 3.0
				var d := Vector2(cos(a), sin(a)) * s * 0.85
				draw_line(c - d, c + d, Color(0.75, 0.95, 1, col.a), s * 0.13, true)
				for sgn in [-1.0, 1.0]:
					var e: Vector2 = c + d * 0.55 * sgn
					var pv := Vector2(-d.y, d.x).normalized() * s * 0.22
					draw_line(e, e + d.normalized() * s * 0.2 * sgn + pv, Color(0.75, 0.95, 1, col.a), s * 0.08)
					draw_line(e, e + d.normalized() * s * 0.2 * sgn - pv, Color(0.75, 0.95, 1, col.a), s * 0.08)
		"racines":
			var g := Color(0.55, 0.85, 0.35, col.a)
			draw_line(c + Vector2(0, 0.85) * s, c + Vector2(0, -0.2) * s, g, s * 0.16, true)
			draw_line(c + Vector2(0, 0.2) * s, c + Vector2(-0.6, -0.55) * s, g, s * 0.12, true)
			draw_line(c + Vector2(0, -0.05) * s, c + Vector2(0.6, -0.7) * s, g, s * 0.12, true)
			draw_line(c + Vector2(0, -0.2) * s, c + Vector2(0.05, -0.85) * s, g, s * 0.1, true)
		"potion_soin", "potion_mana":
			var liquid := Color(0.95, 0.25, 0.25, col.a) if icon == "potion_soin" else Color(0.3, 0.55, 1.0, col.a)
			draw_circle(c + Vector2(0, 0.25) * s, s * 0.6, liquid)
			draw_rect(Rect2(c + Vector2(-0.2, -0.85) * s, Vector2(0.4, 0.6) * s), Color(0.85, 0.85, 0.9, col.a))
			draw_arc(c + Vector2(0, 0.25) * s, s * 0.6, 0, TAU, 24, Color(1, 1, 1, col.a * 0.7), 2.0)
		"parler":
			draw_circle(c + Vector2(-0.1, -0.1) * s, s * 0.62, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, 0.3) * s, c + Vector2(-0.1, 0.4) * s, c + Vector2(-0.7, 0.85) * s]), col)
			for k in 3:
				draw_circle(c + Vector2(-0.38 + k * 0.28, -0.1) * s, s * 0.08, Color(0.1, 0.1, 0.12))
		"couronne":
			var g := Color(1, 0.82, 0.35, col.a)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.75, 0.5) * s, c + Vector2(-0.75, -0.35) * s, c + Vector2(-0.38, 0.05) * s, c + Vector2(0, -0.6) * s, c + Vector2(0.38, 0.05) * s, c + Vector2(0.75, -0.35) * s, c + Vector2(0.75, 0.5) * s]), g)
			draw_rect(Rect2(c + Vector2(-0.75, 0.55) * s, Vector2(1.5, 0.22) * s), g)
			draw_circle(c + Vector2(0, 0.25) * s, s * 0.12, Color(0.85, 0.2, 0.25, col.a))
		"annuler":
			draw_line(c + Vector2(-0.55, -0.55) * s, c + Vector2(0.55, 0.55) * s, Color(1, 0.5, 0.45, col.a), s * 0.22, true)
			draw_line(c + Vector2(0.55, -0.55) * s, c + Vector2(-0.55, 0.55) * s, Color(1, 0.5, 0.45, col.a), s * 0.22, true)
		_:
			_icon_power(c, s, col)

## Icônes des pouvoirs du souverain
func _icon_power(c: Vector2, s: float, col: Color) -> void:
	var k := Color(accent.r, accent.g, accent.b, col.a)
	var w := Color(1, 1, 1, col.a)
	match icon:
		"main":
			draw_rect(Rect2(c + Vector2(-0.45, -0.1) * s, Vector2(0.9, 0.8) * s), k)
			for f in 4:
				draw_rect(Rect2(c + Vector2(-0.45 + f * 0.235, -0.75) * s, Vector2(0.18, 0.65) * s), k)
			draw_rect(Rect2(c + Vector2(0.45, 0.05) * s, Vector2(0.3, 0.18) * s), k)
		"gravite":
			for r in [0.75, 0.5, 0.25]:
				draw_arc(c, s * r, 0, TAU, 24, k, s * 0.1)
			draw_line(c + Vector2(0, -0.95) * s, c + Vector2(0, -0.1) * s, w, s * 0.1)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, -0.25) * s, c + Vector2(0.2, -0.25) * s, c]), w)
		"arsenal":
			for f in 3:
				var x := (-0.5 + f * 0.5) * s
				draw_line(c + Vector2(x, 0.8 * s), c + Vector2(x, -0.6 * s), k, s * 0.14)
				draw_line(c + Vector2(x - 0.2 * s, 0.45 * s), c + Vector2(x + 0.2 * s, 0.45 * s), w, s * 0.1)
		"projection":
			draw_circle(c + Vector2(0, -0.45) * s, s * 0.25, k)
			draw_line(c + Vector2(0, -0.2) * s, c + Vector2(0, 0.45) * s, k, s * 0.14)
			draw_line(c + Vector2(-0.8, 0.8) * s, c + Vector2(0.8, 0.8) * s, w, s * 0.12)
			draw_arc(c + Vector2(0, 0.6) * s, s * 0.6, PI, TAU, 12, w, s * 0.06)
		"vortex":
			for i in 3:
				draw_arc(c, s * (0.3 + i * 0.22), i * 1.4, i * 1.4 + PI * 1.3, 16, k, s * 0.1)
			draw_circle(c, s * 0.18, Color(0.05, 0, 0.1, col.a))
		"dome":
			draw_arc(c + Vector2(0, 0.4) * s, s * 0.8, PI, TAU, 20, k, s * 0.14)
			draw_line(c + Vector2(-0.9, 0.4) * s, c + Vector2(0.9, 0.4) * s, k, s * 0.12)
			draw_circle(c + Vector2(0, 0.1) * s, s * 0.15, w)
		"mur":
			for row in 3:
				for b in 3:
					var off := 0.0 if row % 2 == 0 else 0.25
					draw_rect(Rect2(c + Vector2(-0.8 + off + b * 0.5, 0.3 - row * 0.4) * s, Vector2(0.42, 0.32) * s), k)
		"reflet":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.8) * s, c + Vector2(0.65, 0) * s, c + Vector2(0, 0.8) * s, c + Vector2(-0.65, 0) * s]), k)
			draw_line(c + Vector2(-0.9, -0.6) * s, c + Vector2(-0.2, -0.1) * s, w, s * 0.08)
			draw_line(c + Vector2(0.2, 0.1) * s, c + Vector2(0.9, 0.6) * s, w, s * 0.08)
		"sablier":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.55, -0.8) * s, c + Vector2(0.55, -0.8) * s, c, ]), k)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(0.55, 0.8) * s, c + Vector2(-0.55, 0.8) * s]), k)
			draw_line(c + Vector2(-0.7, -0.85) * s, c + Vector2(0.7, -0.85) * s, w, s * 0.1)
			draw_line(c + Vector2(-0.7, 0.85) * s, c + Vector2(0.7, 0.85) * s, w, s * 0.1)
		"chaines":
			for i in 4:
				var p := c + Vector2(-0.6 + i * 0.4, -0.6 + i * 0.4) * s
				draw_arc(p, s * 0.22, 0, TAU, 12, k, s * 0.1)
		"meteore":
			draw_circle(c + Vector2(0.3, 0.3) * s, s * 0.35, k)
			for i in 3:
				draw_line(c + Vector2(0.1 - i * 0.15, 0.05 + i * 0.12) * s, c + Vector2(-0.7 - i * 0.1, -0.7 + i * 0.15) * s, Color(1, 0.8, 0.4, col.a), s * 0.08)
		"piliers":
			for i in 3:
				var h := 0.5 + i * 0.3 if i < 2 else 1.1
				draw_rect(Rect2(c + Vector2(-0.75 + i * 0.55, 0.8 - h) * s, Vector2(0.4, h) * s), k)
		"eclair":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.15, -0.9) * s, c + Vector2(-0.45, 0.1) * s, c + Vector2(-0.05, 0.1) * s, c + Vector2(-0.2, 0.9) * s, c + Vector2(0.45, -0.15) * s, c + Vector2(0.05, -0.15) * s]), k)
		"faille":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.9) * s, c + Vector2(0.25, 0) * s, c + Vector2(0, 0.9) * s, c + Vector2(-0.25, 0) * s]), k)
			draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.6) * s, w, s * 0.08)
		"legion":
			for i in 3:
				var x := (-0.55 + i * 0.55) * s
				draw_circle(c + Vector2(x, -0.35 * s), s * 0.17, k)
				draw_rect(Rect2(c + Vector2(x - 0.18 * s, -0.15 * s), Vector2(0.36, 0.75) * s), k)
		"oeil":
			draw_arc(c, s * 0.75, PI * 0.15, PI * 0.85, 16, k, s * 0.12)
			draw_arc(c, s * 0.75, PI * 1.15, PI * 1.85, 16, k, s * 0.12)
			draw_circle(c, s * 0.3, k)
			draw_circle(c, s * 0.12, Color(0.02, 0.05, 0.1, col.a))
		"transpo":
			draw_arc(c, s * 0.65, -0.3, PI - 0.3, 14, k, s * 0.12)
			draw_arc(c, s * 0.65, PI - 0.3, TAU - 0.3, 14, w, s * 0.12)
			draw_circle(c + Vector2(-0.65, 0) * s, s * 0.14, k)
			draw_circle(c + Vector2(0.65, 0) * s, s * 0.14, w)
		"incarnation":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.35, c + Vector2(cos(a), sin(a)) * s * 0.85, k, s * 0.1)
			draw_circle(c, s * 0.3, w)
