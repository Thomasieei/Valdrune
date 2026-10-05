extends Node3D
class_name Npc
# Habitants : se promènent, regardent le joueur, parlent

const LINES := {
	"brokk": ["Armes, boucliers, tenues : je vends tout. Et avec ton bois, ton minerai et ta fibre, je te fabrique ce que tu veux — plus le tier est haut, plus ça se revend cher !"],
	"mara": ["Bois, minerai, fibre… j'achète tout. Et j'ai des potions pour les téméraires."],
	"aldric": [],
	"corvin": ["L'Hôtel des ventes de Valdrune ! Achète l'équipement des autres aventuriers… ou vends le tien au prix que tu veux. Mais attention : trop cher, personne n'achètera."],
	"hilda": ["Bienvenue à l'auberge ! Les voyageurs disent que le Bois de Chênevert, à l'ouest, regorge de pins noirs.",
		"Un conseil : les squelettes dorés sont des élites. Plus forts… mais ils lâchent toujours un beau butin.",
		"On raconte que des coffres dorés sont cachés un peu partout. Ouvre l'œil quand tu explores !"],
	"gael": ["Halte, aventurier. Au-delà du pont, chaque région est plus dangereuse que la précédente.",
		"Regarde la couleur en haut de l'écran quand tu changes de région : gris, vert, cyan, bleu… et rouge. Le rouge, c'est la mort assurée sans bon équipement.",
		"Esquive les cercles rouges au sol. Toujours."],
	"lina": ["Il fait bon vivre à Valdrune… tant qu'on ne s'aventure pas trop loin.", "Tu as vu le moulin au sud ? Mon père y travaillait."],
	"pip": ["Tu veux faire la course ? … Ah non, t'as une armure, c'est pas juste !", "Un jour je serai chevalier comme Sire Gaël !"],
	"bram": ["Les champs sont beaux cette année. Les squelettes du vieux sanctuaire, à l'ouest, me font peur par contre.", "Le coton pousse bien dans les prés autour du village."],
	"ysaline": ["Ysaline, enchanteresse. Je peux graver la magie dans ton équipement : jusqu'à cinq fois par pièce. Mais la magie se paie… très cher."],
	"bjorn": ["Une bonne hache, c'est la moitié du travail. L'autre moitié, c'est l'expérience : plus tu coupes, plus tu deviens rapide… et plus tu pourras t'attaquer à des bois rares."],
	"gorm": ["Le minerai, ça se mérite. Monte ton niveau de mineur et je te vendrai des pioches capables de fendre le titane."],
	"sylve": ["Coton, lin, soie-ciel… Chaque fibre demande de l'expérience. Une faucille légendaire, et tu cueilleras deux fois plus vite."],
	"marlo": ["Ahoy ! Capitaine Marlo. Je vends des îles aux plus riches aventuriers du royaume. Cent millions, et elle est à toi."],
	"rhea": ["Rhéa, capitaine des mercenaires. Seul, on meurt vite là-dehors. Avec ma compagnie, tu formes un vrai groupe de 4 — et les grandes bêtes ne t'ignoreront plus."],
	"voyageur": ["Orin, marchand ambulant ! Potions et bonnes affaires, sur la route entre le village et la forêt."],
	"tomas": ["Ces pins noirs donnent le meilleur bois du royaume. Il te faut une hache T2 pour les couper.", "Fais gaffe au repaire des pillards, plus au sud de la forêt."],
	"ilse": ["La Mine d'Ambre regorge de fer… si tu as la pioche qu'il faut.", "Les falaises des collines sont infranchissables : suis les chemins !"],
	"ermite": ["Hmm… un visiteur. Rare, par ici. Le château effondré cache encore des trésors.", "Au nord, les Pics de Cendre. Le Seigneur d'Os y règne. N'y va pas sans une arme T5."],
}

# Objets tenus en main (pour donner du caractère aux habitants)
const PROPS := {
	"brokk": [["handslot.r", "hammer_A"]],
	"gael": [["handslot.r", "sword_C"], ["handslot.l", "shield_square"]],
	"aldric": [["handslot.r", "staff"]],
	"corvin": [["handslot.r", "wand_A"]],
	"tomas": [["handslot.r", "axe_1handed"]],
	"ilse": [["handslot.r", "hammer_A"]],
	"ermite": [["handslot.r", "staff_A"]],
	"rhea": [["handslot.r", "sword_D"], ["handslot.l", "shield_C"]],
	"ysaline": [["handslot.r", "staff_B"]],
	"bjorn": [["handslot.r", "axe_1handed"]],
	"gorm": [["handslot.r", "hammer_A"]],
	"sylve": [["handslot.r", "dagger_A"]],
}

