class_name CutawayScenes
extends RefCounted
## The registry of cutaway scene recipes: scene id -> script. A CutawayDefinition names a recipe by id and ContentDb
## checks that it exists. Adding a clip = one recipe script here plus one CutawayDefinition resource.

const RECIPES: Dictionary = {
	"title_card": preload("res://scripts/cutaways/scenes/title_card_scene.gd"),
	"artillery_barrage": preload("res://scripts/cutaways/scenes/artillery_barrage_scene.gd"),
	"naval_gunfire": preload("res://scripts/cutaways/scenes/naval_gunfire_scene.gd"),
	"close_air_support": preload("res://scripts/cutaways/scenes/close_air_support_scene.gd"),
	"missile_strike": preload("res://scripts/cutaways/scenes/missile_strike_scene.gd"),
}


static func has(scene_id: String) -> bool:
	return RECIPES.has(scene_id)


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k in RECIPES:
		out.append(k)
	out.sort()
	return out


## A fresh recipe instance for `scene_id`, or null if there is none.
static func build(scene_id: String) -> CutawayScene:
	var script: GDScript = RECIPES.get(scene_id)
	return script.new() as CutawayScene if script != null else null
