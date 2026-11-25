## Moeda do jogo: o item "coin". Funções estáticas sobre o [ItemService] (servidor).
class_name Currency

const COIN_ID: String = "coin"
const COIN_PATH: String = "res://resources/items/materials/moeda.tres"

static var _coin: ItemData


static func coin_item() -> ItemData:
	if _coin == null:
		_coin = load(COIN_PATH) as ItemData
		if _coin == null:
			push_error("Currency: item de moeda não encontrado em %s" % COIN_PATH)
	return _coin


static func balance(svc: ItemService, owner: String) -> int:
	return svc.count_of(owner, COIN_ID)


static func can_afford(svc: ItemService, owner: String, amount: int) -> bool:
	return balance(svc, owner) >= amount


## Cobra [param amount] moedas. Retorna false se o saldo não bastar.
static func pay(svc: ItemService, owner: String, amount: int, why: String) -> bool:
	if amount <= 0:
		return true
	return svc.consume(owner, COIN_ID, amount, why)


## Entrega [param amount] moedas. Retorna a quantidade que não coube.
static func give(svc: ItemService, owner: String, amount: int, why: String) -> int:
	var coin: ItemData = coin_item()
	if coin == null or amount <= 0:
		return amount
	return int(svc.mint(coin, amount, owner, why).left)
