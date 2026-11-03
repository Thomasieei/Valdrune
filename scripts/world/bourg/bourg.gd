class_name Bourg
extends RefCounted
## Bâtisseur de maisons à colombages en pièces MegaKit.
## Repère local d'une maison : façade (porte) vers +z, largeur w modules en x, profondeur d modules en z.
## Une maison = soubassement de pierre + rez-de-chaussée (pierre ou enduit) + étages (enduit/colombages,
## encorbellement facultatif) + toit de tuiles (pignon sur rue ou gouttereau sur rue) + cheminée.

const M := 2.0
const FH := 3.0

var mk: MK              # rez-de-chaussée et tout ce qui reste visible
var mk_up: MK           # étages + toit des maisons visitables (masqués quand on entre)
var geo: Geo
var doors: Array = []        # [porte Vector2, direction Vector2]
var chimneys: Array = []
var lit_ratio := 0.2

## Teintes d'enduit (blanc cassé, ocre, rosé, sable, gris bleuté) et de tuiles
const PLASTER := [Color(0.96, 0.94, 0.9), Color(0.98, 0.86, 0.7), Color(0.96, 0.84, 0.8), Color(0.9, 0.88, 0.82), Color(0.82, 0.86, 0.9), Color(0.97, 0.92, 0.8), Color(0.88, 0.8, 0.7)]
const TILES := [Color(0.8, 0.62, 0.56), Color(0.68, 0.52, 0.47), Color(0.58, 0.47, 0.45), Color(0.76, 0.64, 0.56), Color(0.52, 0.5, 0.52), Color(0.7, 0.58, 0.5)]
## Bois de colombage : chêne sombre, noyer, chêne patiné (le bois brut du kit est trop orange)
const WOOD := [Color(0.56, 0.46, 0.42), Color(0.66, 0.54, 0.46), Color(0.48, 0.41, 0.4), Color(0.6, 0.52, 0.5)]
## Tuiles « grises » (texture désaturée teintée) : ardoise bleutée, brun vieilli, tuile moussue
const SLATE := [Color(0.5, 0.55, 0.64), Color(0.44, 0.47, 0.54), Color(0.58, 0.46, 0.36), Color(0.48, 0.5, 0.42), Color(0.62, 0.6, 0.6)]
const ROOF_SIZES := {4: [4, 6, 8], 6: [6, 8, 10, 12, 14], 8: [8, 10, 12, 14]}

## Toit possible pour ces dimensions ?
static func roof_ok(w: int, d: int, roof: String) -> bool:
	var rw := w * 2 if roof == "pignon" else d * 2
	var rl := d * 2 if roof == "pignon" else w * 2
	return ROOF_SIZES.has(rw) and rl >= (ROOF_SIZES[rw] as Array)[0] - 1 and rl <= (ROOF_SIZES[rw] as Array)[-1] + 1

