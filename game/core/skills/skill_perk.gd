## Bônus/habilidade que uma skill concede ao atingir um nível (Resource).
## Guardar em res://resources/skills/<skill>/. Dados placeholder: o efeito real
## é lido por [method SkillSystem.get_modifier] e, no futuro, por habilidades ativas.
extends Resource
class_name SkillPerk

@export var skill: String = ""
@export var level: int = 1
## passive = bônus permanente; active = habilidade ativa (futuro); unlock = libera recurso/receita.
@export_enum("passive", "active", "unlock") var kind: String = "passive"
## Título/descrição opcionais (chaves de tradução). Vazio = gerado a partir de [member modifiers].
@export var name_key: String = ""
@export var description_key: String = ""
## Ex.: {"yield_mult": 0.05, "quality_bonus": 2}. Chaves terminadas em _mult/_chance são porcentagens.
@export var modifiers: Dictionary = {}
## Futuro: id da habilidade ativa concedida (kind = active).
@export var ability_id: String = ""
@export var icon: Texture2D


## Título para exibir.
func get_title() -> String:
	if name_key != "":
		return tr(name_key)
	var parts: PackedStringArray = []
	for key in modifiers:
		var v: float = float(modifiers[key])
		var label: String = tr("perk_mod_" + str(key))
		if str(key).ends_with("_mult") or str(key).ends_with("_chance"):
			parts.append("+%s%% %s" % [_num(v * 100.0), label])
		else:
			parts.append("+%s %s" % [_num(v), label])
	return ", ".join(parts) if not parts.is_empty() else tr("ui_skill_no_perks")


## Descrição opcional (vazia se não definida).
func get_description() -> String:
	return tr(description_key) if description_key != "" else ""


func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
