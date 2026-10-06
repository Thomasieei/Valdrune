extends Node
class_name Social
# Vie sociale : chat (monde / guilde / privé), guilde, groupe, amis, duels entre joueurs.
# Les autres « joueurs » du serveur sont simulés (bots) : ils parlent, répondent, acceptent ou refusent.

const MAX_LOG := 80
const GUILD_COST := 10000
const GROUP_MAX := 3
const WORLD_LINES := ["qq1 pour un donjon ?", "wtb épée T4 pas cher", "gg", "lag de fou là", "ce boss est cheaté mdr", "vends bois en masse, mp",
	"j'ai drop un coffre violet !!", "attention pvp dans le marais", "ça farm bien ici", "lol", "tour étage 10 qui vient ?", "quelqu'un a vu le boss de groupe ?",
	"les loups me spawnkill", "slt", "brb", "mon stuff est enfin +3", "t5 c'est hors de prix", "ez", "on est combien sur le serveur ?",
	"le chef de guerre des collines tape trop fort", "y'a des pommes dans la ferme au nord, servez-vous", "recrute pour guilde active, mp",
	"qui pour un duel à l'arène ?", "les PNJ rentrent chez eux le soir c'est trop mignon", "achète lin T2, bon prix", "vends monture loup T4"]
const GUILD_LINES := ["salut la guilde !", "qui est co ?", "je monte en zone rouge, qq1 ?", "merci pour l'aide tout à l'heure", "on fait le boss de groupe ce soir ?",
	"j'ai des potions en trop si besoin", "gg pour le chef de guerre", "bonne nuit les gars", "je farm le bois T3 si vous voulez", "les bandits ont attaqué mon île mdr"]
const REPLY_HELLO := ["slt !", "yo", "salut", "bonjour :)", "wesh"]
const REPLY_ANY := ["mdr", "ah ouais ?", "grave", "jsp", "ok", "pas faux", "t'es où ?", "ça marche", "+1", "^^"]
const WHISPER_REPLY := ["oui ?", "salut, tu veux quoi ?", "dispo dans 5 min", "ok je viens", "pas le temps là désolé", "carrément", "tu vends quoi ?", "on se fait un donjon ?"]

var main: Node
var lines: Array = []          # {ch, from, to, text}
var pending: Array = []      # réponses différées [t, Callable]
var t_world := 6.0
var t_guild := 25.0
var party: Array = []        # bots du groupe
var unread := 0

func setup(m: Node) -> void:
	main = m
	post("systeme", "", "", "Bienvenue sur Valdrune · touche un joueur pour voir sa fiche, l'inviter, lui parler ou le défier.")

func post(ch: String, from: String, to: String, text: String) -> void:
	lines.append({"ch": ch, "from": from, "to": to, "text": text})
	if lines.size() > MAX_LOG: lines.pop_front()
	unread += 1
	if main.hud: main.hud.refresh_chat()

func _later(delay: float, cb: Callable) -> void: pending.append([delay, cb])

func alive_bots() -> Array: return main.bots.filter(func(b): return is_instance_valid(b) and not b.dead)

func bot_by_name(n: String) -> Bot:
	for b in main.bots:
		if is_instance_valid(b) and b.nm == n: return b
	return null

func update(dt: float) -> void:
	for p in pending: p[0] -= dt
	var due := pending.filter(func(p): return p[0] <= 0.0)
	pending = pending.filter(func(p): return p[0] > 0.0)
	for p in due: (p[1] as Callable).call()
	t_world -= dt
	if t_world <= 0.0:
		t_world = randf_range(9.0, 22.0)
		var al := alive_bots()
		if not al.is_empty():
			var b: Bot = al[randi() % al.size()]
			post("monde", b.display_name(), "", WORLD_LINES[randi() % WORLD_LINES.size()])
	if in_guild():
		t_guild -= dt
		if t_guild <= 0.0:
			t_guild = randf_range(30.0, 70.0)
			var mem: Array = Game.S.guild.members
			if not mem.is_empty(): post("guilde", str(mem[randi() % mem.size()]), "", GUILD_LINES[randi() % GUILD_LINES.size()])
	party = party.filter(func(b): return is_instance_valid(b) and b.party)

