extends RefCounted
class_name Maps
# Les 4 cartes du royaume. Chacune couvre DEUX tiers, a sa ville, son style de terrain et ses passages.
#   1 · Val de Valdrune (T1-T2)     : prairies, rivière, la mer
#   2 · Chênevert (T2-T3)           : forêt profonde et falaises en terrasses
#   3 · Désert d'Ambre (T3-T4)      : dunes de sable et canyon écarlate
#   4 · Grisaille & Cendre (T4-T5)  : marais traversé de rivières, pics volcaniques

const NAMES := ["", "Val de Valdrune", "Chênevert", "Désert d'Ambre", "Grisaille & Cendre"]
const TIERS := [[0, 0], [1, 2], [2, 3], [3, 4], [4, 5]]
static func label(id: int) -> String: return "Carte T%d-T%d · %s" % [TIERS[id][0], TIERS[id][1], NAMES[id]]
# carte où l'on trouve ce tier « chez lui »
static func for_tier(t: int) -> int: return clamp(t - 1, 1, 4)

static func def(id: int) -> Dictionary:
	match id:
		2: return _m2()
		3: return _m3()
		4: return _m4()
	return _m1()

# ——— 1 · Val de Valdrune : prairies, rivière, mer ———
static func _m1() -> Dictionary:
	return {
		"id": 1, "terrain": "Prairies & rivière",
		"town": {"pos": Vector2(0, 80), "name": "VALDRUNE", "kind": "valdrune", "tint": Color(1, 1, 1)},
		"regions": [{},
			{"name": "Val de Valdrune", "tier": 1, "c": Vector2(0, 62), "bias": 26.0, "style": "meadow", "g0": "#5c9c40", "g1": "#7db04c", "sky": "#a9c9d8"},
			{"name": "Lisière de Chênevert", "tier": 2, "c": Vector2(0, -70), "bias": 0.0, "style": "forest", "g0": "#356f2d", "g1": "#4c8838", "sky": "#8fb3a4"},
		],
		"roads": [
			[Vector2(0, 80), Vector2(0, 56), Vector2(-18, 22), Vector2(-8, -28), Vector2(0, -70), Vector2(0, -104)],
			[Vector2(0, 56), Vector2(38, 32), Vector2(70, 12)],
			[Vector2(-18, 22), Vector2(-58, 38)],
			[Vector2(0, 80), Vector2(0, 112)],
			[Vector2(0, 96), Vector2(18, 103)],
		],
		"rivers": [[Vector2(-14, -130), Vector2(-16, -96), Vector2(10, -66), Vector2(22, -28), Vector2(8, 4), Vector2(22, 34), Vector2(40, 60), Vector2(34, 96), Vector2(44, 132)]],
		"lakes": [[Vector2(-26, 104), 7.0], [Vector2(-40, -52), 6.0], [Vector2(44, -64), 4.5]],
		"bay": Vector2(34, 124),
		"pois": [
			{"id": "sanctuaire", "name": "Vieux sanctuaire", "p": Vector2(-44, 66), "r": 6.0, "kind": "shrine"},
			{"id": "moulin", "name": "Moulin des Prés", "p": Vector2(26, 108), "r": 6.0, "kind": "windmill"},
			{"id": "etang", "name": "Étang aux saules", "p": Vector2(-26, 104), "r": 3.0, "kind": "pond"},
			{"id": "bucherons", "name": "Camp des bûcherons", "p": Vector2(-58, 38), "r": 8.0, "kind": "lumbercamp"},
			{"id": "tour", "name": "Tour Infinie", "p": Vector2(-62, 88), "r": 9.0, "kind": "tower_inf"},
			{"id": "enchant", "name": "Sanctuaire des enchantements", "p": Vector2(24, 66), "r": 5.0, "kind": "enchant"},
			{"id": "guet", "name": "Tour de guet en ruine", "p": Vector2(70, 12), "r": 6.0, "kind": "tower"},
			{"id": "arene1", "name": "Arène des duellistes", "p": Vector2(-34, 22), "r": 7.0, "kind": "arena"},
			{"id": "chene", "name": "Clairière du Grand Chêne", "p": Vector2(-72, -36), "r": 7.0, "kind": "bigtree"},
			{"id": "pillards", "name": "Repaire des pillards", "p": Vector2(52, -38), "r": 7.0, "kind": "camp", "chest": 2},
			{"id": "ermite", "name": "Cabane de l'ermite", "p": Vector2(-50, -82), "r": 5.0, "kind": "hut"},
			{"id": "voleurs", "name": "Camp des voleurs", "p": Vector2(-84, 70), "r": 6.0, "kind": "camp", "chest": 1},
		],
		"duelists": [
			{"id": "d_jory", "name": "Jory le Vif", "model": "Rogue", "wkind": "epee", "tier": 1},
			{"id": "d_brune", "name": "Brune Cœur-d'Acier", "model": "Knight", "wkind": "epee", "tier": 1},
			{"id": "d_kael", "name": "Kael la Lame", "model": "Rogue", "wkind": "epee", "tier": 2},
		],
		"hidden": [Vector2(-100, 40), Vector2(96, -70), Vector2(104, 54)],
		"gates": [{"pos": Vector2(0, -104), "to": 2, "dir": "NORD", "arrive": Vector2(0, 96)}],
	}