## s : {pos, rot, w, d, floors, ground ("pierre"/"enduit"), roof ("pignon"/"long"), plaster, tiles, wood,
##      jetty, balcony, door (module de la porte), shop, seed, visit (maison visitable), quoins, y0}
## Renvoie {y0, top, base (Transform3D), door (Vector3 monde), face (Vector2)}
func build_house(s: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("seed", 1))
	var pos: Vector2 = s["pos"]
	var rot: float = s.get("rot", 0.0)
	var w: int = s.get("w", 3)
	var d: int = s.get("d", 4)
	var floors: int = s.get("floors", 2)
	var roof: String = s.get("roof", "pignon")
	var ground: String = s.get("ground", "pierre")
	var jetty: bool = s.get("jetty", floors > 1)
	var visit: bool = s.get("visit", false)
	var hw := w * M * 0.5
	var hd := d * M * 0.5
	var b := Basis(Vector3.UP, rot)
	# hauteur : on pose la maison sur le point le plus haut de son emprise, soubassement dessous
	var hmin := INF
	var hmax := -INF
	for c in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd), Vector2.ZERO]:
		var q: Vector3 = b * Vector3(c.x, 0, c.y)
		var h := Terrain.height_at(pos.x + q.x, pos.y + q.z)
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
	var y0: float = s.get("y0", hmax + 0.18)
	var base := Transform3D(b, Vector3(pos.x, y0, pos.y))
	var pl: Color = s.get("plaster", PLASTER[rng.randi() % PLASTER.size()])
	var tl: Color = s.get("tiles", TILES[rng.randi() % TILES.size()])
	var wd: Color = s.get("wood", WOOD[rng.randi() % WOOD.size()])
	var tint := {"MI_Plaster": pl, "MI_RoundTiles": tl, "MI_WoodTrim": wd, "MI_WoodTrim_Wear": wd * Color(0.92, 0.92, 0.92)}
	var up: MK = mk_up if (visit and mk_up) else mk
	var roof_remap := {}
	if s.get("slate", rng.randf() < 0.45):
		roof_remap = {"MI_RoundTiles": "MI_RoundTiles_Gray"}
		tint["MI_RoundTiles"] = s.get("tiles", SLATE[rng.randi() % SLATE.size()])
	# soubassement
	if geo:
		geo.obox("pierre_base", Transform3D(b, Vector3(pos.x, (hmin - 0.4 + y0) * 0.5 - 0.02, pos.y)), Vector3(w * M + 0.5, y0 - hmin + 0.4, d * M + 0.5), false)
	var door_k: int = s.get("door_k", (w - 1) / 2)
	var shop: bool = s.get("shop", false)
	var sides := [
		{"n": w, "t": Transform3D(Basis(), Vector3(0, 0, hd)), "front": true},
		{"n": w, "t": Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -hd)), "front": false},
		{"n": d, "t": Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-hw, 0, 0)), "front": false},
		{"n": d, "t": Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(hw, 0, 0)), "front": false},
	]
	var blind: Array = s.get("blind", [])   # côtés aveugles (mitoyens) : pas de fenêtres
	var walls_g := "Wall_UnevenBrick_" if ground == "pierre" else "Wall_Plaster_"
	var lit_r: float = s.get("lit", lit_ratio)
	var lit := func() -> Dictionary: return {"MI_WindowGlass": "glass_lit"} if rng.randf() < lit_r else {}
	var door_world := Vector3.ZERO
	var balcony: bool = s.get("balcony", false) and floors > 1
	for f in floors:
		var y := f * FH
		var out := 0.35 if (f > 0 and jetty) else 0.0
		var target: MK = mk if f == 0 else up
		for si in sides.size():
			var sd: Dictionary = sides[si]
			var n: int = sd["n"]
			var st: Transform3D = sd["t"]
			var push := out if si < 2 else 0.0
			var widen := out if si >= 2 else 0.0
			var is_blind: bool = blind.has(si)
			for k in n:
				var x := -n * M * 0.5 + M * (k + 0.5)
				var lt := st * Transform3D(Basis(), Vector3(x, y, push))
				if si >= 2 and widen > 0.0:
					var sc := 1.0 + widen / (n * M * 0.5)
					lt = st * Transform3D(Basis().scaled(Vector3(sc, 1, 1)), Vector3(x * sc, y, push))
				var piece := ""
				var insert := ""
				var shutters := ""
				if f == 0:
					if sd["front"] and k == door_k:
						piece = walls_g + "Door_Round"
						insert = "door"
					elif shop and sd["front"]:
						piece = walls_g + "Window_Wide_Flat"
						insert = "Window_Wide_Flat1"
					elif is_blind:
						piece = walls_g + "Straight"
					elif ((k + si) % 2 == 0 or n <= 2) and not (si == 1 and k % 2 == 1):
						piece = walls_g + ("Window_Thin_Round" if rng.randf() < 0.5 else "Window_Wide_Round")
						insert = "Window_Thin_Round1" if piece.ends_with("Thin_Round") else "Window_Wide_Round1"
						if not sd["front"]:
							insert = "Window_Thin_Flat1" if piece.ends_with("Thin_Round") else "Window_Wide_Flat1"
						if rng.randf() < 0.55:
							shutters = "WindowShutters_" + ("Thin" if piece.contains("Thin") else "Wide") + "_Round_" + ("Open" if rng.randf() < 0.7 else "Closed")
					else:
						piece = walls_g + "Straight"
				else:
					var r := rng.randf()
					var want_win: bool = (k + f + si) % 2 == 0 or (sd["front"] and n <= 3)
					if si == 1 and k % 2 == 1:
						want_win = false   # arrière : moins percé
					if is_blind:
						want_win = false
					if balcony and f == 1 and sd["front"] and k == door_k:
						piece = "Wall_Plaster_Door_Flat"
						insert = "Door_1_Flat"
					elif want_win:
						var wide := r < 0.6
						var round_w: bool = sd["front"] and not wide and rng.randf() < 0.5
						piece = "Wall_Plaster_Window_" + ("Wide_Flat" if wide else "Thin_Round")
						insert = "Window_Wide_Flat1" if wide else ("Window_Thin_Round1" if round_w else "Window_Thin_Flat1")
						if rng.randf() < 0.6:
							shutters = "WindowShutters_" + ("Wide_Flat_" if wide else "Thin_Round_") + ("Open" if rng.randf() < 0.65 else "Closed")
					elif r < 0.55 and sd["front"]:
						piece = "Wall_Plaster_WoodGrid"
					else:
						piece = "Wall_Plaster_Straight"
				target.add(piece, base * lt, tint)
				if insert == "door":
					var dk: String = s.get("door_piece", ["Door_4_Round", "Door_8_Round", "Door_1_Round"][rng.randi() % 3])
					if visit:
						# porte ouverte, rabattue contre le mur intérieur
						target.add(dk, base * lt * Transform3D(Basis(Vector3.UP, -PI / 2.0 + 0.15), Vector3(-0.53, 0, -0.1)), tint)
					else:
						target.add(dk, base * lt * Transform3D(Basis(), Vector3(-0.53, 0, 0.02)), tint)
					var dw: Transform3D = base * lt
					door_world = dw.origin
					doors.append([Vector2(dw.origin.x, dw.origin.z), Vector2(dw.basis.z.x, dw.basis.z.z).normalized()])
				elif insert == "Door_1_Flat":
					target.add(insert, base * lt * Transform3D(Basis(), Vector3(-0.53, 0, 0.02)), tint)
				elif insert != "":
					target.add(insert, base * lt, tint, lit.call())
				if shutters != "":
					target.add(shutters, base * lt, tint)
			# poteaux d'angle
			if si == 0:
				var cz := hd + out
				for cs in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					var cp := Vector3(cs.x * hw, y, cs.y * cz)
					var ca := atan2(cs.x, cs.y) - PI / 4.0
					var brick: bool = f == 0 and ground == "pierre" and cs.y > 0 and bool(s.get("quoins", false))
					target.add("Corner_Exterior_Brick" if brick else "Corner_Exterior_Wood", base * Transform3D(Basis(Vector3.UP, ca), cp), tint)
		# poutres de rive et corbeaux sous l'encorbellement
		if f > 0 and jetty:
			for si in 2:
				var sd: Dictionary = sides[si]
				for k in w:
					if si == 1 and k % 2 == 1:
						continue
					var x := -w * M * 0.5 + M * (k + 0.5)
					var lt: Transform3D = sd["t"] * Transform3D(Basis(), Vector3(x, y, out))
					target.add("Wall_BottomCover", base * lt, tint)
					target.add("Roof_Support2", base * (sd["t"] * Transform3D(Basis(), Vector3(x - M * 0.5 + (0.12 if k == 0 else 0.0), y, 0.0))), tint)
	# balcon de bois sur la façade, au premier étage (plancher, garde-corps à croisillons, jambes de force)
	if balcony:
		var by := FH
		var bz := hd + 0.35 + 1.0
		var k0 := maxi(0, door_k - 1)
		var k1 := mini(w - 1, door_k + 1)
		for k in range(k0, k1 + 1):
			var x := -w * M * 0.5 + M * (k + 0.5)
			up.add("Floor_WoodDark", base * Transform3D(Basis(), Vector3(x, by + 0.03, bz)), tint)
			up.add("Balcony_Cross_Straight", base * Transform3D(Basis(), Vector3(x, by, bz)), tint)
			up.add("Prop_Support", base * Transform3D(Basis(), Vector3(x - 0.8, by - 3.0, hd)), tint)
			up.add("Prop_Support", base * Transform3D(Basis(), Vector3(x + 0.8, by - 3.0, hd)), tint)
		var xl := -w * M * 0.5 + M * k0
		var xr := -w * M * 0.5 + M * (k1 + 1)
		up.add("Balcony_Cross_Straight", base * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(xl + 1.0, by, bz)), tint)
		up.add("Balcony_Cross_Straight", base * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(xr - 1.0, by, bz)), tint)
	# toit
	var top := floors * FH
	var out_r := 0.35 if (jetty and floors > 1) else 0.0
	var roof_w: int
	var roof_l: int
	var ridge_rot := 0.0
	if roof == "pignon":
		roof_w = w * 2
		roof_l = d * 2
	else:
		roof_w = d * 2
		roof_l = w * 2
		ridge_rot = PI / 2.0
	var rw: int = clampi(roof_w, 4, 8)
	if rw % 2 == 1:
		rw += 1
	var lens: Array = ROOF_SIZES[rw]
	var rl: int = lens[0]
	for L in lens:
		if absi(L - roof_l) < absi(rl - roof_l):
			rl = L
	var rname := "Roof_RoundTiles_%dx%d" % [rw, rl]
	var sx := float(roof_w) / rw
	var sz := float(roof_l + (out_r * 2.0 if roof == "pignon" else 0.0)) / rl
	if roof != "pignon":
		sx = float(roof_w + out_r * 2.0) / rw
		sz = float(roof_l) / rl
	var rb := Basis(Vector3.UP, ridge_rot) * Basis().scaled(Vector3(sx, 1.0, sz))
	up.add(rname, base * Transform3D(rb, Vector3(0, top, 0)), tint, roof_remap)
	# pignons
	var gname := "Roof_Front_Brick%d" % rw
	var gl := roof_l * 0.5 + (out_r if roof == "pignon" else 0.0)
	for sgn in [1.0, -1.0]:
		var ga := ridge_rot + (0.0 if sgn > 0 else PI)
		var gp: Vector3 = Basis(Vector3.UP, ridge_rot) * Vector3(0, top, sgn * gl)
		up.add(gname, base * Transform3D(Basis(Vector3.UP, ga).scaled(Vector3(sx, 1, 1)), gp), tint)
	# cheminée
	if s.get("chimney", true):
		var ch := Vector3(hw * 0.45, top, -hd * 0.3) if roof == "pignon" else Vector3(-hw * 0.5, top, -hd * 0.25)
		up.add("Prop_Chimney", base * Transform3D(Basis(), ch + Vector3(0, 1.9, 0)), tint)
		chimneys.append(base * (ch + Vector3(0, 5.1, 0)))
	# collisions
	if visit:
		# murs seuls (on entre) : la porte reste libre
		var t := 0.3
		mk.col_box(Transform3D(b, base * Vector3(0, FH * 0.5, -hd + t * 0.5)), Vector3(w * M, FH, t))
		mk.col_box(Transform3D(b, base * Vector3(-hw + t * 0.5, FH * 0.5, 0)), Vector3(t, FH, d * M))
		mk.col_box(Transform3D(b, base * Vector3(hw - t * 0.5, FH * 0.5, 0)), Vector3(t, FH, d * M))
		var dx0 := -hw + M * door_k + 0.25
		var dx1 := -hw + M * (door_k + 1) - 0.25
		if dx0 > -hw:
			mk.col_box(Transform3D(b, base * Vector3((-hw + dx0) * 0.5, FH * 0.5, hd - t * 0.5)), Vector3(dx0 + hw, FH, t))
		if dx1 < hw:
			mk.col_box(Transform3D(b, base * Vector3((hw + dx1) * 0.5, FH * 0.5, hd - t * 0.5)), Vector3(hw - dx1, FH, t))
		# plancher
		for i in w:
			for j in d:
				mk.add("Floor_WoodDark", base * Transform3D(Basis(), Vector3(-hw + M * (i + 0.5), 0.02, -hd + M * (j + 0.5))), tint)
		mk.col_box(Transform3D(b, base * Vector3(0, -0.15, 0)), Vector3(w * M, 0.3, d * M))
	else:
		mk.col_box(Transform3D(b, Vector3(pos.x, y0 + FH * 0.5, pos.y)), Vector3(w * M, FH, d * M))
	return {"y0": y0, "top": y0 + top, "base": base, "door": door_world, "face": Vector2(b.z.x, b.z.z), "hmin": hmin, "tint": tint}
