class_name Armes
## Armes du seigneur : deux emplacements (arme principale, main gauche), usure à chaque coup donné
## (arme) ou reçu (bouclier), réparation et achat à la Forge de Valmont. Sauvegarde : user://armes.json

const SAVE := "user://armes.json"

## mult = multiplicateur de dégâts, dur = solidité max, prix = or, modele/echelle = objet tenu en main,
## def = défense (boucliers), crit = chance de coup critique (dague)
const CATALOGUE := {
	"epee_courte": {"nom": "Épée courte", "slot": "main", "mult": 1.0, "dur": 120, "prix": 0, "modele": "Sword", "echelle": 1.15,
		"desc": "L'épée de vos débuts. Fiable, sans plus."},
	"epee_batarde": {"nom": "Épée bâtarde", "slot": "main", "mult": 1.3, "dur": 160, "prix": 140, "modele": "Sword", "echelle": 1.4,
		"desc": "Plus longue, plus lourde : chaque coup porte."},
	"lance_garde": {"nom": "Lance de la garde", "slot": "main", "mult": 1.25, "dur": 140, "prix": 120, "modele": "Spear", "echelle": 0.9,
		"desc": "La lance des gardes de Valmont. Tient l'ennemi à distance."},
	"lame_valmont": {"nom": "Lame de Valmont", "slot": "main", "mult": 1.75, "dur": 240, "prix": 600, "modele": "Sword", "echelle": 1.5, "or": true,
		"desc": "Chef-d'œuvre de maître Brand, acier nain trempé trois fois."},
	"aucune": {"nom": "Main nue", "slot": "gauche", "dur": 0, "prix": 0, "modele": "", "desc": "Rien en main gauche."},
	"dague": {"nom": "Dague de parade", "slot": "gauche", "crit": 0.15, "dur": 90, "prix": 60, "modele": "Knife", "echelle": 1.3,
		"desc": "15 % de chances de coup critique (dégâts x2)."},
	"bouclier_bois": {"nom": "Bouclier de bois", "slot": "gauche", "def": 3.0, "dur": 100, "prix": 80, "modele": "Shield", "echelle": 0.75,
		"desc": "Réduit chaque coup reçu de 3 points."},
	"bouclier_fer": {"nom": "Bouclier cerclé de fer", "slot": "gauche", "def": 6.0, "dur": 180, "prix": 220, "modele": "Shield", "echelle": 0.85, "fer": true,
		"desc": "Réduit chaque coup reçu de 6 points."},
}

static var possedees: Array = ["epee_courte", "aucune"]
static var main := "epee_courte"
static var gauche := "aucune"
static var usure := {"epee_courte": 120.0}    # solidité restante
static var _loaded := false
static var _warned := {}
static var _player: Node3D
static var _att_r: Node3D
static var _att_l: Node3D

static func load_game() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if d is Dictionary:
		possedees = d.get("possedees", possedees)
		main = d.get("main", main)
		gauche = d.get("gauche", gauche)
		usure = d.get("usure", usure)

static func save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"possedees": possedees, "main": main, "gauche": gauche, "usure": usure}))

static func dur_max(id: String) -> float:
	return float(CATALOGUE[id]["dur"])

static func etat(id: String) -> float:
	if dur_max(id) <= 0.0:
		return 1.0
	return clampf(float(usure.get(id, dur_max(id))) / dur_max(id), 0.0, 1.0)

## Arme usée : moins de dégâts (émoussée sous 30 %, brisée à 0)
static func _wear_mult(id: String) -> float:
	var e := etat(id)
	if e <= 0.0:
		return 0.45
	if e < 0.3:
		return 0.8
	return 1.0

## Multiplicateur appliqué aux dégâts de mêlée (Progression.melee_damage)
static func factor() -> float:
	load_game()
	var m := float(CATALOGUE[main].get("mult", 1.0)) * _wear_mult(main)
	var crit := float(CATALOGUE[gauche].get("crit", 0.0)) * (1.0 if etat(gauche) > 0.0 else 0.0)
	if crit > 0.0 and randf() < crit:
		m *= 2.0
	return m

## Un coup porté : l'arme s'use un peu
static func on_hit() -> void:
	load_game()
	_use(main, 1.0)
	if CATALOGUE[gauche].has("crit"):
		_use(gauche, 0.4)