# ——— 2 · Chênevert : forêt et falaises ———
static func _m2() -> Dictionary:
	return {
		"id": 2, "terrain": "Forêt & falaises",
		"town": {"pos": Vector2(-10, 70), "name": "CHÊNEVERT", "kind": "town", "tint": Color(0.82, 1.0, 0.78)},
		"regions": [{},
			{"name": "Bois de Chênevert", "tier": 2, "c": Vector2(-30, 52), "bias": 18.0, "style": "forest", "g0": "#356f2d", "g1": "#4c8838", "sky": "#8fb3a4"},
			{"name": "Falaises d'Ambre", "tier": 3, "c": Vector2(42, -52), "bias": 0.0, "style": "hills", "g0": "#9a8a3c", "g1": "#b3954a", "sky": "#d0b98a"},
		],
		"roads": [
			[Vector2(-10, 70), Vector2(0, 104)],
			[Vector2(-10, 70), Vector2(8, 40), Vector2(40, 12), Vector2(80, -6), Vector2(104, -8)],
			[Vector2(8, 40), Vector2(-4, 0), Vector2(-22, -30), Vector2(-40, -50)],
			[Vector2(40, 12), Vector2(60, -20)],
			[Vector2(-4, 0), Vector2(18, -40), Vector2(20, -80)],
		],
		"rivers": [],
		"lakes": [[Vector2(-62, 18), 7.0], [Vector2(30, 34), 5.0], [Vector2(-60, -64), 6.0], [Vector2(70, 60), 5.5]],
		"bay": null,
		"pois": [
			{"id": "chene2", "name": "Clairière du Vieux Chêne", "p": Vector2(-72, 58), "r": 7.0, "kind": "bigtree"},
			{"id": "bucherons2", "name": "Scierie de Chênevert", "p": Vector2(-50, 90), "r": 8.0, "kind": "lumbercamp"},
			{"id": "pillards2", "name": "Repaire des brigands", "p": Vector2(-84, -12), "r": 7.0, "kind": "camp", "chest": 2},
			{"id": "arene2", "name": "Arène de Chênevert", "p": Vector2(26, 62), "r": 7.0, "kind": "arena"},
			{"id": "mine", "name": "Mine d'Ambre", "p": Vector2(60, -20), "r": 8.0, "kind": "mine"},
			{"id": "pierres", "name": "Cercle de pierres", "p": Vector2(76, -72), "r": 7.0, "kind": "stones"},
			{"id": "chateau", "name": "Château des falaises", "p": Vector2(-40, -50), "r": 10.0, "kind": "castle", "chest": 3},
			{"id": "guet2", "name": "Vigie des falaises", "p": Vector2(20, -80), "r": 6.0, "kind": "tower"},
		],
		"duelists": [
			{"id": "d_orso", "name": "Orso le Bûcheron", "model": "Barbarian", "wkind": "hache", "tier": 2},
			{"id": "d_sabine", "name": "Sabine des Falaises", "model": "Ranger", "wkind": "epee", "tier": 3},
			{"id": "d_ragnar", "name": "Ragnar Fend-Roc", "model": "Barbarian", "wkind": "hache", "tier": 3},
		],
		"hidden": [Vector2(-100, -60), Vector2(92, 40), Vector2(-20, -102)],
		"gates": [{"pos": Vector2(0, 104), "to": 1, "dir": "SUD", "arrive": Vector2(0, -96)},
			{"pos": Vector2(104, -8), "to": 3, "dir": "EST", "arrive": Vector2(-96, 0)}],
	}

