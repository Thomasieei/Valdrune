class_name Army
## L'armée du royaume, façon Age of Empires : on déploie tout ou partie des soldats de la garnison,
## on les envoie garder un point, patrouiller une ronde, attaquer un camp, ou suivre le souverain.

const MAX_SHOWN := 24   # au-delà, le téléphone souffre : on représente l'armée par 24 hommes au plus
static var units: Array = []

static func alive() -> Array:
	units = units.filter(func(s): return is_instance_valid(s) and not s.cbt.dead)
	return units

## Soldats encore à la caserne (on en garde toujours 2 au château)
static func reserve() -> int:
	var sold := int(Kingdom.res("soldats")) if Kingdom.inst else 6
	return maxi(0, mini(sold - 2 - Escort.members.size() - alive().size(), MAX_SHOWN - alive().size()))

## Fait sortir n soldats de la caserne (ils arrivent près du souverain s'il est loin, par un portail)
static func deploy(n: int) -> Array:
	var made: Array = []
	var pool: Array = Kingdom.data()["pnj"]["noms_h"]
	var p := Combat.player
	for i in mini(n, reserve()):
		var s := Soldier.new()
		s.nom = pool[randi() % pool.size()]
		s.home = Escort.GATE
		s.slot = (alive().size() + i) % 8
		Escort.world().add_child(s)
		var at := Escort.GATE + Vector3((i % 6) * 1.3 - 3.0, 0, int(i / 6) * 1.4)
		if p and p.global_position.distance_to(Escort.GATE) > 60.0:
			at = p.global_position + Vector3((i % 6) * 1.3 - 3.0, 0, 4.0 + int(i / 6) * 1.4)
			if i == 0:
				Magic.rune(Vector3(at.x + 3.0, Terrain.height_at(at.x, at.z) + 0.05, at.z), 4.0, Color(0.6, 0.8, 1.0), 2.4, 1.0)
				Magic.pillar(Vector3(at.x + 3.0, Terrain.height_at(at.x, at.z), at.z), Color(0.6, 0.8, 1.0), 7.0, 0.8, 3.0)
		at.y = Terrain.height_at(at.x, at.z) + 0.3
		s.global_position = at
		s.mode = Soldier.M.GARDER
		s.goal = at
		units.append(s)
		made.append(s)
	return made

## Formation en carré autour d'un point (pas tous empilés)
static func spot(center: Vector3, i: int, n: int) -> Vector3:
	var cols := maxi(1, int(ceil(sqrt(float(n)))))
	var q := center + Vector3((i % cols - (cols - 1) * 0.5) * 1.6, 0, (int(i / cols) - (cols - 1) * 0.5) * 1.6)
	q.y = Terrain.height_at(q.x, q.z) + 0.2
	return q

static func order(sel_in: Array, o: String, pts: Array = []) -> void:
	var sel := sel_in.duplicate()   # « rentrer » retire de la liste : on ne parcourt jamais l'original
	var n := sel.size()
	for i in n:
		var s: Soldier = sel[i]
		s.patrol = []
		s.passive = false
		match o:
			"suivre":
				Escort.set_mode(s, Soldier.M.ESCORTE)
			"garder", "attaquer":
				s.mode = Soldier.M.ALLER
				s.goal = spot(pts[0], i, n)
			"patrouille":
				for pt in pts:
					s.patrol.append(spot(pt, i, n))
				s.mode = Soldier.M.GARDER
				s.goal = s.patrol[0]
			"passif":
				s.passive = true
			"rentrer":
				s.mode = Soldier.M.RETOUR
				s.goal = s.home
				units.erase(s)
	if n > 0:
		sel[0].say({"suivre": "On vous suit !", "garder": "En position !", "attaquer": "À l'assaut !", "patrouille": "On fait la ronde !", "passif": "Lames au fourreau.", "rentrer": "Retour à la caserne."}.get(o, "À vos ordres !"), 2.0)
	Sfx.play("ok", -6.0)
