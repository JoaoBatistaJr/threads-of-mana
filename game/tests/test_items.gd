extends SceneTree
func _init():
	var reg = ItemRegistry
	ItemRegistry._ensure()
	var all: Array = reg.all_items()
	print("itens carregados: ", all.size())
	var wood: ItemData; var sword: ItemData
	for i in all:
		if i.get_stack_limit() > 1 and wood == null: wood = i
		if i.get_stack_limit() == 1 and sword == null: sword = i
	print("pilha: ", wood.id, " único: ", sword.id)
	var s := ItemService.new()
	s.set_capacity("player:1", 6); s.set_capacity("player:2", 6); s.set_capacity("loot:1", 20)
	var r := s.mint(wood, 250, "loot:1", "teste")
	print("mint 250: ", r.added, " left ", r.left, " pilhas ", s.owned_by("loot:1").size())
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var minted := 250; var destroyed := 0
	var owners := ["player:1", "player:2", "loot:1"]
	for k in 20000:
		var op := rng.randi() % 5
		var a: String = owners[rng.randi() % 3]; var b: String = owners[rng.randi() % 3]
		match op:
			0:
				var q := rng.randi_range(1, 120)
				var m := s.mint(wood, q, a, "t"); minted += m.added
			1:
				var m := s.mint(sword, 1, a, "t"); minted += m.added
			2, 3:
				var ol := s.owned_by(a)
				if ol.size() > 0:
					var e: Dictionary = ol[rng.randi() % ol.size()]
					s.move(e.uid, a, b, "t", rng.randi_range(0, e.amount))
			4:
				var c := s.count_of(a, wood.id)
				var q2 := rng.randi_range(1, 40)
				if s.consume(a, wood.id, q2, "t"): destroyed += q2
	var errs := s.check()
	var tw := s.total_of(wood.id) + s.total_of(sword.id)
	print("erros integridade: ", errs.size(), " ", errs.slice(0,3))
	print("conservação: criado-destruído=", minted - destroyed, " existente=", tw)
	# dupe: mover de dono errado / uid inexistente
	var any: Dictionary = s.owned_by("loot:1")[0] if s.owned_by("loot:1").size() > 0 else {}
	if not any.is_empty():
		print("mover com dono errado: ", s.move(any.uid, "player:1", "player:2", "x"))
	print("mover uid falso: ", s.move("abc", "loot:1", "player:1", "x"))
	print("log: ", s.history.size())
	quit()
