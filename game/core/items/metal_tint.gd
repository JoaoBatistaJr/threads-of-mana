## Pinta metal conforme o material do item (pelo id: bronze, ferro, aço, prata, ouro).
## Armas/ferramentas: só materiais sem textura com nome de metal (pack rpg_items).
## Roupas/armaduras (gear): peças de metal pelo nome da malha; se nenhuma casar, um tom leve em tudo.
class_name MetalTint
extends RefCounted

## Palavra (um trecho do id entre "_") → material.
const ID_KEYWORDS: Dictionary = {
	"bronze": "bronze",
	"ferro": "iron",
	"iron": "iron",
	"aco": "steel",
	"aço": "steel",
	"steel": "steel",
	"prata": "silver",
	"silver": "silver",
	"ouro": "gold",
	"gold": "gold",
}

const PALETTE: Dictionary = {
	"bronze": {"color": Color(0.80, 0.48, 0.20), "metallic": 0.75, "roughness": 0.45},
	"iron": {"color": Color(0.42, 0.44, 0.48), "metallic": 0.85, "roughness": 0.5},
	"steel": {"color": Color(0.68, 0.72, 0.78), "metallic": 0.9, "roughness": 0.35},
	"silver": {"color": Color(0.93, 0.95, 1.0), "metallic": 1.0, "roughness": 0.2},
	"gold": {"color": Color(1.0, 0.78, 0.25), "metallic": 1.0, "roughness": 0.3},
}

const METAL_SHADES: Dictionary = {
	"Steel": 1.0,
	"LightSteel": 1.2,
	"DarkSteel": 0.65,
	"Golden": 1.0,
	"LightGold": 1.2,
}

## Trechos de nome de malha vestível tratados como metal.
const GEAR_METAL_PARTS: Array = ["pauldron", "plate", "armor", "armour", "helm", "greave", "bracer", "buckle", "metal", "shoulder"]
## Força da pintura nas partes de metal / no resto quando nenhuma parte casa (0..1).
const GEAR_METAL_STRENGTH: float = 0.75
const GEAR_FALLBACK_STRENGTH: float = 0.3

static var _cache: Dictionary = {}


## Material do item pelo id ("" = sem pintura).
static func kind_for(item: Resource) -> String:
	if item == null:
		return ""
	for token in str(item.get("id")).to_lower().split("_"):
		if ID_KEYWORDS.has(token):
			return ID_KEYWORDS[token]
	return ""


static func apply(root: Node, item: Resource) -> void:
	var kind: String = kind_for(item)
	if root == null or kind == "":
		return
	if str(item.get("category")) == "gear":
		_apply_gear(root, kind)
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture != null or not METAL_SHADES.has(mat.resource_name):
				continue
			mi.set_surface_override_material(s, _tinted(mat, kind))


static func _apply_gear(root: Node, kind: String) -> void:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	var metal: Array = []
	for node in meshes:
		var lower: String = String(node.name).to_lower()
		for k in GEAR_METAL_PARTS:
			if lower.contains(k):
				metal.append(node)
				break
	var targets: Array = metal if not metal.is_empty() else meshes
	var strength: float = GEAR_METAL_STRENGTH if not metal.is_empty() else GEAR_FALLBACK_STRENGTH
	var color: Color = PALETTE[kind].color
	var mix := Color.WHITE.lerp(color, strength)
	for node in targets:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var out := mat.duplicate() as BaseMaterial3D
			out.albedo_color = mat.albedo_color * mix
			if not metal.is_empty():
				out.metallic = maxf(out.metallic, float(PALETTE[kind].metallic) * 0.5)
			mi.set_surface_override_material(s, out)


static func _tinted(mat: BaseMaterial3D, kind: String) -> BaseMaterial3D:
	var key: String = "%s|%s" % [mat.get_instance_id(), kind]
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key]
	var p: Dictionary = PALETTE[kind]
	var shade: float = float(METAL_SHADES[mat.resource_name])
	var out := mat.duplicate() as BaseMaterial3D
	var c: Color = p.color
	out.albedo_color = Color(clampf(c.r * shade, 0.0, 1.0), clampf(c.g * shade, 0.0, 1.0), clampf(c.b * shade, 0.0, 1.0))
	out.metallic = float(p.metallic)
	out.roughness = float(p.roughness)
	_cache[key] = out
	return out