var main: Node
var id := ""
var nm := ""
var role := ""
var act := "talk"
var ch: Dictionary
var ap: AnimationPlayer
var path: Array = []
var pi := 0
var wait := 0.0
var home := Vector3.ZERO
var yaw := 0.0
var cur := ""
var talk_i := 0
var marker: Label3D
var data: Dictionary
var hidden := false
var indoor := false
var door_idx: Array = []

func setup(m: Node, d: Dictionary) -> void:
	main = m; id = d.id; nm = d.name; role = d.role; act = d.act; data = d
	ch = Chars.make("res://assets/heroes/%s.glb" % d.model); add_child(ch.root); ap = ch.ap
	ch.root.scale = Vector3.ONE * d.get("scale", 1.0)
	for pr in PROPS.get(id, []): Chars.attach(ch, pr[0], Game.W % pr[1], 1.0)
	if d.act == "guard":
		Chars.attach(ch, "handslot.r", Game.W % "halberd", 1.0); Chars.attach(ch, "handslot.l", Game.W % "shield_square", 1.0)
	if act == "duel":
		Chars.attach(ch, "handslot.r", Game.weapon_model(d.wkind, d.tier), 1.0)
		if d.model in ["Knight", "Barbarian"] and d.wkind != "baton": Chars.attach(ch, "handslot.l", Game.shield_model(d.tier), 1.0)
	home = d.pos; home.y = main.world.height(home.x, home.z); position = home
	for p in d.get("path", []): path.append(Vector3(p.x, 0, p.y))
	door_idx = d.get("doors", [])
	pi = int(d.get("start", 0)) % max(1, path.size())
	yaw = float(d.get("yaw", randf() * TAU))
	var l := Label3D.new(); l.text = nm; l.font_size = 50; l.outline_size = 12; l.modulate = Color("#fff4d6"); l.outline_modulate = Color(0, 0, 0, 0.75)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.0065; l.position.y = 2.55 * d.get("scale", 1.0); l.no_depth_test = true; add_child(l)
	var r := Label3D.new(); r.text = role; r.font_size = 34; r.outline_size = 9; r.modulate = Color("#c9e6ff"); r.outline_modulate = Color(0, 0, 0, 0.7)
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED; r.pixel_size = 0.0065; r.position.y = 2.3 * d.get("scale", 1.0); r.no_depth_test = true; add_child(r)
	if act in ["quest", "auction", "duel", "mercs", "enchant", "tools", "forge", "harbor", "tools3", "travel", "shop"]:
		marker = Label3D.new(); marker.text = {"quest": "!", "auction": "$", "duel": "VS", "mercs": "+", "enchant": "+5", "tools": "★", "forge": "★", "harbor": "ÎLES", "tools3": "★", "travel": "»", "shop": "$"}[act]; marker.font_size = 90 if act != "duel" else 70; marker.outline_size = 16
		marker.modulate = {"duel": Color("#ff7a4a"), "enchant": Color("#d58bff")}.get(act, Color("#ffd24a")); marker.outline_modulate = Color(0.3, 0.15, 0, 0.9); marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED; marker.pixel_size = 0.008; marker.position.y = 3.15 * d.get("scale", 1.0); marker.no_depth_test = true; add_child(marker)
	var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.4; cy.height = 2.0; cs.shape = cy; cs.position.y = 1.0; b.add_child(cs); add_child(b)
	_play("Idle_A")

func _play(n: String, sp := 1.0) -> void:
	if n == cur: return
	cur = n; ap.play(n, 0.25); ap.speed_scale = sp