# ——— 3 · Désert d'Ambre : dunes et canyon ———
static func _m3() -> Dictionary:
	return {
		"id": 3, "terrain": "Sable & canyon",
		"town": {"pos": Vector2(-64, 0), "name": "KSAR D'AMBRE", "kind": "town", "tint": Color(1.25, 1.05, 0.72)},
		"regions": [{},
			{"name": "Dunes d'Ambre", "tier": 3, "c": Vector2(-40, 10), "bias": 16.0, "style": "desert", "g0": "#a5804a", "g1": "#b8935c", "sky": "#d8bd88"},
			{"name": "Canyon Écarlate", "tier": 4, "c": Vector2(56, -44), "bias": 0.0, "style": "canyon", "g0": "#94482f", "g1": "#ad6640", "sky": "#d89270"},
		],
		"roads": [
			[Vector2(-64, 0), Vector2(-104, 0)],
			[Vector2(-64, 0), Vector2(-24, -8), Vector2(0, -24), Vector2(8, -64), Vector2(10, -104)],
			[Vector2(-24, -8), Vector2(30, 10), Vector2(80, 10)],
			[Vector2(30, 10), Vector2(62, -40), Vector2(62, -72)],
			[Vector2(-24, -8), Vector2(-22, 40)],
		],
		"rivers": [],
		"lakes": [[Vector2(-22, 52), 8.0], [Vector2(40, 40), 6.0], [Vector2(-40, -56), 5.0]],
		"bay": null,
		"pois": [
			{"id": "oasis", "name": "Oasis des palmes", "p": Vector2(-34, 62), "r": 4.0, "kind": "pond"},
			{"id": "temple", "name": "Temple ensablé", "p": Vector2(14, 70), "r": 10.0, "kind": "castle", "chest": 3},
			{"id": "nomades", "name": "Camp des nomades", "p": Vector2(4, -24), "r": 7.0, "kind": "camp", "chest": 3},
			{"id": "arene3", "name": "Arène des sables", "p": Vector2(-50, 34), "r": 7.0, "kind": "arena"},
			{"id": "necropole", "name": "Nécropole", "p": Vector2(-26, -80), "r": 8.0, "kind": "graveyard"},
			{"id": "forge_morte", "name": "Forge abandonnée", "p": Vector2(84, 14), "r": 6.0, "kind": "deadforge"},
			{"id": "canyon_camp", "name": "Camp du canyon", "p": Vector2(76, -42), "r": 7.0, "kind": "camp", "chest": 4},
			{"id": "autel3", "name": "Autel écarlate", "p": Vector2(62, -78), "r": 6.0, "kind": "altar"},
		],
		"duelists": [
			{"id": "d_sabra", "name": "Sabra la Dune", "model": "Ranger", "wkind": "epee", "tier": 3},
			{"id": "d_ysolde", "name": "Ysolde la Brûlante", "model": "Mage", "wkind": "baton", "tier": 4},
			{"id": "d_garm", "name": "Garm le Sec", "model": "Knight", "wkind": "hache", "tier": 4},
		],
		"hidden": [Vector2(-92, 74), Vector2(96, -92), Vector2(62, 92)],
		"gates": [{"pos": Vector2(-104, 0), "to": 2, "dir": "OUEST", "arrive": Vector2(96, -8)},
			{"pos": Vector2(10, -104), "to": 4, "dir": "NORD", "arrive": Vector2(0, 96)}],
	}

