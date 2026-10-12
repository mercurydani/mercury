class_name ForestProp
extends Node3D
## Один экземпляр лесного вида (дуб-герой, бревно, камень): меш строится при загрузке из ForestSpecies.

@export var species: String = "oak"


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ForestSpecies.get_mesh(species)
	mi.name = "Mesh"
	add_child(mi)