## Un coup reçu : le bouclier encaisse et s'use
static func on_hurt() -> void:
	if CATALOGUE[gauche].has("def"):
		_use(gauche, 1.0)
		_apply_defense()

static func _use(id: String, n: float) -> void:
	if dur_max(id) <= 0.0:
		return
	var before := etat(id)
	usure[id] = maxf(0.0, float(usure.get(id, dur_max(id))) - n)
	var after := etat(id)
	var nom: String = CATALOGUE[id]["nom"]
	if before >= 0.3 and after < 0.3:
		_say("%s s'émousse : faites-la réparer à la forge." % nom, Color(1.0, 0.75, 0.35))
	elif before > 0.0 and after <= 0.0:
		_say("%s est brisée ! Dégâts fortement réduits." % nom, Color(1.0, 0.4, 0.3))
	if int(usure[id]) % 10 == 0:
		save()

static func _say(t: String, c: Color) -> void:
	if Combat.player and Combat.player.combat:
		Combat.player.combat.message.emit(t, c)

static func repair_cost(id: String) -> int:
	var cat: Dictionary = CATALOGUE[id]
	var missing := 1.0 - etat(id)
	return int(ceil(missing * maxf(20.0, float(cat["prix"]) * 0.35)))

static func repair(id: String) -> bool:
	var cost := repair_cost(id)
	var p := Progression.get_inst()
	if cost <= 0 or p.gold < cost:
		return false
	p.add_gold(-cost)
	usure[id] = dur_max(id)
	save()
	_apply_defense()
	return true

static func buy(id: String) -> bool:
	var p := Progression.get_inst()
	var prix := int(CATALOGUE[id]["prix"])
	if possedees.has(id) or p.gold < prix:
		return false
	p.add_gold(-prix)
	possedees.append(id)
	usure[id] = dur_max(id)
	equip(id)
	return true

static func equip(id: String) -> void:
	if not possedees.has(id):
		return
	if CATALOGUE[id]["slot"] == "main":
		main = id
	else:
		gauche = id
	save()
	refresh_visual()

# ---------------------------------------------------------------- en main

## Appelé une fois le joueur créé : objets tenus et défense du bouclier
static func setup(player: Node3D) -> void:
	load_game()
	_player = player
	var skel: Skeleton3D = player.model.get_node("Armature/Skeleton3D")
	for c in skel.get_children():
		if c is BoneAttachment3D and c.bone_name == "hand_r":
			_att_r = c
	_att_l = BoneAttachment3D.new()
	_att_l.bone_name = "hand_l"
	skel.add_child(_att_l)
	player.cbt.damaged.connect(func(_a, _s): on_hurt())
	refresh_visual()

static func refresh_visual() -> void:
	if not is_instance_valid(_player):
		return
	if is_instance_valid(_att_r):
		for c in _att_r.get_children():
			c.queue_free()
		_hold(_att_r, main, Vector3(-90, 0, 0))
	if is_instance_valid(_att_l):
		for c in _att_l.get_children():
			c.queue_free()
		_hold(_att_l, gauche, Vector3(0, 90, 0) if CATALOGUE[gauche].has("def") else Vector3(-90, 0, 0))
	_apply_defense()

static func _hold(att: Node3D, id: String, rot: Vector3) -> void:
	var cat: Dictionary = CATALOGUE[id]
	if String(cat["modele"]) == "":
		return
	var n := Kit.dungeon(att, cat["modele"], Vector3.ZERO, 0.0, float(cat.get("echelle", 1.0)))
	n.rotation_degrees = rot
	if cat.get("or", false) or cat.get("fer", false):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Kit.lpd_material().albedo_texture
		m.albedo_color = Color(1.0, 0.85, 0.45) if cat.get("or", false) else Color(0.75, 0.78, 0.85)
		m.metallic = 0.6
		m.roughness = 0.35
		if cat.get("or", false):
			m.emission_enabled = true
			m.emission = Color(0.9, 0.6, 0.2)
			m.emission_energy_multiplier = 0.35
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = m

static func _apply_defense() -> void:
	if not is_instance_valid(_player):
		return
	var d := float(CATALOGUE[gauche].get("def", 0.0))
	if etat(gauche) <= 0.0:
		d *= 0.3
	_player.cbt.defense = d