# ——— le joueur écrit ———
func say(ch: String, text: String, to := "") -> void:
	text = text.strip_edges()
	if text == "": return
	if text.begins_with("/w ") or text.begins_with("/m "):
		var rest := text.substr(3).strip_edges(); var sp := rest.find(" ")
		if sp > 0: ch = "prive"; to = rest.substr(0, sp); text = rest.substr(sp + 1)
	if ch == "guilde" and not in_guild(): post("systeme", "", "", "Tu n'as pas de guilde : crée-la depuis l'onglet Guilde."); return
	if ch == "prive" and to == "": post("systeme", "", "", "À qui ? Écris « /w Nom message » ou ouvre la fiche d'un joueur."); return
	post(ch, "Toi", to, text)
	var low := text.to_lower()
	var hello := low.begins_with("slt") or low.begins_with("salut") or low.begins_with("yo") or low.begins_with("bonjour") or low.begins_with("cc")
	match ch:
		"prive":
			var b := bot_by_name(to)
			if b == null: _later(1.0, func(): post("systeme", "", "", "%s n'est pas connecté sur cette carte." % to)); return
			if randf() < 0.85:
				var rep: String = (REPLY_HELLO[randi() % REPLY_HELLO.size()] if hello else WHISPER_REPLY[randi() % WHISPER_REPLY.size()])
				if b.hostile and randf() < 0.4: rep = ["parle pas trop, je vais te farm", "t'as quoi comme stuff ?", "on verra en zone rouge"][randi() % 3]
				_later(randf_range(1.5, 4.0), func(): post("prive", b.display_name(), "Toi", rep))
		"guilde":
			var mem: Array = Game.S.guild.members
			if not mem.is_empty() and randf() < 0.7:
				var who: String = mem[randi() % mem.size()]
				_later(randf_range(2.0, 5.0), func(): post("guilde", who, "", (REPLY_HELLO if hello else REPLY_ANY)[randi() % (REPLY_HELLO if hello else REPLY_ANY).size()]))
		_:
			if randf() < (0.8 if hello else 0.45):
				var al := alive_bots()
				if not al.is_empty():
					var b2: Bot = al[randi() % al.size()]
					_later(randf_range(2.0, 6.0), func(): post("monde", b2.display_name(), "", (REPLY_HELLO if hello else REPLY_ANY)[randi() % (REPLY_HELLO if hello else REPLY_ANY).size()]))

# ——— guilde ———
func in_guild() -> bool: return Game.S.get("guild", {}).has("name")
func guild_tag() -> String: return "[%s] " % Game.S.guild.tag if in_guild() else ""
func guild_bonus() -> float: return min(0.10, 0.01 * Game.S.guild.members.size()) if in_guild() else 0.0

func create_guild(nm: String, tag: String) -> String:
	nm = nm.strip_edges(); tag = tag.strip_edges().to_upper()
	if in_guild(): return "Tu es déjà dans une guilde."
	if nm.length() < 3 or nm.length() > 22: return "Le nom doit faire entre 3 et 22 lettres."
	if tag.length() < 2 or tag.length() > 4: return "Le blason doit faire 2 à 4 lettres."
	if Game.S.silver < GUILD_COST: return "Il faut %s argent pour fonder une guilde." % Game.fmt(GUILD_COST)
	Game.S.silver -= GUILD_COST
	Game.S.guild = {"name": nm, "tag": tag, "members": [], "rank": "Fondateur"}
	post("systeme", "", "", "Guilde « %s » [%s] fondée ! Invite des joueurs depuis leur fiche." % [nm, tag])
	main.player.refresh_name(); Game.save()
	return ""

func leave_guild() -> void:
	if not in_guild(): return
	var old: String = Game.S.guild.name
	for n in Game.S.guild.members:
		var b := bot_by_name(n)
		if b: b.set_guild("")
	Game.S.guild = {}
	post("systeme", "", "", "Tu as quitté la guilde « %s »." % old); main.player.refresh_name(); Game.save()

func invite_guild(b: Bot) -> void:
	if not in_guild(): post("systeme", "", "", "Crée d'abord ta guilde (onglet Guilde du chat)."); return
	if b.nm in Game.S.guild.members: return
	if Game.S.guild.members.size() >= 20: post("systeme", "", "", "Ta guilde est complète (20 membres)."); return
	post("systeme", "", "", "Invitation envoyée à %s…" % b.nm)
	var ok: bool = randf() < (0.35 if b.hostile else 0.65) and b.guild == ""
	_later(randf_range(2.0, 4.0), func():
		if ok:
			Game.S.guild.members.append(b.nm); b.set_guild(Game.S.guild.tag)
			post("guilde", b.nm, "", ["merci pour l'invit !", "content d'être là", "yo la guilde", "go farmer ensemble"][randi() % 4])
			main.hud.toast("%s a rejoint ta guilde !" % b.nm, Color("#9fe0ff")); Game.save()
		else:
			post("prive", b.display_name(), "Toi", ["non merci, j'ai déjà ma guilde" if b.guild != "" else "non merci, je joue solo", "pas pour l'instant"][randi() % 2]))

