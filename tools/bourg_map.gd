extends SceneTree
## Plan du bourg vu de dessus : maisons (vert), lots refusés (rouge), cours (jaune), rues (gris), rivière
func _init():
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var p := BourgPlan.new()
	p.build(root)
	var x0 := -100.0; var z0 := -75.0; var S := 5.0
	var W := 160; var H := 135
	var img := Image.create(int(W * S), int(H * S), false, Image.FORMAT_RGB8)
	for j in img.get_height():
		for i in img.get_width():
			var q := Vector2(x0 + i / S, z0 + j / S)
			var c := Color(0.3, 0.45, 0.25)
			if Layout.river_dist(q) < Layout.RIVER_W: c = Color(0.2, 0.4, 0.8)
			elif Layout.road_dist(q) < 0 or p._on_street(q): c = Color(0.6, 0.6, 0.6)
			elif p._in_square(q): c = Color(0.7, 0.7, 0.65)
			if Layout.in_fields(q): c = c.lerp(Color(0.6, 0.5, 0.3), 0.6)
			for bx in p.boxes:
				if _in(q, bx): c = Color(0.85, 0.8, 0.3) if c.r < 0.7 else c
			for h in p.built:
				if _in(q, [h["pos"], Vector2(int(h["w"]), int(h["d"])) * 1.0, h["rot"]]): c = Color(0.2, 0.75, 0.3) if not h.has("name") else Color(0.2, 0.9, 0.9)
			for r in p.refused:
				if _in(q, r) and c.g < 0.7: c = Color(0.9, 0.2, 0.2)
			if (int(q.x) % 10 == 0 and absf(q.x - roundf(q.x)) < 0.11) or (int(q.y) % 10 == 0 and absf(q.y - roundf(q.y)) < 0.11): c = c.darkened(0.35)
			img.set_pixel(i, j, c)
	img.save_png("res://shots/bourg_map.png")
	for r in p.refused:
		print("refus %s %s rot=%.2f %s contre %s" % [r[0], r[1], r[2], r[3], r[4]])
	print("carte : x0=", x0, " z0=", z0, " px/m=", S, " refus=", p.why)
	quit()
func _in(q: Vector2, bx: Array) -> bool:
	var d: Vector2 = q - bx[0]
	var r: float = bx[2]
	var lx := d.dot(Vector2(cos(r), -sin(r)))
	var lz := d.dot(Vector2(sin(r), cos(r)))
	return absf(lx) <= bx[1].x and absf(lz) <= bx[1].y
