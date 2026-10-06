extends Node
class_name Net
# Connexion à Supabase (vrai serveur) : compte invité automatique, sauvegarde en ligne,
# profil (nom + puissance) et chat « Monde » partagé entre les vrais joueurs.
# Seules l'URL et la clé PUBLIQUE sont dans le jeu (jamais la clé secrète).
# Si le réseau ne répond pas, le jeu continue normalement en solo.

const URL := "https://xtbolgcxyegdwpvpcupc.supabase.co"
const KEY := "sb_publishable_u2uC7CQjQ9YyMXF7Y89G8Q_Np6xKSk4"
const CFG := "user://net.json"

var main: Node
var token := ""
var refresh_tok := ""
var uid := ""
var online := false
var status := "Connexion au serveur…"
var last_chat := 0
var t_poll := 3.0
var t_save := 60.0
var t_refresh := 3000.0
var t_retry := 0.0
var players_online := 0
var top: Array = []          # classement des vrais joueurs [{name, power}]

func setup(m: Node) -> void:
	main = m
	if FileAccess.file_exists(CFG):
		var d = JSON.parse_string(FileAccess.open(CFG, FileAccess.READ).get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			refresh_tok = str(d.get("refresh", "")); uid = str(d.get("uid", ""))
	_login()

func _store() -> void:
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"refresh": refresh_tok, "uid": uid}))

func pname() -> String:
	var n := str(Game.S.get("pname", ""))
	if n == "" or n == "Aventurier": n = "Voyageur-" + (uid.substr(0, 4).to_upper() if uid != "" else "????")
	return n.substr(0, 24)

# ——— requêtes HTTP (une à la fois par appel, jamais bloquantes) ———
func _req(method: int, path: String, body, extra: Array, cb: Callable) -> void:
	var h := HTTPRequest.new(); h.timeout = 12.0; add_child(h)
	var done := func(_res: int, code: int, _hd: PackedStringArray, bytes: PackedByteArray) -> void:
		h.queue_free()
		var txt := bytes.get_string_from_utf8()
		var t2 := txt.strip_edges()
		var data = JSON.parse_string(t2) if t2.begins_with("{") or t2.begins_with("[") else null
		cb.call(code, data)
	h.request_completed.connect(done)
	var hd: Array = ["apikey: " + KEY, "Content-Type: application/json"]
	if token != "": hd.append("Authorization: Bearer " + token)
	hd += extra
	var err := h.request(URL + path, PackedStringArray(hd), method, JSON.stringify(body) if body != null else "")
	if err != OK: h.queue_free(); cb.call(0, null)

func _fail(code: int, data, what: String) -> void:
	online = false
	var msg := ""
	if typeof(data) == TYPE_DICTIONARY: msg = str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "")))))
	if code == 0: status = "Hors ligne (pas de réseau)"
	elif "nonymous" in msg: status = "Serveur : active « Anonymous sign-ins » dans Supabase"
	elif code == 404 or "does not exist" in msg or "relation" in msg: status = "Serveur : tables manquantes (lance le script SQL)"
	else: status = "Serveur indisponible (%s %d)" % [what, code]
	Game.crumb("net %s : %d %s" % [what, code, msg.substr(0, 80)])
	t_retry = 60.0

# ——— compte invité (anonyme) : rien à saisir, le compte est créé au premier lancement ———
func _login() -> void:
	status = "Connexion au serveur…"
	if refresh_tok != "":
		_req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_tok}, [], _on_auth)
	else:
		_req(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {"name": pname()}}, [], _on_auth)

func _on_auth(code: int, data) -> void:
	if code == 200 and typeof(data) == TYPE_DICTIONARY and data.has("access_token"):
		token = str(data.access_token); refresh_tok = str(data.get("refresh_token", refresh_tok))
		if typeof(data.get("user")) == TYPE_DICTIONARY: uid = str(data.user.get("id", uid))
		t_refresh = float(data.get("expires_in", 3600)) * 0.8
		_store(); online = true; status = "En ligne"
		push_profile(); push_save(); _poll_chat()
		return
	# jeton périmé : on recrée un compte (la sauvegarde locale reste intacte)
	if refresh_tok != "" and code in [400, 401, 403]:
		refresh_tok = ""; token = ""; _login(); return
	_fail(code, data, "connexion")

func _process(dt: float) -> void:
	if not online:
		if t_retry > 0.0:
			t_retry -= dt
			if t_retry <= 0.0: _login()
		return
	t_refresh -= dt
	if t_refresh <= 0.0: t_refresh = 600.0; _login(); return
	t_poll -= dt
	if t_poll <= 0.0: t_poll = 6.0; _poll_chat()
	t_save -= dt
	if t_save <= 0.0: t_save = 120.0; push_save(); push_profile()

# ——— profil public (nom, puissance, carte) ———
func push_profile() -> void:
	if not online: return
	var cb := func(code: int, data) -> void:
		if code >= 300: _fail(code, data, "profil")
		else: _fetch_top()
	var body := {"id": uid, "name": pname(), "power": Game.power(), "map": int(Game.S.get("map", 1)), "updated_at": Time.get_datetime_string_from_system(true) + "Z"}
	_req(HTTPClient.METHOD_POST, "/rest/v1/profiles", body, ["Prefer: resolution=merge-duplicates,return=minimal"], cb)

func _fetch_top() -> void:
	var cb := func(code: int, data) -> void:
		if code == 200 and typeof(data) == TYPE_ARRAY: top = data; players_online = data.size()
	_req(HTTPClient.METHOD_GET, "/rest/v1/profiles?select=name,power&order=power.desc&limit=50", null, [], cb)

# ——— sauvegarde en ligne (copie de secours de la partie) ———
func push_save() -> void:
	if not online: return
	var cb := func(code: int, data) -> void:
		if code >= 300: _fail(code, data, "sauvegarde")
		else: status = "En ligne · partie sauvegardée"
	var body := {"user_id": uid, "data": Game.S, "version": Game.VERSION, "updated_at": Time.get_datetime_string_from_system(true) + "Z"}
	_req(HTTPClient.METHOD_POST, "/rest/v1/saves", body, ["Prefer: resolution=merge-duplicates,return=minimal"], cb)

# ——— chat Monde partagé ———
func send_chat(text: String, ch := "monde") -> void:
	if not online: return
	var cb := func(code: int, data) -> void:
		if code >= 300: _fail(code, data, "chat")
	_req(HTTPClient.METHOD_POST, "/rest/v1/chat", {"user_id": uid, "name": pname(), "channel": ch, "msg": text.substr(0, 200)}, ["Prefer: return=minimal"], cb)

func _poll_chat() -> void:
	var q := "/rest/v1/chat?select=id,user_id,name,channel,msg&order=id.desc&limit=20" if last_chat == 0 else "/rest/v1/chat?select=id,user_id,name,channel,msg&id=gt.%d&order=id.asc&limit=30" % last_chat
	var first := last_chat == 0
	var cb := func(code: int, data) -> void:
		if code != 200 or typeof(data) != TYPE_ARRAY:
			if code >= 300: _fail(code, data, "chat")
			return
		var rows: Array = data
		if first: rows.reverse()
		for r in rows:
			last_chat = max(last_chat, int(r.id))
			if str(r.user_id) == uid: continue
			if main and main.social: main.social.post(str(r.channel), "◆ " + str(r.name), "", str(r.msg))
	_req(HTTPClient.METHOD_GET, q, null, [], cb)
