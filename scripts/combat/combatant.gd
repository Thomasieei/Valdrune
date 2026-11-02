class_name Combatant
extends Node
## Composant de combat commun au joueur et aux créatures : vie, bouclier, ralentissement, immobilisation.

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var team := "monstre"
var max_hp := 50.0
var hp := 50.0
var defense := 0.0
var dead := false
var invulnerable_until := 0.0
var shield := 0.0
var shield_until := 0.0
var slow_factor := 1.0
var slow_until := 0.0
var rooted_until := 0.0
var display_name := ""
var elem := {}                 # multiplicateurs élémentaires reçus (faiblesses > 1, résistances < 1)
var reflect_until := 0.0       # Reflet du souverain : dégâts réduits et renvoyés
var reflect_ratio := 1.0
var incoming_mult := 1.0       # Incarnation souveraine : dégâts subis réduits
var incoming_until := 0.0

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func body() -> Node3D:
	return get_parent() as Node3D

func speed_mult() -> float:
	var t := now()
	if t < rooted_until:
		return 0.0
	if t < slow_until:
		return slow_factor
	return 1.0

func is_rooted() -> bool:
	return now() < rooted_until

var hp_floor := 0.0   # duel d'honneur : on ne descend pas sous ce seuil (le vaincu se rend)

func take_damage(amount: float, source: Node = null, kind := "physique") -> float:
	if dead or now() < invulnerable_until:
		return 0.0
	var dmg := maxf(1.0, amount - defense) if kind == "physique" else amount
	if elem.has(kind):
		dmg *= float(elem[kind])
	if now() < incoming_until:
		dmg *= incoming_mult
	if now() < reflect_until:
		var back := dmg * reflect_ratio
		dmg *= 0.3
		if source and is_instance_valid(source) and "cbt" in source and source.cbt != self and source.cbt.team != team:
			source.cbt.take_damage(back, body(), "arcane")
			FX.hit_spark(body().global_position + Vector3.UP * 1.2, Color(0.7, 0.95, 1.0))
	dmg = roundf(dmg * randf_range(0.9, 1.1))
	if shield > 0.0 and now() < shield_until:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
		if absorbed > 0:
			FX.damage_number(body().global_position + Vector3.UP * 2.0, "-%d" % absorbed, Color(0.55, 0.85, 1.0))
	if dmg <= 0.0:
		return 0.0
	hp = maxf(hp - dmg, hp_floor)
	var col := Color(1.0, 0.35, 0.3) if team == "joueur" else (Color(1.0, 0.85, 0.3) if kind == "physique" else Color(1.0, 0.6, 0.25))
	FX.damage_number(body().global_position + Vector3.UP * 2.0, str(int(dmg)), col)
	damaged.emit(dmg, source)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit(source)
	return dmg

func heal(n: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + n)

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_until = now() + duration

func apply_root(duration: float) -> void:
	rooted_until = now() + duration

func give_shield(amount: float, duration: float) -> void:
	shield = amount
	shield_until = now() + duration

func has_shield() -> bool:
	return shield > 0.0 and now() < shield_until
