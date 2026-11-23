class_name Foule
extends Node3D

# Habitants : des passants qui marchent dans les rues (chemins A*), des groupes qui discutent,
# des disputes et des vols. Un petit nombre autour du joueur, recyclés en permanence : la ville vit partout, à coût constant.
const N_MARCHE := 10
const COULEURS := [Color(0.7, 0.3, 0.3), Color(0.3, 0.45, 0.7), Color(0.85, 0.75, 0.35), Color(0.35, 0.6, 0.4), Color(0.55, 0.35, 0.65), Color(0.8, 0.5, 0.25), Color(0.25, 0.25, 0.3), Color(0.9, 0.9, 0.9)]
const CHEVEUX := [Color(0.1, 0.08, 0.08), Color(0.45, 0.28, 0.15), Color(0.8, 0.65, 0.3), Color(0.55, 0.15, 0.1), Color(0.7, 0.7, 0.75)]
const REP_DISPUTE := ["Tu m'as bousculé !", "Rends-moi mon argent !", "Casse-toi de là !", "Répète un peu pour voir !", "J'étais là avant !"]
const REP_VOL := ["Donne ton portefeuille !", "Vide tes poches !", "Pas un geste !", "Au secours !", "Laissez-moi tranquille !"]
const REP_DISCUTE := ["Tu as vu le raid ?", "Les chasseurs montent la garde.", "Le loyer augmente encore...", "J'ai entendu un cri dans le donjon.", "Quel froid aujourd'hui !"]

var ville: Node3D
var carte: Carte
var pts: Array = []
var _marche: Array = []
var _scenes: Array = []
var _pret := false
var _t_print := 4.0

func installer(v: Node3D, p: Array, c: Carte) -> void:
	ville = v
	pts = p
	carte = c

static func _civil(femme: bool) -> Node3D:
	var base: Node3D = load(Apparence.P + ("Female_Peasant.gltf" if femme else "Male_Peasant.gltf")).instantiate()
	var sq: Skeleton3D = base.find_child("Skeleton3D", true, false)
	Apparence._visage(sq, femme)
	var hc: Color = CHEVEUX.pick_random()
	if femme:
		Apparence._cheveux(sq, ["Hair_Buns"], hc, "T_Hair_2_BaseColor.png")
	else:
		Apparence._cheveux(sq, ["Hair_Buzzed"], hc)
	Apparence._teinter(sq, "Female_Peasant" if femme else "Male_Peasant", COULEURS.pick_random())
	var n := Modele.preparer(base, "civil_f" if femme else "civil_m", randf_range(1.62, 1.84))
	return n

func _agent() -> Dictionary:
	var n := _civil(randf() < 0.5)
	add_child(n)
	n.visible = false
	var ap := Modele.lecteur(n)
	if ap:
		Modele.jouer(ap, "Idle", randf_range(0.9, 1.1))
		ap.seek(randf() * 1.5, true)
	return {"n": n, "ap": ap}

func _anim(a: Dictionary, nom: String, vit := 1.0) -> void:
	var ap: AnimationPlayer = a["ap"]
	if ap and ap.current_animation != nom:
		Modele.jouer(ap, nom, vit, 0.15)

func _chemin(p: Vector3, q: Vector3) -> PackedVector2Array:
	var res := PackedVector2Array()
	var ids: Array = carte._astar.get_id_path(carte._libre(carte._cell(Vector2(p.x, p.z))), carte._libre(carte._cell(Vector2(q.x, q.z))))
	if ids.size() < 3:
		return res
	for id: Vector2i in ids:
		res.append(Vector2(Carte.X0 + (id.x + 0.5) * Carte.CELL + randf_range(-1.2, 1.2), Carte.Z0 + (id.y + 0.5) * Carte.CELL + randf_range(-1.2, 1.2)))
	return res

func _point_proche(pj: Vector3, dmin: float, dmax: float) -> Vector3:
	for essai in 14:
		var p: Vector3 = pts.pick_random()
		var d := p.distance_to(pj)
		if d >= dmin and d <= dmax:
			return p
	return Vector3.INF

