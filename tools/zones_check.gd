extends SceneTree
func _init():
	for z in Spawner.ZONES:
		var p: Vector2 = z["pos"]
		print(z["label"], " h=", snappedf(Layout.height(p.x, p.y), 0.1), " riviere=", snappedf(Layout.river_dist(p), 0.1), " route=", snappedf(Layout.road_dist(p), 0.1), " reserve=", Layout.reserved(p))
	quit()
