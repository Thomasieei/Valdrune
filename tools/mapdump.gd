extends SceneTree
## Carte du site du bourg : hauteur, rivière, routes, zones réservées (pour dessiner le plan)
func _init():
	var x0 := -130; var z0 := -100; var w := 230; var h := 200
	var img := Image.create(w * 4, h * 4, false, Image.FORMAT_RGB8)
	for j in h * 4:
		for i in w * 4:
			var p := Vector2(x0 + i * 0.25, z0 + j * 0.25)
			var y := Layout.height(p.x, p.y)
			var c := Color(0.25 + y * 0.04, 0.45 + y * 0.03, 0.25)
			if int(floor(y)) % 2 == 0: c = c.darkened(0.08)
			if Layout.river_dist(p) < Layout.RIVER_W: c = Color(0.2, 0.4, 0.8)
			elif Layout.road_dist(p) < 0: c = Color(0.75, 0.7, 0.6)
			if Layout.in_castle(p, 0): c = Color(0.5, 0.5, 0.5)
			if Layout.in_fields(p, 0): c = c.lerp(Color(0.7, 0.55, 0.3), 0.5)
			if int(p.x) % 10 == 0 and absf(p.x - round(p.x)) < 0.13 or int(p.y) % 10 == 0 and absf(p.y - round(p.y)) < 0.13: c = c.darkened(0.3)
			if (int(p.x) % 50 == 0 and absf(p.x - round(p.x)) < 0.13) or (int(p.y) % 50 == 0 and absf(p.y - round(p.y)) < 0.13): c = Color(1, 0, 0)
			img.set_pixel(i, j, c)
	img.save_png("res://shots/site.png")
	var s := ""
	for z in range(-80, 75, 10):
		var line := "%4d:" % z
		for x in range(-110, 70, 10):
			line += "%5.1f" % Layout.height(x, z)
		s += line + "\n"
	print(s)
	quit()
