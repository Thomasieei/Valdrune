class_name Camps
## Vrais campements ennemis autour des repaires (façon Diablo) : palissade, tentes ou huttes, feu de camp
## crépitant, butin, crânes, bannière ; le nom du camp s'affiche à l'approche et ses occupants parlent.

const STYLES := {
	"bandit": {"nom": "Camp de bandits", "tente": "tissu_rouge", "pieu": "bois_sombre", "col": Color(1.0, 0.55, 0.25)},
	"lanceur": {"nom": "Campement de brigands", "tente": "tissu_blanc", "pieu": "bois_sombre", "col": Color(1.0, 0.6, 0.3)},
	"mercenaire": {"nom": "Avant-poste de Vargas", "tente": "bleu_royal", "pieu": "bois", "col": Color(1.0, 0.6, 0.3)},
	"puglin": {"nom": "Village puglin", "tente": "chaume", "pieu": "bois", "col": Color(1.0, 0.5, 0.2)},
	"zombie": {"nom": "Charnier", "tente": "", "pieu": "bois_sombre", "col": Color(0.4, 1.0, 0.55)},
	"imp": {"nom": "Cercle infernal", "tente": "", "pieu": "pierre_base", "col": Color(1.0, 0.25, 0.15)},
}
const BARKS := {
	"bandit": ["Qui va là ?", "Ta bourse ou ta vie !", "Encore un chevalier qui se croit malin…", "Les gars, on a de la visite !", "Le chef va être content."],
	"lanceur": ["Visez la tête !", "Pas un pas de plus !", "Il est seul, allez-y !"],
	"mercenaire": ["Vargas paie double pour ta tête.", "Rien de personnel, seigneur.", "Formez les rangs !"],
	"puglin": ["Grrah ! Humain !", "Brillant ! Brillant ! Donne !", "Krak veut ta soupe !", "Fuyez, c'est le grand chef humain !"],
	"zombie": ["Grhhh…", "Faaaim…", "…chair…", "Rejoins-nous…"],
	"imp": ["Hi hi hi ! Brûle !", "Le portail a faim !", "Chair fraîche !"],
	"chef_bandit": ["Personne ne vole dans MON camp !", "Montrez-lui qui commande ici !"],
}

static func build(world: Node3D) -> void:
	var g := Geo.new()
	var root := Node3D.new()
	root.name = "CampsDecor"
	world.add_child(root)
	for z in Spawner.ZONES:
		var id: String = z["id"]
		if Spawner.group_of(id) != id or id in ["deserteur", "portail_brute"] or id.begins_with("foret_"):
			continue
		var kind: String = z["kind"]
		var st: Dictionary = STYLES.get(kind, STYLES["bandit"])
		_camp(g, root, z["pos"], float(z["r"]), kind, st, absi(id.hash()))
		_sign(root, z["pos"], st["nom"] if not String(z["label"]).contains("(") else String(z["label"]))
	g.commit(world, "Camps")
	Batcher.merge(root)