func kick_guild(n: String) -> void:
	Game.S.guild.members.erase(n)
	var b := bot_by_name(n)
	if b: b.set_guild("")
	post("systeme", "", "", "%s a été exclu de la guilde." % n); Game.save()

# ——— groupe ———
func invite_group(b: Bot) -> void:
	if b.party: return
	if party.size() >= GROUP_MAX: post("systeme", "", "", "Ton groupe est complet (%d joueurs + toi)." % GROUP_MAX); return
	post("systeme", "", "", "Invitation de groupe envoyée à %s…" % b.nm)
	var ok: bool = randf() < (0.25 if b.hostile else 0.7) or (in_guild() and b.nm in Game.S.guild.members)
	_later(randf_range(1.5, 3.0), func():
		if not is_instance_valid(b) or b.dead: return
		if ok:
			b.join_party(); party.append(b)
			post("prive", b.display_name(), "Toi", ["ok j'arrive", "go !", "je te suis", "on farm quoi ?"][randi() % 4])
			main.hud.toast("%s rejoint ton groupe" % b.nm, Color("#9fe0ff"))
		else: post("prive", b.display_name(), "Toi", ["non merci", "je suis occupé là", "plus tard peut-être"][randi() % 3]))

func leave_group(b: Bot) -> void:
	if not is_instance_valid(b): return
	b.leave_party(); party.erase(b)
	post("systeme", "", "", "%s a quitté le groupe." % b.nm)

# ——— amis ———
func is_friend(n: String) -> bool: return n in Game.S.get("friends", [])
func toggle_friend(n: String) -> void:
	if is_friend(n): Game.S.friends.erase(n); post("systeme", "", "", "%s retiré de tes amis." % n)
	else: Game.S.friends.append(n); post("systeme", "", "", "%s ajouté à tes amis." % n)
	Game.save()

# ——— duel amical ———
func ask_duel(b: Bot) -> void:
	if main.world.in_town(main.player.global_position): post("systeme", "", "", "Pas de duel en ville : sortez un peu des murs."); return
	if b.mode == "pvp" or main.pvp_target != null: post("systeme", "", "", "Un combat est déjà en cours."); return
	if b.duel or duel_wait: post("systeme", "", "", "Un défi est déjà en attente."); return
	post("systeme", "", "", "Défi lancé à %s…" % b.nm)
	main.hud.toast("Défi envoyé à %s… il répond dans un instant" % b.nm, Color("#ffd27a"))
	var ok := randf() < (0.9 if b.party else 0.75)
	duel_wait = true
	_later(randf_range(1.5, 3.0), func():
		duel_wait = false
		if not is_instance_valid(b) or b.dead: return
		if not ok:
			var no: String = ["pas maintenant", "t'es trop fort pour moi mdr", "flemme"][randi() % 3]
			post("prive", b.display_name(), "Toi", no); main.hud.toast("%s refuse le duel : « %s »" % [b.nm, no], Color("#ffb07a")); return
		post("prive", b.display_name(), "Toi", ["ok, prépare-toi", "chiche", "tu vas pleurer", "go !"][randi() % 4])
		main.hud.celebrate("DUEL !", "%s accepte · premier à terre perd — rien n'est volé" % b.nm, "it_seal")
		_later(2.0, func():
			if is_instance_valid(b) and not b.dead: b.start_duel()))

var duel_wait := false
func duel_end(b: Bot, won: bool, why := "") -> void:
	var P: Player = main.player
	P.hp = P.max_hp
	if why == "temps": main.hud.celebrate("ÉGALITÉ", "Temps écoulé contre %s · personne ne gagne" % b.nm, "it_seal")
	elif why == "fuite": main.hud.celebrate("DUEL ABANDONNÉ", "Tu t'es trop éloigné de %s" % b.nm, "it_seal")
	elif won:
		Game.S.duel_wins = int(Game.S.get("duel_wins", 0)) + 1
		var gain: int = main.gain_silver(int(Game.money(b.tier) * 40.0))
		main.hud.celebrate("DUEL GAGNÉ !", "Contre %s · +%s argent · %d victoire(s)" % [b.nm, Game.fmt(gain), Game.S.duel_wins], "it_trophy")
		_later(1.5, func(): post("prive", b.display_name(), "Toi", ["gg bien joué", "revanche quand tu veux", "t'es chaud toi"][randi() % 3]))
	else:
		main.hud.celebrate("DUEL PERDU", "%s t'a battu · aucune perte, juste l'honneur" % b.nm, "it_seal")
		_later(1.5, func(): post("prive", b.display_name(), "Toi", ["gg", "ez", "pas mal quand même"][randi() % 3]))
	Game.save()