func _placer_marcheur(w: Dictionary, pj: Vector3) -> void:
	var n: Node3D = w["a"]["n"]
	var p := _point_proche(pj, 26.0, 62.0)
	if p == Vector3.INF:
		n.visible = false
		w["pause"] = 1.0
		return
	for essai in 6:
		var q: Vector3 = pts.pick_random()
		var d := p.distance_to(q)
		if d < 35.0 or d > 140.0:
			continue
		var ch := _chemin(p, q)
		if ch.size() < 3:
			continue
		w["chemin"] = ch
		w["i"] = 1
		w["vit"] = randf_range(1.3, 1.9)
		w["pause"] = 0.0
		n.global_position = p
		n.rotation.y = randf() * TAU
		n.visible = true
		return
	n.visible = false
	w["pause"] = 1.0

func _maj_marcheur(w: Dictionary, dt: float, pj: Vector3) -> void:
	var a: Dictionary = w["a"]
	var n: Node3D = a["n"]
	if not n.visible:
		w["pause"] = float(w["pause"]) - dt
		if float(w["pause"]) <= 0.0:
			_placer_marcheur(w, pj)
		return
	var d2 := n.global_position.distance_squared_to(pj)
	var ap: AnimationPlayer = a["ap"]
	if ap:
		ap.active = d2 < 2025.0
	var ch: PackedVector2Array = w["chemin"]
	if d2 > 6400.0 or int(w["i"]) >= ch.size():
		_placer_marcheur(w, pj)
		return
	if float(w["pause"]) > 0.0:
		w["pause"] = float(w["pause"]) - dt
		_anim(a, "Talk" if w.get("parle", false) else "Idle")
		return
	var cible := ch[int(w["i"])]
	var dir := cible - Vector2(n.global_position.x, n.global_position.z)
	if dir.length() < 0.7:
		w["i"] = int(w["i"]) + 1
		if randf() < 0.07:
			w["pause"] = randf_range(2.0, 5.0)
			w["parle"] = randf() < 0.5
		return
	var vit: float = w["vit"]
	var pas := dir.normalized() * vit * dt
	n.global_position.x += pas.x
	n.global_position.z += pas.y
	n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
	w["yt"] = float(w.get("yt", 0.0)) - dt
	if float(w["yt"]) <= 0.0:
		w["yt"] = 0.25
		w["y"] = ville._sol(n.global_position.x, n.global_position.z)
	n.global_position.y = lerpf(n.global_position.y, float(w.get("y", n.global_position.y)), minf(1.0, dt * 8.0))
	_anim(a, "Walk", vit / 1.5)

# ---------- Scènes : discussion, dispute, vol ----------
func _creer_scene(type: String) -> Dictionary:
	var nb := 3 if type == "discute" and randf() < 0.4 else (3 if type == "vol" else 2)
	var agents := []
	for k in nb:
		agents.append(_agent())
	return {"type": type, "agents": agents, "t": 0.0, "vie": 0.0, "centre": Vector3.INF, "dit": 0.0}

func _placer_scene(s: Dictionary, pj: Vector3) -> void:
	var p := _point_proche(pj, 24.0, 58.0)
	if p == Vector3.INF:
		for a in s["agents"]:
			a["n"].visible = false
		return
	s["centre"] = p
	s["vie"] = randf_range(70.0, 140.0)
	var ags: Array = s["agents"]
	var base := randf() * TAU
	for k in ags.size():
		var n: Node3D = ags[k]["n"]
		var ang := base + TAU * k / ags.size()
		var r := 0.0 if (s["type"] == "vol" and k == 0) else 1.0
		n.global_position = p + Vector3(cos(ang) * r, 0, sin(ang) * r)
		n.visible = true
	for k in ags.size():
		var n: Node3D = ags[k]["n"]
		var cible: Vector3 = ags[0]["n"].global_position if (s["type"] != "discute" and k > 0) else p
		var dd := cible - n.global_position
		if k == 0 and s["type"] == "vol":
			n.rotation.y = randf() * TAU
		elif dd.length() > 0.1:
			n.rotation.y = atan2(dd.x, dd.z)
		else:
			n.rotation.y = randf() * TAU