static func _camp(g: Geo, root: Node3D, c: Vector2, r: float, kind: String, st: Dictionary, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var y := Terrain.height_at(c.x, c.y)
	var face := atan2(Layout.TOWN.x - c.x, Layout.TOWN.y - c.y)   # l'entrée regarde vers le bourg
	var R := r + 4.0
	for z in Spawner.ZONES:
		if z["pos"] == c and BanditVillage.is_village(z["id"]):
			R = BanditVillage.VR
	# palissade de pieux taillés (ou cercle de pierres levées pour les diablotins)
	var n := int(TAU * R / 0.85)
	for i in n:
		var a := TAU * i / n
		var da := wrapf(a - (PI / 2.0 - face), -PI, PI)
		if absf(da) < 0.32:
			continue   # entrée
		if kind == "zombie" and i % 3 != 0:
			continue
		if kind == "imp" and i % 5 != 0:
			continue
		var q := Vector2(c.x + cos(a) * R, c.y + sin(a) * R)
		var h := Terrain.height_at(q.x, q.y)
		if h < Layout.WATER + 0.3:
			continue
		var tall := rng.randf_range(1.9, 2.6) if kind != "imp" else 3.2
		var w := 0.28 if kind != "imp" else 0.9
		g.obox(st["pieu"], Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), Vector3(q.x, h + tall * 0.5 - 0.2, q.y)), Vector3(w, tall, w), kind == "imp")
		if kind != "imp":
			g.obox(st["pieu"], Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, PI / 4.0), Vector3(q.x, h + tall - 0.1, q.y)), Vector3(0.2, 0.2, 0.2), false)
	# torches à l'entrée
	for s in [-1.0, 1.0]:
		var ea: float = PI / 2.0 - face + s * 0.38
		var tq := Vector2(c.x + cos(ea) * R, c.y + sin(ea) * R)
		Kit.dungeon(root, "Torch", Vector3(tq.x, Terrain.height_at(tq.x, tq.y), tq.y), 0.0, 1.6)
	# abris : tentes, huttes de chaume, ou tombes/pierres runiques
	var huts := 3 if r > 9.0 else 2
	for k in huts:
		var a: float = face + PI + (k - (huts - 1) * 0.5) * 1.1
		var q := Vector2(c.x + sin(a) * r * 0.75, c.y + cos(a) * r * 0.75)
		var h := Terrain.height_at(q.x, q.y)
		var rot := atan2(c.x - q.x, c.y - q.y)
		match kind:
			"zombie":
				for t in 4:
					var o := Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
					g.box("pierre_base", Vector3(q.x + o.x, h + 0.5, q.y + o.y), Vector3(0.7, 1.0 + rng.randf() * 0.5, 0.2), rot + rng.randf_range(-0.3, 0.3), true)
					g.box("terre", Vector3(q.x + o.x, h + 0.1, q.y + o.y + 0.9), Vector3(0.9, 0.25, 1.8), rot, false)
			"imp":
				g.box("pierre_base", Vector3(q.x, h + 1.4, q.y), Vector3(1.0, 2.8, 1.0), rot, true)
				g.box("rune", Vector3(q.x, h + 1.8, q.y) + Vector3(sin(rot), 0, cos(rot)) * 0.52, Vector3(0.5, 1.2, 0.04), rot, false)
			_:
				var hx := rng.randf_range(2.3, 2.9)
				g.hip_roof(st["tente"], Vector3(q.x, h, q.y), hx, hx * 1.25, 3.2 if kind != "puglin" else 3.6, rot)
				g.box("bois_sombre", Vector3(q.x, h + 1.3, q.y), Vector3(0.12, 2.6, 0.12), 0.0, true)
	# feu de camp au centre
	for i in 7:
		var a := TAU * i / 7.0
		g.box("pierre_base", Vector3(c.x + cos(a) * 0.9, y + 0.15, c.y + sin(a) * 0.9), Vector3(0.45, 0.3, 0.35), a, false)
	Kit.dungeon(root, "Firewood", Vector3(c.x, y, c.y), 0.0, 1.3)
	var fire := FX.particles("flame_01", 18, 0.8, [Color(1, 0.9, 0.5, 0.0), st["col"], Color(0.4, 0.1, 0.05, 0)], 0.9, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.8
	fire.initial_velocity_max = 1.6
	fire.gravity = Vector3(0, 0.5, 0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.35
	fire.visibility_range_end = 70.0
	root.add_child(fire)
	fire.position = Vector3(c.x, y + 0.35, c.y)
	fire.emitting = true
	var l := OmniLight3D.new()
	l.light_color = st["col"]
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 10.0
	l.set_script(load("res://scripts/world/flicker.gd"))
	root.add_child(l)
	l.position = Vector3(c.x, y + 1.3, c.y)
	# butin et ambiance
	var props := ["Barrel_Closed", "Chest", "WeaponRack_Small", "Skull", "Bone", "Bone", "Barrel_Open", "Spear", "Bag"]
	if kind == "zombie":
		props = ["Skull", "Skull", "Bone", "Bone", "Bone", "Cauldron_Empty", "Chest"]
	if kind == "imp":
		props = ["Skull", "Cauldron_Full", "Skull", "Bone", "CrystalBall_Stand"]
	for k in props.size():
		var a := face + PI * 0.5 + k * 0.7 + rng.randf() * 0.3
		var d := rng.randf_range(2.0, r * 0.6)
		var q := Vector2(c.x + sin(a) * d, c.y + cos(a) * d)
		Kit.dungeon(root, props[k], Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), rng.randf() * TAU, 1.3 if props[k] in ["Skull", "Bone"] else 1.1)
	# bannière du camp
	var bq := c + Vector2(sin(face), cos(face)) * (r * 0.4)
	g.box("bois_sombre", Vector3(bq.x, Terrain.height_at(bq.x, bq.y) + 2.0, bq.y), Vector3(0.15, 4.0, 0.15), 0.0, true)
	Kit.dungeon(root, "Banner", Vector3(bq.x, Terrain.height_at(bq.x, bq.y) + 2.2, bq.y), face, 1.2)

static func _sign(root: Node3D, c: Vector2, nom: String) -> void:
	var l := Label3D.new()
	l.text = nom
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72
	l.outline_size = 14
	l.pixel_size = 0.012
	l.modulate = Color(1.0, 0.55, 0.45)
	l.visibility_range_begin = 6.0
	l.visibility_range_end = 45.0
	root.add_child(l)
	l.position = Vector3(c.x, Terrain.height_at(c.x, c.y) + 6.5, c.y)

## Paroles des occupants (appelé par le repaire)
static func bark(kind: String, m: Node3D) -> void:
	var lines: Array = BARKS.get(kind, [])
	if lines.size() > 0 and is_instance_valid(m):
		FX.bark(m, lines[randi() % lines.size()], 2.4 * float(m.def["scale"]), 2.6)
