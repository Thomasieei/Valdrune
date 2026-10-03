extends RefCounted
var m
func npc_act(a: String) -> Npc:
	for n in m.npcs:
		if n.act == a: return n
	return null
func plan(main) -> Array:
	m = main
	var O := "/tmp/claude-0/"
	var st: int = Game.get_meta("stage", 0)
	if st == 0:
		return [{"t": 0.3, "call": func():
				Game.S.tips["start"] = 1; m.hud.close_panel(); Game.S.silver = 5000000
				Game.S["seen"] = {"1": 1, "2": 1, "3": 1}
				m.cam_zoom = 1.0; m._cam_update(1.0, true)},
			{"t": 5.9, "call": func(): print("DC town1 ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 6.0, "png": O + "t1_town.png"},
			{"t": 6.1, "call": func():
				m.cam_zoom = 1.0; var g: Dictionary = m.world.gates[0]
				m.player.global_position = g.pos + Vector3(0, 1, 7); m._cam_update(1.0, true)},
			{"t": 8.0, "png": O + "t1_gate.png"},
			{"t": 8.1, "call": func(): m.hud.show_map()},
			{"t": 8.8, "png": O + "t1_map.png"},
			{"t": 8.9, "call": func():
				m.hud.close_panel(); m.player.global_position = m.camp_spawn + Vector3(0, 1, -26); m._cam_update(1.0, true)
				var e: Enemy = m._spawn_enemy("warrior", 1, m.player.global_position + Vector3(2, 0, 0), {"members": []}, false)
				e.elite = true; e.take_hit(99999, m.player, 0)},
			{"t": 10.0, "png": O + "t1_bag_ground.png"},
			{"t": 10.1, "call": func(): print("loots ", m.loots.size()); if not m.loots.is_empty(): m.open_bag(m.loots[0])},
			{"t": 10.8, "png": O + "t1_loot.png"},
			{"t": 10.9, "call": func():
				m.hud._take_all(m.hud.loot_cur); m.hud.close_panel()
				for k in 4: Game.S.items.append(Game.random_junk(2, Game.JUNK_SKEL))
				Game.S.items.append({"slot": "epee", "tier": 4, "kind": "hache"})
				m.hud.bag_sel = Game.S.items.size() - 1; m.hud.show_bag()},
			{"t": 12.0, "png": O + "t1_bagpanel.png"},
			{"t": 12.1, "call": func(): m.hud.arm_tier = 3; m.hud.show_armurier("buy")},
			{"t": 12.8, "png": O + "t1_brokk.png"},
			{"t": 12.9, "call": func():
				var sp: Dictionary = {}
				for x in m.world.spawns:
					if x.has("chest"): sp = x; break
				m.open_chest(sp)},
			{"t": 13.5, "png": O + "t1_chest.png"},
			{"t": 13.55, "call": func(): m.hud._x_close(); print("bags after close ", m.loots.size())},
			{"t": 60.0, "call": func(): m.hud.show_shop()},
			{"t": 60.6, "png": O + "t1_shop.png"},
			{"t": 60.7, "call": func(): m.hud.bag_sel = 0; m.hud.show_bag()},
			{"t": 61.3, "png": O + "t1_bag2.png"},
			{"t": 61.4, "call": func():
				m.hud.close_panel()
				var pp: Vector3 = m.player.global_position
				# rivière : on jette le héros à l'eau
				var best := Vector3.ZERO
				for i in 4000:
					var q := Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
					if m.world.height(q.x, q.z) < -1.6: best = q; break
				m.player.global_position = best + Vector3(0, m.world.height(best.x, best.z) + 0.3, 0); m._cam_update(1.0, true)
				print("in water at ", best, " walkable=", m.world.walkable(best.x, best.z))},
			{"t": 64.5, "call": func():
				var p: Vector3 = m.player.global_position
				print("after 3s walkable=", m.world.walkable(p.x, p.z), " pos=", p)},
			{"t": 64.6, "png": O + "t1_river.png"},
			{"t": 64.8, "call": func(): Game.set_meta("stage", 1); m.travel_to(2, Vector2(0, 96))}, {"t": 99.0, "call": func(): pass}]
	if st == 1:
		return [{"t": 0.3, "call": func(): m.cam_zoom = 1.0; m._cam_update(1.0, true)},
			{"t": 5.9, "call": func(): print("DC town2 ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 6.0, "png": O + "t2_town.png"},
			{"t": 6.1, "call": func():
				m.cam_zoom = 1.0
				m.player.global_position = Vector3(40, 0, -30); m.player.global_position.y = m.world.height(40, -30) + 0.5; m._cam_update(1.0, true)
				var b: Bot = m.bots[0]; b.hostile = true; b.global_position = m.player.global_position + Vector3(5, 0.5, 0)
				b._start_pvp(); m.hud.pvp_alert(b)
				var b2: Bot = m.bots[1]; b2.hostile = false; b2.global_position = m.player.global_position + Vector3(-4, 0.5, 2); b2._style()},
			{"t": 7.5, "png": O + "t2_pvp.png"},
			{"t": 9.0, "png": O + "t2_pvp2.png"},
			{"t": 9.1, "call": func():
				var en := {"pos": m.player.global_position, "tier": 2, "node": Node3D.new(), "expires": 99999.0, "seed": 1234}
				m.enter_dungeon(en)},
			{"t": 15.0, "call": func():
				var bad := 0; var n := 0
				for e in m.enemies:
					if e.dead or not e.camp.get("dungeon", false): continue
					n += 1
					if not m.dungeon.walkable(e.global_position.x, e.global_position.z): bad += 1
				print("dungeon enemies ", n, " outside floor ", bad)},
			{"t": 15.1, "png": O + "t2_dungeon.png"},
			{"t": 15.2, "call": func(): m.exit_dungeon(false); Game.set_meta("stage", 2); m.travel_to(3, Vector2(-96, 0))}, {"t": 99.0, "call": func(): pass}]
	if st == 2:
		return [{"t": 0.3, "call": func(): m.cam_zoom = 1.0; m._cam_update(1.0, true)},
			{"t": 5.9, "call": func(): print("DC town3 ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 6.0, "png": O + "t3_town.png"},
			{"t": 6.1, "call": func():
				m.cam_zoom = 1.6; m.player.global_position = Vector3(60, 0, -40); m.player.global_position.y = m.world.height(60, -40) + 0.5; m._cam_update(1.0, true)},
			{"t": 7.9, "call": func(): print("DC canyon ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 8.0, "png": O + "t3_canyon.png"},
			{"t": 8.1, "call": func(): m.hud.show_map()},
			{"t": 8.8, "png": O + "t3_map.png"},
			{"t": 8.9, "call": func(): m.hud.close_panel(); Game.set_meta("stage", 3); m.travel_to(4, Vector2(0, 96))}, {"t": 99.0, "call": func(): pass}]
	return [{"t": 0.3, "call": func(): m.cam_zoom = 1.0; m._cam_update(1.0, true)},
		{"t": 5.9, "call": func(): print("DC town4 ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 6.0, "png": O + "t4_town.png"},
		{"t": 6.1, "call": func():
			m.cam_zoom = 1.6; m.player.global_position = Vector3(-20, 0, 20); m.player.global_position.y = m.world.height(-20, 20) + 0.5; m._cam_update(1.0, true)},
		{"t": 7.9, "call": func(): print("DC swamp ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}, {"t": 8.0, "png": O + "t4_swamp.png"},
		{"t": 8.1, "call": func(): m.player.global_position = Vector3(0, 0, -80); m.player.global_position.y = m.world.height(0, -80) + 0.5; m._cam_update(1.0, true)},
		{"t": 10.0, "png": O + "t4_ash.png"},
		{"t": 10.1, "call": func(): m.hud.show_map()},
		{"t": 10.8, "png": O + "t4_map.png"},
		{"t": 10.9, "call": func(): Game.reset_save(); Game.set_meta("stage", 0)}]