func _process(dt: float) -> void:
	if hidden: return
	var P: Node3D = main.player
	var d := Vector2(P.global_position.x - position.x, P.global_position.z - position.z)
	if marker: marker.position.y = 3.15 * data.get("scale", 1.0) + sin(Time.get_ticks_msec() * 0.004) * 0.12
	var far := d.length() > 45.0
	if ap.active == far: ap.active = not far   # loin : animation coupée (gros gain sur mobile)
	if far: return
	if indoor:
		wait -= dt
		if wait <= 0.0:
			indoor = false; ch.root.visible = true; _labels(true)
			pi = (pi + 1) % path.size()
		return
	if d.length() < 4.0:
		yaw = lerp_angle(yaw, atan2(d.x, d.y), 1.0 - exp(-dt * 6.0)); _play("Idle_A")
	elif act == "guard":
		yaw = lerp_angle(yaw, float(data.yaw), 1.0 - exp(-dt * 3.0)); _play("Idle_A")
	elif not path.is_empty():
		if wait > 0.0: wait -= dt; _play("Idle_B")
		else:
			var t: Vector3 = path[pi]; var to := Vector2(t.x - position.x, t.z - position.z)
			if to.length() < 0.4:
				if pi in door_idx:
					# il rentre chez lui un moment
					indoor = true; wait = randf_range(6.0, 16.0); ch.root.visible = false; _labels(false)
					return
				pi = (pi + 1) % path.size(); wait = randf_range(1.0, 3.5) if not door_idx.is_empty() else randf_range(1.5, 4.0)
			else:
				var v := to.normalized() * 1.5 * dt
				position.x += v.x; position.z += v.y; position.y = main.world.height(position.x, position.z)
				yaw = lerp_angle(yaw, atan2(to.x, to.y), 1.0 - exp(-dt * 6.0)); _play("Walking_A", 0.9)
	ch.root.rotation.y = yaw

func _labels(on: bool) -> void:
	for c in get_children():
		if c is Label3D: c.visible = on

func hide_for_duel(on: bool) -> void:
	hidden = on; visible = not on
	position.y = (main.world.height(home.x, home.z) - 60.0) if on else main.world.height(home.x, home.z)
	if not on: position.x = home.x; position.z = home.z

const ACT_LINES := {
	"forge": ["Je vends des armes et des tenues, et je forge avec tes ressources. Mais pas de raccourci : chaque tier se débloque en portant le précédent."],
	"shop": ["Bois, minerai, fibre… j'achète tout. Et ton bric-à-brac aussi, je le reprends sur-le-champ !", "Des potions ? J'en ai toujours pour les téméraires."],
	"auction": ["L'hôtel des ventes : achète ce que les autres aventuriers revendent… ou vends au prix que tu veux."],
	"mercs": ["Seul, on meurt vite. Avec ma compagnie, tu formes un vrai groupe de 4."],
	"tools3": ["Haches, pioches, faucilles : j'ai tout, du commun au légendaire. Encore faut-il avoir le niveau pour s'en servir."],
	"travel": ["Je connais toutes les routes du royaume."],
	"guard": ["Halte ! … Ah, un aventurier. Passe, la ville est sûre.", "Personne n'entre armé de mauvaises intentions. Pas sous ma garde.", "Les routes sont calmes de jour. La nuit, c'est une autre histoire.", "Si tu croises des joueurs hostiles, reviens en ville : ici, on ne se bat pas."],
	"farmer": ["Sers-toi dans le potager si tu veux, ça repousse vite. Mais laisse-en un peu pour les autres !", "Un légume frais, ça remet d'aplomb mieux qu'une potion. Mange-en depuis ton sac.",
		"Les bêtes sont nerveuses ce soir… les loups rôdent près des champs.", "Ce que tu cueilles se revend bien chez la marchande, surtout les fruits des régions lointaines."],
	"villager": ["Belle journée pour flâner, pas vrai ?", "Mon voisin jure avoir vu un loup géant près du moulin.", "Les nuits sont dangereuses : les monstres deviennent plus forts… mais on dit que leur butin aussi.",
		"Tu cherches du travail ? Le chef de la ville a toujours une tâche pour les aventuriers.", "Ne t'approche pas des terres rouges sans bon équipement. Là-bas, on perd tout.", "Ma fille veut devenir aventurière. Je préférerais qu'elle fasse du pain."],
}

func next_line() -> String:
	if id == "aldric" or act == "quest": return main.quest_line()
	var arr: Array = LINES.get(id, ACT_LINES.get(act, ["…"]))
	var t: String = arr[talk_i % arr.size()]; talk_i += 1
	return t
