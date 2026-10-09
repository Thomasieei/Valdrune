extends Node
class_name Net
# Supabase: identity, backup, public profile, world chat and Stripe commerce.
# Only the publishable key is shipped. Financial writes require the server.
const URL := "https://xtbolgcxyegdwpvpcupc.supabase.co"
const KEY := "sb_publishable_u2uC7CQjQ9YyMXF7Y89G8Q_Np6xKSk4"
const CFG := "user://net.json"
const COMMERCE := "/functions/v1/valdrune-commerce"

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
var t_wallet := 3.0
var players_online := 0
var top: Array = []
var auth_busy := false
var sync_busy := false
var purchase_busy := false
var commit_busy := false
var save_busy := false
var commit_retry := 0.0
var blocked_delivery_notice := false
var wallet_revision := -1
var checkout_requests: Dictionary = {}
var pending_spend: Dictionary = {}
var commits: Array = []
var store_status := "Vérification de la boutique…"

func setup(m: Node) -> void:
	main = m
	if FileAccess.file_exists(CFG):
		var f := FileAccess.open(CFG, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(d) == TYPE_DICTIONARY:
			refresh_tok = str(d.get("refresh", "")); uid = str(d.get("uid", ""))
			checkout_requests = d.get("checkout_requests", {}) if typeof(d.get("checkout_requests")) == TYPE_DICTIONARY else {}
			pending_spend = d.get("pending_spend", {}) if typeof(d.get("pending_spend")) == TYPE_DICTIONARY else {}
			wallet_revision = int(d.get("wallet_revision", -1))
			Game.paid_crowns = int(d.get("paid_crowns", 0))
			Game.paid_premium_until = int(d.get("paid_premium_until", 0))
	_login()

func _store() -> void:
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"refresh": refresh_tok, "uid": uid,
			"checkout_requests": checkout_requests, "pending_spend": pending_spend,
			"wallet_revision": wallet_revision, "paid_crowns": Game.paid_crowns,
			"paid_premium_until": Game.paid_premium_until}))

func pname() -> String:
	var n := str(Game.S.get("pname", "")).strip_edges()
	if n == "" or n == "Aventurier": n = "Voyageur-" + (uid.substr(0, 4).to_upper() if uid != "" else "????")
	if n.length() < 3: n += "___"
	return n.substr(0, 24)

func _req(method: int, path: String, body, extra: Array, cb: Callable) -> void:
	var h := HTTPRequest.new(); h.timeout = 25.0; h.use_threads = true; add_child(h)
	h.request_completed.connect(func(result: int, code: int, _hd: PackedStringArray, bytes: PackedByteArray):
		h.queue_free()
		var txt := bytes.get_string_from_utf8().strip_edges()
		var data = JSON.parse_string(txt) if txt.begins_with("{") or txt.begins_with("[") else null
		cb.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data))
	var hd: Array = ["apikey: " + KEY, "Content-Type: application/json"]
	if token != "": hd.append("Authorization: Bearer " + token)
	hd += extra
	var err := h.request(URL + path, PackedStringArray(hd), method, JSON.stringify(body) if body != null else "")
	if err != OK: h.queue_free(); cb.call(0, null)

func _notice(msg: String) -> void:
	if main and main.hud: main.hud.toast(msg, Color("#ffb07a"), true)

func _error(data, fallback: String) -> String:
	return str(data.get("error", fallback)) if typeof(data) == TYPE_DICTIONARY else fallback

func _fail(code: int, data, what: String) -> void:
	online = false
	var msg := ""
	if typeof(data) == TYPE_DICTIONARY: msg = str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "")))))
	if code == 0: status = "Hors ligne (pas de réseau)"
	elif "nonymous" in msg: status = "Connexion invitée indisponible"
	elif code == 404 or "does not exist" in msg or "relation" in msg: status = "Serveur indisponible"
	else: status = "Serveur indisponible (%s %d)" % [what, code]
	Game.crumb("net %s : %d" % [what, code])
	t_retry = 60.0

func _login() -> void:
	if auth_busy: return
	auth_busy = true
	status = "Connexion au serveur…"
	if refresh_tok != "":
		_req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_tok}, [], _on_auth)
	else:
		_req(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {"name": pname()}}, [], _on_auth)

func _on_auth(code: int, data) -> void:
	auth_busy = false
	if code >= 200 and code < 300 and typeof(data) == TYPE_DICTIONARY and data.has("access_token"):
		token = str(data.access_token); refresh_tok = str(data.get("refresh_token", refresh_tok))
		if typeof(data.get("user")) == TYPE_DICTIONARY: uid = str(data.user.get("id", uid))
		t_refresh = maxf(30.0, float(data.get("expires_in", 3600)) * 0.8)
		_store(); online = true; status = "En ligne"
		# Chat insertion requires the profile to exist first.
		push_profile(true); sync_wallet(); _check_store()
		return
	# Do not silently replace a guest account that owns paid purchases.
	if refresh_tok != "" and code in [400, 401, 403]:
		online = false; status = "Session du compte expirée · données locales conservées"
		t_retry = 0.0; return
	_fail(code, data, "connexion")

