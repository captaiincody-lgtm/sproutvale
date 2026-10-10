extends "res://scripts/tree_ui.gd"
## Sproutvale, the Lunar Shop: a shop that sells nothing. Luna Coins go into it, a meter fills, and at a
## thousand something answers (lunar.gd). Also the Luna Coin's little icon and the ↑ hints for talking
## to people and boarding the rocket.


func _coin(p: Vector2, r: float, kind := "coin") -> void:
	if kind != "luna":
		super._coin(p, r, kind)
		return
	uci.draw_circle(p, r, css("#06304a"))
	uci.draw_circle(p, r - 1.5, css("#64ecff"))
	uci.draw_circle(p + Vector2(r * 0.25, -r * 0.1), r * 0.5, css("#1a8ab0"))   # a crescent
	uci.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.28, css("#e2ffff"))


func lunarCard(x: float, y: float, w: float) -> float:
	var L = LU()
	return uCards(x, y, w, 1, [func(X, Y, W):
		var yy = Y
		uText("Lunar Shop", X, yy, 11, css("#d8f8ff"))
		var pw = uW(fmt(lunaCoins()), 8) + 22
		uBox(Rect2(X + W - pw, yy, pw, 14), css("#06203a"), NONE, 0, 7)
		_coin(Vector2(X + W - pw + 8, yy + 7), 4, "luna")
		uText(fmt(lunaCoins()), X + W - pw + 15, yy + 2, 8, css("#bff8ff"))
		yy += 20
		yy += muted("Nothing here is for sale. There is only a cold silver basin under an open skylight, and a meter beside it that hums when Luna Coins go in. Lunar monsters drop them: about one monster in a thousand is born under the moon.", X, yy, W, css("#9fc8e0")) + 8
		# the meter
		var frac = float(L.meter) / LUNAR_GOAL
		var r = Rect2(X, yy, W, 22)
		uGlow(r, Color(0.5, 0.9, 1.0, 0.25 + 0.15 * sin(realTime * 2) * frac), 6 + frac * 6, 8)
		uBox(r, css("#020c18"), css("#7fe6ff"), 2, 8)
		var inner = r.grow(-3)
		if frac > 0:
			uGrad(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y)), css("#bff8ff"), css("#48c8f0"), css("#1a5a90"))
		uText("LUNAR METER", X + 8, yy + 8, 6, Color(1, 1, 1, 0.85), PX)
		uText("%s / %s" % [fmt(L.meter), fmt(LUNAR_GOAL)], X + W - 8, yy + 5, 10, Color.WHITE, UB, 2, css("#020c18"))
		yy += 32
		if int(L.meter) < LUNAR_GOAL:
			var bx = X
			for q in [["Donate 1", 1], ["Donate 10", 10], ["Donate 100", 100], ["Donate all", LUNAR_GOAL]]:
				var n: int = q[1]
				var bw = uW(q[0], 9) + 18
				uButton(Rect2(bx, yy, bw, 20), q[0], func(): donateLuna(n), {"disabled": lunaCoins() <= 0, "bg": css("#7fe6ff"), "shadow": 0.0})
				bx += bw + 6
			yy += 28
			yy += muted("Donated coins are gone for good. The meter is shared by every hero.", X, yy, W, css("#7fa8c0"))
		elif lunarNight():
			yy += muted("The meter is dark now. Whatever was listening has answered. Go outside and look up.", X, yy, W, css("#ff9aa8"))
		elif finaleBeaten():
			yy += muted("The meter is full, and something is still waiting for an answer.", X, yy, W, css("#bff8ff")) + 4
			uButton(Rect2(X, yy, 120, 20), "Answer the call", func(): toggleMenu(false); later(0.4, func(): startLunarRite()), {"bg": css("#7fe6ff"), "shadow": 0.0})
			yy += 26
		else:
			yy += muted("The meter is full. Something answered, but it won't say more until you've beaten the game.", X, yy, W, css("#bff8ff"))
		return yy - Y], [{"fill": css("#0c1a2e"), "border": css("#06203a")}])


func hintText() -> String:
	if scene == null and finaleBeaten():
		var n = npcAt()
		if n != null:
			return "Press ↑ · Talk to " + npcName(n)
		if rocketAt():
			return "Press ↑ · Fly home" if mapId == "moon1" else "Press ↑ · Board the rocket"
	if mapId == "moon1" and not P.grounded:
		return "Moon gravity · you fall slowly"
	return super.hintText()
