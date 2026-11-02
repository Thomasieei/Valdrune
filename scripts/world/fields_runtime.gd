extends Node3D
## Met à jour les parcelles (croissance, couleur, bottes de foin) — quelques fois par seconde.

var _t := 0.0
var _acc := 0.0

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	for plot in Fields.plots:
		var st := Fields.state_of(plot, _t)
		var s := int(st.x)
		var f := st.y
		var growth := 0.0
		var ripe := 0.0
		match s:
			0: growth = 0.0
			1: growth = lerpf(0.04, 0.18, f)
			2: growth = lerpf(0.18, 0.7, f)
			3:
				growth = lerpf(0.7, 1.0, minf(f * 2.0, 1.0))
				ripe = smoothstep(0.0, 0.6, f)
			4:
				growth = 0.13 if plot["kind"] == "ble" else 0.0
				ripe = 1.0
		var mmi: MultiMeshInstance3D = plot["mmi"]
		var mat: ShaderMaterial = plot["mat"]
		mat.set_shader_parameter("growth", growth)
		mat.set_shader_parameter("ripe", ripe)
		mmi.visible = growth > 0.01
		if s != plot["state"]:
			plot["state"] = s
			_on_state(plot, s)

func _on_state(plot: Dictionary, s: int) -> void:
	for h in plot["hay"]:
		h.queue_free()
	plot["hay"] = []
	if s == 4 and plot["kind"] == "ble":
		var c: Vector2 = plot["c"]
		var sz: Vector2 = plot["size"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(c.x * 13 + c.y)
		for i in 5:
			var p := c + Vector2(rng.randf_range(-sz.x * 0.4, sz.x * 0.4), rng.randf_range(-sz.y * 0.35, sz.y * 0.35))
			var n := Kit.village(self, "Prop_Hay_1", Vector3(p.x, Terrain.height_at(p.x, p.y), p.y), rng.randf() * TAU, 1.4)
			plot["hay"].append(n)