func _maj_scene(s: Dictionary, dt: float, pj: Vector3) -> void:
	var ags: Array = s["agents"]
	if s["centre"] == Vector3.INF:
		s["t"] = float(s["t"]) - dt
		if float(s["t"]) <= 0.0:
			s["t"] = 1.5
			_placer_scene(s, pj)
		return
	var c: Vector3 = s["centre"]
	s["vie"] = float(s["vie"]) - dt
	var d2 := Vector2(c.x - pj.x, c.z - pj.z).length_squared()
	if d2 > 6400.0 or float(s["vie"]) <= 0.0:
		s["centre"] = Vector3.INF
		s["t"] = 0.5
		for a in ags:
			a["n"].visible = false
		return
	for a in ags:
		var ap: AnimationPlayer = a["ap"]
		if ap:
			ap.active = d2 < 2025.0
	if d2 > 2025.0:
		return
	s["t"] = float(s["t"]) + dt
	var cyc := fmod(float(s["t"]), 4.0)
	match s["type"]:
		"discute":
			for k in ags.size():
				_anim(ags[k], "Talk" if (int(float(s["t"]) / 3.0) % ags.size()) == k else "Idle")
		"dispute":
			_anim(ags[0], "Attack" if cyc > 2.6 else "Talk", 1.0)
			_anim(ags[1], "Hit" if (cyc > 2.8 and cyc < 3.4) else ("Block" if cyc > 3.4 else "Talk"))
		"vol":
			for k in range(1, ags.size()):
				_anim(ags[k], "Attack" if fmod(float(s["t"]) + k * 1.3, 4.0) > 2.8 else "SwordIdle")
			_anim(ags[0], "Hit" if cyc > 2.8 else "Block")
	# répliques quand le joueur passe près
	if d2 < 196.0:
		s["dit"] = float(s["dit"]) - dt
		if float(s["dit"]) <= 0.0:
			s["dit"] = randf_range(4.0, 7.0)
			var l: Array = REP_DISPUTE if s["type"] == "dispute" else (REP_VOL if s["type"] == "vol" else REP_DISCUTE)
			var qui: Node3D = ags[randi() % ags.size()]["n"]
			Fx.texte(qui.global_position + Vector3(0, 2.2, 0), l.pick_random(), Color(1.0, 0.85, 0.6) if s["type"] != "discute" else Color(0.85, 0.95, 1.0), 1.0, 2.2)

func _process(dt: float) -> void:
	if ville == null or ville.joueur == null or carte == null or pts.size() < 10:
		return
	var dehors: bool = ville.donjon == null and ville.chateau == null and ville.abime == null and not ville.chez_soi and ville.arene == null
	visible = dehors
	if not dehors:
		return
	var pj: Vector3 = ville.joueur.global_position
	if not _pret:
		_pret = true
		for k in N_MARCHE:
			_marche.append({"a": _agent(), "chemin": PackedVector2Array(), "i": 0, "vit": 1.5, "pause": randf() * 0.5})
		for t in ["discute", "discute", "discute", "dispute", "vol"]:
			_scenes.append(_creer_scene(t))
	for w in _marche:
		_maj_marcheur(w, dt, pj)
	for s in _scenes:
		_maj_scene(s, dt, pj)
	_t_print -= dt
	if _t_print <= 0.0:
		_t_print = 1000000.0
		var nb := 0
		for w in _marche:
			if w["a"]["n"].visible:
				nb += 1
		var ns := 0
		for s in _scenes:
			if s["centre"] != Vector3.INF:
				ns += 1
		print("[FOULE] marcheurs=", nb, "/", N_MARCHE, " scenes=", ns, "/", _scenes.size())
