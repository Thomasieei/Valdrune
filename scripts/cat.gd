extends Node3D
## Panthère spirituelle procédurale (style KayKit : formes rondes et trapues, couleurs franches).
## Animée par code : course, respiration, queue, griffes, bond, chute.

var legs: Array = []
var tail: Array = []
var body: Node3D
var head: Node3D
var ph := 0.0
var t := 0.0
var lunge := 0.0
var _pose := ""

func _mat(c: Color, e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.75
	if e > 0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e
	return m

func _part(parent: Node3D, mesh: Mesh, m: Material, p: Vector3, r := Vector3.ZERO, s := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m
	mi.position = p; mi.rotation = r; mi.scale = s; parent.add_child(mi); return mi

func _ready() -> void:
	var fur := _mat(Color(0.12, 0.3, 0.33)); var belly := _mat(Color(0.32, 0.55, 0.52))
	var gold := _mat(Color(1.0, 0.72, 0.25), 0.4); var eye := _mat(Color(0.75, 1.0, 0.3), 2.5); var dark := _mat(Color(0.06, 0.1, 0.12))
	body = Node3D.new(); body.position.y = 0.72; add_child(body)
	var cap := CapsuleMesh.new(); cap.radius = 0.34; cap.height = 1.35; cap.radial_segments = 12; cap.rings = 4
	_part(body, cap, fur, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	var bel := CapsuleMesh.new(); bel.radius = 0.26; bel.height = 1.0; bel.radial_segments = 10; bel.rings = 3
	_part(body, bel, belly, Vector3(0, -0.12, 0.05), Vector3(PI / 2, 0, 0))
	var sm := SphereMesh.new(); sm.radius = 0.4; sm.height = 0.8; sm.radial_segments = 12; sm.rings = 6
	_part(body, sm, fur, Vector3(0, 0.06, 0.42), Vector3.ZERO, Vector3(1, 0.95, 0.9))
	# rayures dorées
	var st := BoxMesh.new(); st.size = Vector3(0.62, 0.06, 0.08)
	for i in 4: _part(body, st, gold, Vector3(0, 0.3, -0.35 + i * 0.22), Vector3(0, 0, 0), Vector3(1 - i * 0.05, 1, 1))
	# tête
	head = Node3D.new(); head.position = Vector3(0, 0.32, 0.82); body.add_child(head)
	var hs := SphereMesh.new(); hs.radius = 0.36; hs.height = 0.66; hs.radial_segments = 14; hs.rings = 7
	_part(head, hs, fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.95, 1))
	var sn := SphereMesh.new(); sn.radius = 0.18; sn.height = 0.3; sn.radial_segments = 10; sn.rings = 5
	_part(head, sn, belly, Vector3(0, -0.1, 0.27), Vector3.ZERO, Vector3(1.2, 0.8, 1))
	var nose := SphereMesh.new(); nose.radius = 0.05; nose.height = 0.08
	_part(head, nose, dark, Vector3(0, -0.04, 0.42))
	var es := SphereMesh.new(); es.radius = 0.065; es.height = 0.11
	_part(head, es, eye, Vector3(-0.15, 0.06, 0.28)); _part(head, es, eye, Vector3(0.15, 0.06, 0.28))
	var ear := PrismMesh.new(); ear.size = Vector3(0.24, 0.3, 0.1)
	_part(head, ear, fur, Vector3(-0.2, 0.32, -0.02), Vector3(0, 0, 0.25)); _part(head, ear, fur, Vector3(0.2, 0.32, -0.02), Vector3(0, 0, -0.25))
	var ein := PrismMesh.new(); ein.size = Vector3(0.12, 0.16, 0.05)
	_part(head, ein, gold, Vector3(-0.2, 0.3, 0.03), Vector3(0, 0, 0.25)); _part(head, ein, gold, Vector3(0.2, 0.3, 0.03), Vector3(0, 0, -0.25))
	var mark := PrismMesh.new(); mark.size = Vector3(0.14, 0.18, 0.05)
	_part(head, mark, gold, Vector3(0, 0.2, 0.28), Vector3(-0.4, 0, PI))
	# pattes
	var lg := CapsuleMesh.new(); lg.radius = 0.11; lg.height = 0.62; lg.radial_segments = 8; lg.rings = 2
	var pw := SphereMesh.new(); pw.radius = 0.13; pw.height = 0.18; pw.radial_segments = 8; pw.rings = 4
	for p in [Vector3(-0.2, 0, 0.45), Vector3(0.2, 0, 0.45), Vector3(-0.2, 0, -0.45), Vector3(0.2, 0, -0.45)]:
		var piv := Node3D.new(); piv.position = p; body.add_child(piv)
		_part(piv, lg, fur, Vector3(0, -0.3, 0)); _part(piv, pw, dark, Vector3(0, -0.62, 0.04), Vector3.ZERO, Vector3(1, 0.7, 1.3))
		legs.append(piv)
	# queue
	var par: Node3D = body
	var tp := Vector3(0, 0.12, -0.72)
	var tm := CapsuleMesh.new(); tm.radius = 0.08; tm.height = 0.4; tm.radial_segments = 8; tm.rings = 2
	for i in 4:
		var seg := Node3D.new(); seg.position = tp; par.add_child(seg)
		_part(seg, tm, gold if i == 3 else fur, Vector3(0, 0, -0.17), Vector3(PI / 2, 0, 0))
		seg.rotation.x = 0.35 if i == 0 else -0.15
		tail.append(seg); par = seg; tp = Vector3(0, 0, -0.32)

func tick(spd: float, dt: float) -> void:
	t += dt
	var run: float = clamp(spd / 5.6, 0, 1.6)
	ph += dt * (3.0 + run * 9.0)
	lunge = move_toward(lunge, 0.0, dt * 3.0)
	if _pose == "dead": return
	var air := _pose == "Jump_Idle"
	var amp: float = 0.9 * min(run, 1.2)
	for i in 4:
		var off := 0.0 if i < 2 else PI
		off += 0.5 if i % 2 == 1 else 0.0
		legs[i].rotation.x = -0.9 if air and i < 2 else (0.9 if air else sin(ph + off) * amp)
	body.position.y = 0.72 + abs(sin(ph)) * 0.08 * run + sin(t * 2.0) * 0.015 * (1.0 - min(run, 1))
	body.position.z = lunge * 0.6
	body.rotation.x = sin(ph * 2.0) * 0.05 * run - lunge * 0.25
	head.rotation.x = -body.rotation.x * 0.8 + lunge * 0.3
	for i in tail.size(): tail[i].rotation.y = sin(t * 2.5 - i * 0.7) * (0.25 + 0.1 * i)

func act(n: String) -> void:
	lunge = 1.0 if n != "claw2" else 1.4

func pose(n: String) -> void:
	_pose = n
	if n == "dead":
		var tw := create_tween(); tw.tween_property(body, "rotation:z", PI / 2, 0.4); tw.parallel().tween_property(body, "position:y", 0.4, 0.4)
	else:
		body.rotation.z = 0
