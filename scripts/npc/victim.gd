class_name Victim
extends Node3D
## Civil qu'on peut blesser (marchand de caravane) : les pillards le prennent pour cible pendant une embuscade.

signal killed
var cbt: Combatant
var hp := 70.0

func _ready() -> void:
	cbt = Combatant.new()
	cbt.team = "joueur"
	cbt.display_name = "Marchand"
	cbt.max_hp = hp
	cbt.hp = hp
	add_child(cbt)
	cbt.died.connect(func(_s):
		Combat.remove_ally(self)
		killed.emit())

## Pendant l'embuscade seulement : les bandits le voient comme une proie
func exposed(v: bool) -> void:
	if v and not cbt.dead:
		Combat.add_ally(self)
	else:
		Combat.remove_ally(self)

func _exit_tree() -> void:
	Combat.remove_ally(self)