func _process(dt: float) -> void:
	commit_retry = maxf(0.0, commit_retry - dt)
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
	t_wallet -= dt
	if t_wallet <= 0.0:
		t_wallet = 10.0
		if not purchase_busy and not commit_busy: sync_wallet()
	if not commits.is_empty() and not commit_busy and not save_busy and commit_retry <= 0.0: _commit_next()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		t_wallet = 0.5; t_poll = 1.0
		if not online and not auth_busy and t_retry > 0.0: t_retry = 0.5

func push_profile(first := false) -> void:
	if not online: return
	var cb := func(code: int, data) -> void:
		if code == 0 or code >= 300: _fail(code, data, "profil")
		else:
			_fetch_top()
			if first: push_save(); _poll_chat()
	var body := {"user_id": uid, "display_name": pname(), "power": Game.power(), "map": int(Game.S.get("map", 1))}
	_req(HTTPClient.METHOD_POST, "/rest/v1/valdrune_profiles", body, ["Prefer: resolution=merge-duplicates,return=minimal"], cb)

func _fetch_top() -> void:
	var cb := func(code: int, data) -> void:
		if code == 200 and typeof(data) == TYPE_ARRAY:
			top = []
			for r in data: top.append({"name": str(r.display_name), "power": int(r.power)})
			players_online = data.size()
	_req(HTTPClient.METHOD_GET, "/rest/v1/valdrune_profiles?select=display_name,power&order=power.desc&limit=50", null, [], cb)

func push_save() -> void:
	if not online or save_busy or commit_busy or not commits.is_empty(): return
	save_busy = true
	var cb := func(code: int, data) -> void:
		save_busy = false
		if code == 0 or code >= 300: _fail(code, data, "sauvegarde")
		else: status = "En ligne · partie sauvegardée"
	var body := {"user_id": uid, "state": Game.S, "version": Game.VERSION, "client_updated_at": int(Time.get_unix_time_from_system() * 1000)}
	_req(HTTPClient.METHOD_POST, "/rest/v1/valdrune_cloud_saves", body, ["Prefer: resolution=merge-duplicates,return=minimal"], cb)

func send_chat(text: String, ch := "monde") -> void:
	if not online: return
	var msg := text.strip_edges().substr(0, 200)
	if msg == "" or ch not in ["monde", "commerce"]: return
	var cb := func(code: int, data) -> void:
		if code == 0: _notice("Message non envoyé : pas de réseau")
		elif code >= 300: _notice("Message non envoyé : réessaie dans quelques secondes")
	_req(HTTPClient.METHOD_POST, "/rest/v1/valdrune_chat", {"user_id": uid, "channel": ch, "body": msg}, ["Prefer: return=minimal"], cb)

func _poll_chat() -> void:
	var q := "/rest/v1/valdrune_chat?select=id,user_id,sender_name,channel,body&order=id.desc&limit=20" if last_chat == 0 else "/rest/v1/valdrune_chat?select=id,user_id,sender_name,channel,body&id=gt.%d&order=id.asc&limit=30" % last_chat
	var first := last_chat == 0
	var cb := func(code: int, data) -> void:
		if code != 200 or typeof(data) != TYPE_ARRAY:
			if code == 0 or code >= 300: _fail(code, data, "chat")
			return
		var rows: Array = data
		if first: rows.reverse()
		for r in rows:
			last_chat = maxi(last_chat, int(r.id))
			if str(r.user_id) == uid: continue
			if main and main.social:
				main.social.post(str(r.channel), "◆ " + _plain(str(r.sender_name)), "", _plain(str(r.body)))
	_req(HTTPClient.METHOD_GET, q, null, [], cb)

func _plain(s: String) -> String:
	return s.replace("[", "［").replace("]", "］")

func _new_id() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func _check_store() -> void:
	var cb := func(code: int, data) -> void:
		if code == 200 and typeof(data) == TYPE_DICTIONARY and data.get("ready", false):
			store_status = "Paiement Stripe sécurisé" if data.get("livemode", false) else "Stripe · environnement de test"
		else: store_status = _error(data, "Boutique indisponible")
	_req(HTTPClient.METHOD_POST, COMMERCE, {"action": "status"}, [], cb)

func sync_wallet() -> void:
	if not online or sync_busy or purchase_busy or commit_busy: return
	sync_busy = true
	var cb := func(code: int, data) -> void:
		sync_busy = false
		if code == 200 and typeof(data) == TYPE_DICTIONARY:
			_on_wallet(data)
			if not pending_spend.is_empty() and commits.is_empty(): _retry_spend()
		elif code == 401: t_refresh = 0.0
	_req(HTTPClient.METHOD_POST, COMMERCE, {"action": "sync"}, [], cb)