# ——— 4 · Grisaille & Cendre : marais aux rivières, pics de cendre ———
static func _m4() -> Dictionary:
	return {
		"id": 4, "terrain": "Rivières & volcans",
		"town": {"pos": Vector2(0, 80), "name": "FORT-GRIS", "kind": "town", "tint": Color(0.78, 0.8, 0.9)},
		"regions": [{},
			{"name": "Marais de Grisaille", "tier": 4, "c": Vector2(0, 46), "bias": 14.0, "style": "swamp", "g0": "#5d6b4c", "g1": "#76805c", "sky": "#8d9a8a"},
			{"name": "Pics de Cendre", "tier": 5, "c": Vector2(0, -74), "bias": 0.0, "style": "ash", "g0": "#5b4a46", "g1": "#76605a", "sky": "#9a6a60"},
		],
		"roads": [
			[Vector2(0, 80), Vector2(0, 104)],
			[Vector2(0, 80), Vector2(0, 52), Vector2(-10, 12), Vector2(0, -40), Vector2(0, -98)],
			[Vector2(0, 52), Vector2(40, 62)],
			[Vector2(-10, 12), Vector2(-50, -8)],
			[Vector2(0, -40), Vector2(-40, -80)],
			[Vector2(0, -40), Vector2(40, -88)],
			[Vector2(-10, 12), Vector2(70, 2)],
		],
		"rivers": [
			[Vector2(-132, 30), Vector2(-70, 38), Vector2(-30, 24), Vector2(20, 34), Vector2(76, 22), Vector2(132, 32)],
			[Vector2(-60, 132), Vector2(-52, 92), Vector2(-66, 60), Vector2(-60, 38)],
			[Vector2(74, 132), Vector2(62, 84), Vector2(78, 26)],
		],
		"lakes": [[Vector2(-30, 64), 4.0], [Vector2(36, 96), 4.0]],
		"bay": null,
		"pois": [
			{"id": "cimetiere", "name": "Cimetière des noyés", "p": Vector2(40, 62), "r": 8.0, "kind": "graveyard"},
			{"id": "ermite4", "name": "Hutte du passeur", "p": Vector2(-88, 76), "r": 5.0, "kind": "hut"},
			{"id": "noyes", "name": "Repaire des noyés", "p": Vector2(70, 2), "r": 7.0, "kind": "camp", "chest": 4},
			{"id": "arene4", "name": "Arène grise", "p": Vector2(-30, 82), "r": 7.0, "kind": "arena"},
			{"id": "chateau4", "name": "Château effondré", "p": Vector2(-50, -8), "r": 10.0, "kind": "castle"},
			{"id": "autel", "name": "Autel des cendres", "p": Vector2(-40, -80), "r": 6.0, "kind": "altar"},
			{"id": "forge4", "name": "Forge du volcan", "p": Vector2(40, -88), "r": 6.0, "kind": "deadforge"},
			{"id": "cendres", "name": "Camp des cendres", "p": Vector2(-76, -50), "r": 7.0, "kind": "camp", "chest": 5},
			{"id": "antre", "name": "Antre du Seigneur d'Os", "p": Vector2(0, -104), "r": 11.0, "kind": "lair"},
		],
		"duelists": [
			{"id": "d_vesper", "name": "Vesper l'Écarlate", "model": "Rogue", "wkind": "epee", "tier": 4},
			{"id": "d_morg", "name": "Morg le Champion", "model": "Barbarian", "wkind": "hache", "tier": 5},
			{"id": "d_nyx", "name": "Nyx la Cendrée", "model": "Mage", "wkind": "baton", "tier": 5},
		],
		"hidden": [Vector2(-100, 96), Vector2(100, -62), Vector2(96, 96)],
		"gates": [{"pos": Vector2(0, 104), "to": 3, "dir": "SUD", "arrive": Vector2(10, -96)}],
	}
