extends RefCounted
class_name VQuests
# Quêtes des habitants : chaque métier a sa petite histoire, débloquée par la réputation.
# On gagne la confiance du royaume en aidant ses habitants ; les plus belles récompenses
# (enchantement, quête secrète) ne s'ouvrent qu'aux amis… et aux héros.

var main: Node

const Q := {
	"forge": [
		{"title": "Prouve ta valeur", "goal": "kill_loup", "n": 5, "rep": 8, "need": -100,
			"ask": "Hmpf. Encore un étranger qui veut une épée…\nLes [b]loups[/b] rôdent autour du village. Tues-en [b]5[/b], et on en reparlera.",
			"done": "…Pas mal, gamin. Prends ce [b]couteau à dépecer[/b] : désormais, les bêtes que tu abats te laisseront leur peau.",
			"r": {"silver": 150, "knife": 1}},
		{"title": "Du cuir pour la forge", "goal": "give_hides", "n": 6, "rep": 12, "need": -100,
			"ask": "Mon cuir est épuisé. Ramène-moi [b]6 peaux[/b] et je te taille une armure qui tient la route.",
			"done": "Ha ! Du beau cuir. Voilà ta [b]veste de cuir[/b], cousue main. Et dis aux autres que Brokk est réglo.",
			"r": {"silver": 250, "leather": true}},
		{"title": "Le métal des braves", "goal": "give_ore", "n": 15, "rep": 15, "need": 0,
			"ask": "Les gens commencent à parler de toi… en bien. Apporte-moi [b]15 minerais[/b], je dois forger pour la garde.",
			"done": "La garde aura ses lames grâce à toi. Tiens — et passe quand tu veux, la forge t'est ouverte.",
			"r": {"silver": 600, "crowns": 10}},
	],
	"shop": [
		{"title": "Cueillette", "goal": "food", "n": 8, "rep": 8, "need": -100,
			"ask": "Tu traînes dans les champs ? Cueille-moi [b]8 fruits ou légumes[/b]. Mes étals sont vides.",
			"done": "Merci… t'es moins mauvais que ce qu'on raconte. Prends ces [b]potions[/b].",
			"r": {"potions": 5}},
		{"title": "Bois de chauffe", "goal": "give_wood", "n": 25, "rep": 10, "need": -40,
			"ask": "L'hiver approche. Il me faudrait [b]25 bûches[/b] pour l'auberge et les anciens.",
			"done": "Les anciens dormiront au chaud cette nuit. Merci, vraiment.",
			"r": {"silver": 300}},
	],
	"mercs": [
		{"title": "Défends le village", "goal": "kill_near", "n": 12, "rep": 12, "need": -100,
			"ask": "Les monstres s'approchent des murs. Abats-en [b]12 autour du village[/b] et la garde te respectera.",
			"done": "Les patrouilles disent t'avoir vu te battre. Bon travail, soldat.",
			"r": {"silver": 300}},
		{"title": "Chasse aux élites", "goal": "elite", "n": 3, "rep": 15, "need": 0,
			"ask": "Des [b]monstres d'élite[/b] mènent les attaques. Abats-en [b]3[/b].",
			"done": "Sans leurs chefs, ils hésitent. Le royaume te doit beaucoup.",
			"r": {"crowns": 15, "silver": 300}},
	],
	"tools": [
		{"title": "Main-d'œuvre", "goal": "gather", "n": 30, "rep": 8, "need": -100,
			"ask": "Tu veux que les gens d'ici t'acceptent ? Travaille comme eux. Récolte [b]30 ressources[/b].",
			"done": "T'as des ampoules aux mains, maintenant. Ça, ça inspire le respect.",
			"r": {"silver": 200}},
	],
	"quest": [
		{"title": "Explorateur du royaume", "goal": "poi", "n": 3, "rep": 10, "need": -100,
			"ask": "Un étranger ne connaît pas nos terres… Découvre [b]3 lieux[/b] de ce royaume, et reviens me les raconter.",
			"done": "Tu as vu ce que nos yeux ne voient plus. Merci, voyageur.",
			"r": {"silver": 200}},
		{"title": "La Crypte Oubliée", "goal": "secret", "n": 1, "rep": 20, "need": 70, "secret": true,
			"ask": "[i]Approche… Seuls les héros du royaume peuvent entendre ceci.[/i]\nUn [b]Gardien Oublié[/b] dort sous nos terres. Je t'ai marqué l'endroit sur ta carte. Vaincs-le.",
			"done": "Le Gardien est tombé… La légende parlera de toi. Ceci t'appartient désormais.",
			"r": {"crowns": 60, "artefact": true}},
	],
}
const ROLE_NAME := {"forge": "l'armurier", "shop": "la marchande", "mercs": "la capitaine", "tools": "l'artisan", "quest": "l'Ancien"}

func _init(m: Node) -> void: main = m

static func chain_of(act: String) -> String:
	if act == "tools3": return "tools"
	return act if Q.has(act) else ""

func st() -> Dictionary:
	if typeof(Game.S.get("vq")) != TYPE_DICTIONARY: Game.S["vq"] = {}
	var k := str(main.world.map_id)
	if not Game.S.vq.has(k): Game.S.vq[k] = {}
	return Game.S.vq[k]