func _on_wallet(data: Dictionary) -> void:
	var w = data.get("wallet", null)
	if typeof(w) == TYPE_DICTIONARY and int(w.get("revision", 0)) >= wallet_revision:
		var before := Game.paid_crowns
		wallet_revision = int(w.get("revision", 0))
		Game.paid_crowns = int(w.get("crowns", 0))
		Game.paid_premium_until = int(w.get("premium_until", 0))
		if w.get("starter_purchased", false): Game.S["pack_debut"] = true
		_store()
		if Game.paid_crowns > before and main.hud:
			Game.play("coin")
			main.hud.toast("+%d couronnes · paiement confirmé" % (Game.paid_crowns - before), Color("#7dff8a"), true)
	var orders = data.get("orders", [])
	for o in orders:
		if str(o.get("status", "")) in ["paid", "expired", "failed", "refunded"]:
			if checkout_requests.get(str(o.offer_id), "") == str(o.id): checkout_requests.erase(str(o.offer_id))
	_store()
	for receipt in data.get("deliveries", []):
		if typeof(receipt) != TYPE_DICTIONARY: continue
		var rid := str(receipt.get("id", ""))
		if rid == "" or commits.any(func(x): return x.id == rid): continue
		# A locally persisted marker means the reward has already been applied.
		var delivered: bool = main.apply_commerce_delivery(receipt)
		if not delivered and receipt.get("kind", "") == "starter":
			if not blocked_delivery_notice: _notice("Libère une case dans ton sac pour recevoir ton cheval"); blocked_delivery_notice = true
			continue
		commits.append({"id": rid, "cancel": not delivered})
	if main: main.reopen_paid_chest()

func buy_cash(offer_id: String) -> void:
	if not online: _notice("Connecte-toi au serveur pour acheter"); return
	if purchase_busy or commit_busy or not commits.is_empty(): _notice("Un achat est déjà en cours"); return
	var request_id := str(checkout_requests.get(offer_id, ""))
	if request_id == "":
		request_id = _new_id(); checkout_requests[offer_id] = request_id; _store()
	purchase_busy = true
	var cb := func(code: int, data) -> void:
		purchase_busy = false
		if code != 200 or typeof(data) != TYPE_DICTIONARY:
			if typeof(data) == TYPE_DICTIONARY and data.get("terminal", false): checkout_requests.erase(offer_id); _store()
			_notice(_error(data, "Paiement indisponible : vérifie ta connexion")); return
		if data.has("wallet"): _on_wallet(data)
		if data.get("paid", false) or data.get("pending", false):
			_notice("Paiement en cours de vérification"); t_wallet = 0.5; return
		var checkout_url := str(data.get("checkout_url", ""))
		if not checkout_url.begins_with("https://checkout.stripe.com/"): _notice("Lien de paiement invalide"); return
		var err := OS.shell_open(checkout_url)
		if err != OK: _notice("Impossible d'ouvrir la page de paiement"); return
		_notice("Paiement ouvert · les couronnes arrivent après confirmation")
		t_wallet = 1.0
	_req(HTTPClient.METHOD_POST, COMMERCE, {"action": "checkout", "offer_id": offer_id, "request_id": request_id}, [], cb)

func buy_with_wallet(offer_id: String, free_part: int) -> void:
	if not online: _notice("Les couronnes achetées nécessitent une connexion au serveur"); return
	if purchase_busy or commit_busy or not commits.is_empty() or not pending_spend.is_empty():
		_notice("Un achat est déjà en cours"); return
	pending_spend = {"action": "spend", "offer_id": offer_id, "free_part": free_part, "request_id": _new_id()}
	_store(); _retry_spend()

func _retry_spend() -> void:
	if pending_spend.is_empty() or purchase_busy or commit_busy: return
	purchase_busy = true
	var cb := func(code: int, data) -> void:
		purchase_busy = false
		if code == 200 and typeof(data) == TYPE_DICTIONARY: _on_wallet(data)
		elif code != 0 and code < 500:
			pending_spend = {}; _store(); _notice(_error(data, "Achat refusé")); t_wallet = 0.5
		else: _notice("Achat en attente : il sera vérifié à la reconnexion")
	_req(HTTPClient.METHOD_POST, COMMERCE, pending_spend, [], cb)

func _commit_next() -> void:
	if not online or commits.is_empty() or commit_busy or save_busy: return
	commit_busy = true
	var c: Dictionary = commits[0]
	Game.save_now()
	var cb := func(code: int, data) -> void:
		commit_busy = false
		if code == 200 and typeof(data) == TYPE_DICTIONARY:
			commits.pop_front()
			if str(pending_spend.get("request_id", "")) == str(c.id): pending_spend = {}; _store()
			_on_wallet(data)
		else:
			# Keep the receipt for a retry; no second reward will be added.
			commit_retry = 5.0
			t_wallet = 5.0
			if code == 401: t_refresh = 0.0
			elif code == 0: _fail(code, data, "achat")
	_req(HTTPClient.METHOD_POST, COMMERCE, {"action": "finish", "receipt_id": c.id, "state": Game.S if not c.cancel else null, "cancel": c.cancel}, [], cb)