func state(chain: String) -> Dictionary:
	var s := st()
	if not s.has(chain): s[chain] = {"stage": 0, "n": 0, "on": false}
	return s[chain]
func cur(chain: String) -> Dictionary:
	var stt := state(chain)
	var arr: Array = Q[chain]
	return arr[int(stt.stage)] if int(stt.stage) < arr.size() else {}

# état d'un PNJ pour son marqueur : "ready" (?), "offer" (!), "locked" (…), "on" (en cours), ""
func npc_state(act: String) -> String:
	var ch := chain_of(act)
	if ch == "": return ""
	var q := cur(ch)
	if q.is_empty(): return ""
	var stt := state(ch)
	if stt.on: return "ready" if is_complete(ch) else "on"
	if Game.rep() < int(q.need): return "locked"
	return "offer"

func is_complete(ch: String) -> bool:
	var q := cur(ch); var stt := state(ch)
	if q.is_empty() or not stt.on: return false
	match str(q.goal):
		"give_hides": return int(Game.S.get("hides", 0)) >= int(q.n)
		"give_wood": return _inv_sum("wood") >= int(q.n)
		"give_ore": return _inv_sum("ore") >= int(q.n)
	return int(stt.n) >= int(q.n)
func progress_text(ch: String) -> String:
	var q := cur(ch); var stt := state(ch)
	var have: int = int(stt.n)
	match str(q.goal):
		"give_hides": have = int(Game.S.get("hides", 0))
		"give_wood": have = _inv_sum("wood")
		"give_ore": have = _inv_sum("ore")
	return "%d / %d" % [min(have, int(q.n)), int(q.n)]
func _inv_sum(k: String) -> int:
	var t := 0
	for i in range(1, 6): t += int(Game.S.inv[k][i])
	return t
func _inv_take(k: String, n: int) -> void:
	for i in range(1, 6):
		var take: int = min(n, int(Game.S.inv[k][i])); Game.S.inv[k][i] -= take; n -= take
		if n <= 0: return

# événements du jeu → progression
func event(goal: String, n := 1) -> void:
	for ch in Q:
		var q := cur(ch); var stt := state(ch)
		if q.is_empty() or not stt.on or str(q.goal) != goal: continue
		var was := is_complete(ch)
		stt.n = int(stt.n) + n
		if not was and is_complete(ch):
			main.hud.toast("Quête « %s » accomplie : retourne voir %s" % [q.title, ROLE_NAME.get(ch, "l'habitant")], Color("#7dff8a"), true)
			Game.play("level", -6.0, 1.2)
	main.update_goal()

func accept(ch: String) -> void:
	var stt := state(ch); stt.on = true; stt.n = 0
	var q := cur(ch)
	if q.get("secret", false): main.spawn_secret_boss()
	Game.crumb("quête acceptée : %s" % q.title); Game.save(); main.update_goal()

func turn_in(ch: String, n: Npc) -> void:
	var q := cur(ch)
	if q.is_empty() or not is_complete(ch): return
	match str(q.goal):
		"give_hides": Game.S.hides = int(Game.S.hides) - int(q.n)
		"give_wood": _inv_take("wood", int(q.n))
		"give_ore": _inv_take("ore", int(q.n))
	var r: Dictionary = q.r
	var got: Array = []
	if r.has("silver"): Game.S.silver += int(r.silver); got.append("+%s argent" % Game.fmt(int(r.silver)))
	if r.has("potions"): Game.S.potions += int(r.potions); got.append("+%d potions" % int(r.potions))
	if r.has("crowns"): Game.add_crowns(int(r.crowns)); got.append("+%d couronnes" % int(r.crowns))
	if r.has("knife"): Game.S["knife"] = max(int(Game.S.get("knife", 0)), int(r.knife)); got.append("Couteau à dépecer T%d" % int(r.knife))
	if r.has("leather"):
		var it := {"slot": "armure", "tier": clamp(int(Game.S.gear.get("armure", 1)) + 1, 2, 5), "kind": "cuir"}
		if Game.add_item(it): got.append(Game.item_name(it))
	if r.has("artefact"):
		var art := Game.random_artefact(clamp(int(Game.S.gear.get("epee", 1)) + 1, 2, 5))
		if Game.add_item(art): got.append(Game.item_name(art))
	var stt := state(ch); stt.stage = int(stt.stage) + 1; stt.n = 0; stt.on = false
	var lv: Array = Game.rep_add(int(q.rep))
	got.append("+%d réputation" % int(q.rep))
	Game.play("level"); main.emote(n, "heart")
	main.hud.show_dialog(n, "%s\n\n[color=#7dff8a]%s[/color]" % [q.done, " · ".join(got)], [["Merci !", func(): main.hud.close_panel(); main.rep_feedback(lv), true]])
	Game.crumb("quête rendue : %s" % q.title); Game.save(); main.update_goal()

# quête active la plus avancée (pour l'objectif à l'écran)
func active() -> Array:
	for ch in Q:
		var stt := state(ch)
		if stt.on: return [ch, cur(ch)]
	return []
