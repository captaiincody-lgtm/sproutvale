extends RefCounted
## Slimes, rats, ferrets, boars and tortoises: spawning, AI, taking hits and dropping loot.
## A port of the prototype's spawnSlime / updateSlimes / damageSlime / killSlime.

const S := preload("res://scripts/state.gd")

var G
var P: S.Player


func _init(game) -> void:
	G = game
	P = game.P


func box(e: S.Mob) -> Dictionary:
	return G.hbox(e.x - e.w / 2, e.x + e.w / 2, e.y - e.h, e.y)


func spawn(_initial: bool) -> void:
	var M: Dictionary = G.M
	if M.spawn.is_empty():   # safe maps have nothing to spawn
		return
	var pool = []
	for k in M.spawn:
		if M.get("ignoreUnlock", false) or G.D.mobs[k].unlock <= G.CH().level:
			pool.append([k, M.spawn[k]])
	if pool.is_empty():
		return
	var tot = 0.0
	for p in pool:
		tot += p[1]
	var r = randf() * tot
	var type: String = pool[0][0]
	for p in pool:
		r -= p[1]
		if r <= 0:
			type = p[0]
			break
	var T: Dictionary = G.D.mobs[type]
	var dry: Array = G.surfaces.filter(func(q): return not q.water)
	var s: Dictionary
	var x = 0.0
	var guard = 0
	while true:
		var wt = 0.0
		for q in dry:
			wt += q.x1 - q.x0
		var pick = randf() * wt
		s = dry[0]
		for q in dry:
			pick -= q.x1 - q.x0
			if pick <= 0:
				s = q
				break
		x = randf_range(s.x0 + 14, s.x1 - 14)
		guard += 1
		if not (absf(x - P.x) < 110 and absf(s.y - P.y) < 60 and guard < 20):
			break
	var e = S.Mob.new()
	G.mob_uid += 1
	e.id = G.mob_uid; e.type = type; e.T = T; e.lv = int(T.lv); e.x = x; e.y = s.y; e.surf = s
	e.face = -1 if randf() < 0.5 else 1; e.t = randf_range(0, 2)
	e.hp = T.hp; e.max_hp = T.hp; e.atk = T.atk; e.def = T.def; e.exp_val = T.exp
	e.hop_cd = randf_range(0.5, 2); e.atk_cd = 1
	var critter: bool = T.get("critter", false)
	e.w = (16.0 if type == "rat" else 22.0) if critter else 18.0 * T.size
	e.h = 10.0 if critter else 16.0 * T.size
	if randf() < 0.03:   # shiny: rarer, tougher, five times the rewards
		e.shiny = true; e.hp = e.hp * 3; e.max_hp = e.hp; e.atk *= 3; e.def *= 1.5
	G.mobs.append(e)


func update(dt: float) -> void:
	var pb: Dictionary = G.player.box()
	for i in range(G.mobs.size() - 1, -1, -1):
		var e: S.Mob = G.mobs[i]
		var T = e.T
		e.t += dt; e.flash -= dt; e.bang -= dt; e.atk_cd -= dt; e.hop_cd -= dt; e.show_bar -= dt
		if e.spawn_t > 0:
			e.spawn_t -= dt
		if e.state == "dead":
			e.dead_t += dt
			if e.dead_t > 0.45:
				G.mobs.remove_at(i)
			continue
		var dx = P.x - e.x
		var dy = P.y - e.y
		var near: bool = absf(dx) < 120 and absf(dy) < 54 and P.state != "dead" and G.mode == "play"
		var grounded = e.y >= e.surf.y - 0.01 and e.vy >= 0
		var critter: bool = T.get("critter", false)
		if critter and e.state in ["idle", "chase", "retreat"]:
			if e.state == "idle":
				if near and e.spawn_t <= 0:
					e.aggro = true; e.bang = 0.8; e.state = "chase"
					if absf(dx) < 90:
						Sfx.play("aggro_critter")
				else:
					if e.hop_cd <= 0:
						e.hop_cd = randf_range(0.8, 2.4); e.pause = randf() < 0.35
						if randf() < 0.4:
							e.face *= -1
					e.walk = 0.0 if e.pause else e.face * 26 * T.speed
			elif e.state == "chase":
				if not near and absf(dx) > 190:
					e.state = "idle"; e.aggro = false
				e.face = int(signf(dx)) if dx != 0 else e.face
				e.walk = e.face * 62 * T.speed if absf(dx) > 20 else 0.0
				var reach = 120.0 if e.type == "boar" else (70.0 if e.type == "tortoise" else 40.0)
				if grounded and absf(dx) < reach and absf(dy) < 22 and e.atk_cd <= 0:
					e.state = "wind"; e.t = 0; e.walk = 0; e.vx = 0
			elif e.state == "retreat":
				e.walk = -e.face * 95.0
				if e.t > 0.35:
					e.state = "chase"; e.t = 0
		else:
			match e.state:
				"idle":
					if near and e.spawn_t <= 0:
						e.aggro = true; e.bang = 0.8; e.state = "flee" if T.get("flees", false) else "chase"
						if absf(dx) < 90:
							Sfx.play("bang")
					elif grounded and e.hop_cd <= 0:
						if randf() < 0.35:
							e.face *= -1
						e.vy = -110; e.vx = e.face * 38 * T.speed; e.hop_cd = randf_range(0.8, 2.2); e.sq = -0.3
				"chase":
					if not near and absf(dx) > 190:
						e.state = "idle"; e.aggro = false
					else:
						e.face = int(signf(dx)) if dx != 0 else e.face
						if grounded and absf(dx) < 42 and absf(dy) < 26 and e.atk_cd <= 0:
							e.state = "wind"; e.t = 0; e.vx = 0
						elif grounded and e.hop_cd <= 0 and absf(dx) > 16:
							e.vy = -150; e.vx = e.face * 70 * T.speed; e.hop_cd = randf_range(0.25, 0.5); e.sq = -0.3
				"flee":
					e.face = -int(signf(dx)) if dx != 0 else 1
					if not near and absf(dx) > 200:
						e.state = "idle"; e.aggro = false
					if grounded and e.hop_cd <= 0:
						e.vy = -170; e.vx = e.face * 110 * T.speed; e.hop_cd = randf_range(0.1, 0.3)
				"wind":
					if e.type == "boar" and e.t > 0.45:
						e.state = "charge"; e.t = 0; e.hit_done = false; Sfx.play("charge")
					elif e.type == "tortoise" and e.t > 0.5:
						e.state = "spin"; e.t = 0; e.hit_t = 0; Sfx.play("spin_start")
					else:
						if e.type == "boar" and randf() < dt * 20:
							G.parts.append(S.Part.new(e.x - e.face * 10, e.y - 1, -e.face * randf_range(20, 50), randf_range(-30, -10), 0.3, Color("#d8c8a8"), 0, 2))
						var wait = (9.0 if e.type in ["boar", "tortoise"] else 0.3) if critter else 0.45
						if e.t > wait:
							e.state = "lunge"; e.t = 0
							e.vx = e.face * (240.0 if critter else 190.0 * minf(1.3, T.speed))
							e.vy = -110.0 if critter else -190.0
							e.hit_done = false
							Sfx.play("lunge_critter" if critter else "lunge")
				"charge":
					e.vx = e.face * 320.0
					if randf() < dt * 30:
						G.parts.append(S.Part.new(e.x - e.face * 12, e.y - 1, -e.face * 40, -10, 0.3, Color("#d8c8a8"), 0, 2))
					if not e.hit_done and G.overlap(box(e), pb):
						e.hit_done = true; G.player.hurt(e, e.atk * 1.2)
					if e.t > 0.75 or e.x <= e.surf.x0 + e.w / 2 + 1 or e.x >= e.surf.x1 - e.w / 2 - 1:
						e.state = "recover"; e.t = 0; e.vx *= 0.3
				"spin":
					e.vx = e.face * 200.0
					if e.x <= e.surf.x0 + e.w / 2 + 1:
						e.face = 1
					if e.x >= e.surf.x1 - e.w / 2 - 1:
						e.face = -1
					e.hit_t -= dt
					if e.hit_t <= 0 and G.overlap(box(e), pb):
						e.hit_t = 0.5; G.player.hurt(e, e.atk)
					if e.t > 1.2:
						e.state = "recover"; e.t = 0
				"shell":
					e.vx *= exp(-dt * 6)
					if e.t > 1.3:
						e.state = "chase"; e.t = 0
				"lunge":
					if not e.hit_done and G.overlap(box(e), pb):
						e.hit_done = true; G.player.hurt(e, e.atk)
					if P.state == "dash" and not P.dodged.has(e) and absf(dx) < 34 and absf(dy) < 30:
						P.dodged[e] = true; G.player.perfect_dodge()
					if grounded and e.t > 0.15:
						e.state = "recover"; e.t = 0
				"recover":
					if e.t > (0.25 if critter else 0.6):
						e.state = "flee" if T.get("flees", false) else ("retreat" if e.type == "ferret" else "chase")
						e.t = 0
						e.atk_cd = randf_range(0.9 if critter else 1.2, 1.7 if critter else 2.4)
				"hurt":
					e.stun -= dt
					if e.stun <= 0 and grounded:
						e.state = "flee" if T.get("flees", false) else "chase"
						e.aggro = true; e.hop_cd = 0.3; e.atk_cd = maxf(e.atk_cd, 0.6)
		# touch damage from awake monsters (classic side-scroller rule)
		if e.aggro and e.state != "hurt" and e.state != "lunge" and G.overlap(box(e), pb) and P.touch_cd <= 0:
			P.touch_cd = 0.9
			G.player.hurt(e, roundf(e.atk * 0.6))
		# physics on its own surface
		var juggled = e.state == "hurt" and e.juggle > 0
		if e.juggle > 0:
			e.juggle -= dt
		e.vy = minf(G.MAXFALL, e.vy + G.GRAV * (0.5 if juggled else 0.75) * dt)
		e.x += e.vx * dt
		e.y += e.vy * dt
		if e.y >= e.surf.y:
			if e.vy > 120 and e.state == "hurt":
				e.vy *= -0.3; e.sq = 0.4
			else:
				if e.vy > 60:
					e.sq = 0.35
				e.vy = 0
			e.y = e.surf.y
			e.vx *= exp(-dt * (5.0 if e.state == "hurt" else 14.0))
		if critter and e.y >= e.surf.y - 0.01 and e.state in ["idle", "chase", "retreat"]:
			e.vx = G.damp(e.vx, e.walk, 12, dt)
		var lo = e.surf.x0 + e.w / 2
		var hi = e.surf.x1 - e.w / 2
		if e.x < lo:
			e.x = lo; e.vx = absf(e.vx) * 0.3
			if e.state == "idle":
				e.face = 1
		if e.x > hi:
			e.x = hi; e.vx = -absf(e.vx) * 0.3
			if e.state == "idle":
				e.face = -1
		e.sq += (0 - e.sq) * minf(1, dt * 10)
	if G.mode == "play" and G.M.target > 0:
		G.spawn_timer -= dt
		var alive = G.mobs.filter(func(m): return m.state != "dead").size()
		if alive < G.M.target and G.spawn_timer <= 0:
			spawn(false)
			G.spawn_timer = 2.2


func damage(e: S.Mob, mv: Dictionary) -> void:
	if e.state == "dead":
		return
	var PS: Dictionary = G.PS
	var crit = randf() * 100 < PS.crit
	var dmg: float = PS.atk * mv.dmg * randf_range(0.9, 1.1) * 100 / (100 + e.def * 4)
	if crit:
		dmg *= PS.critDmg
	if e.state == "shell" or (e.state == "spin" and e.type == "tortoise"):
		dmg *= 0.3
		Sfx.play("shell_clink")
	dmg = maxf(1, roundf(dmg))
	e.hp -= dmg; e.flash = 0.1; e.show_bar = 3; e.aggro = true
	G.float_text(e.x, e.y - e.h - 6, str(int(dmg)), "crit" if crit else "dmg")
	var dir = P.face
	if mv.get("both", false):
		dir = int(signf(e.x - P.x)) if e.x != P.x else P.face
	var heavy = 0.6 if e.T.get("metal", false) else 1.0
	G.sparks(e.x - dir * 4, e.y - e.h * 0.6, Color("#ffe14d") if crit else Color.WHITE, 10 if crit else 6)
	G.goo(e.x, e.y - e.h * 0.5, mob_color(e), 3)
	G.hitstop = maxf(G.hitstop, 0.09 if mv.get("heavy", false) else 0.045)
	G.shake = maxf(G.shake, 5.0 if mv.get("heavy", false) else (3.0 if crit else 1.5))
	Sfx.play("hit_crit" if crit else "hit")
	G.style_add(mv.style * (1.3 if crit else 1.0), mv.anim)
	G.combo_hit()
	if e.hp <= 0:
		kill(e)
		return
	if e.type == "tortoise" and e.state != "shell" and e.state != "spin" and randf() < 0.4:
		e.state = "shell"; e.t = 0; e.vx = P.face * 60
		return
	e.state = "hurt"
	e.stun = 0.7 if mv.get("heavy", false) else 0.45
	e.sq = 0.3
	e.vx = dir * mv.kb * heavy
	var airborne = e.y < e.surf.y - 2
	var up: float = mv.get("up", 0)
	if mv.get("air", false) or (airborne and not up):
		e.vy = up if up else -150.0
		e.juggle = 0.5; e.stun = 0.8
	elif up:
		e.vy = up * heavy
		if up < -250:
			e.juggle = 0.7; e.stun = 1.1


func mob_color(e: S.Mob) -> Color:
	return Color.hex((int(e.T.color) << 8) | 0xff)


func exp_scale(mob_lv: int) -> float:
	var d = mob_lv - int(G.CH().level)
	if d <= -3: return 0.5
	if d == -2: return 0.75
	if d == -1: return 0.9
	if d == 0: return 1.0
	if d == 1: return 1.1
	if d == 2: return 1.25
	if d == 3: return 1.5
	if d == 4: return 1.75
	if d < 10: return 2 + (d - 5) / 5.0
	if d < 20: return 3 + (d - 10) / 10.0 * 2
	return 5.0


func kill(e: S.Mob) -> void:
	e.state = "dead"; e.dead_t = 0; e.hp = 0
	if e.T.get("critter", false):
		Sfx.play("critter_die")
	else:
		Sfx.play("squish")
	G.goo(e.x, e.y - 6, mob_color(e), 16)
	var coins: Array = e.T.coins
	var total = roundi(randi_range(int(coins[0]), int(coins[1])) * (5 if e.shiny else 1))
	var pieces = clampi(int(ceil(total / 5.0)), 3, 18 if (e.type == "gold" or e.shiny) else 8)
	for i in pieces:
		if total <= 0:
			break
		var v = total if i == pieces - 1 else maxi(1, total / (pieces - i))
		total -= v
		var d = S.Drop.new()
		d.kind = "coin"; d.x = e.x; d.y = e.y - 8; d.vx = randf_range(-70, 70); d.vy = randf_range(-260, -160); d.val = v
		d.surf_y = e.surf.y; d.x0 = e.surf.x0 + 4; d.x1 = e.surf.x1 - 4; d.spin = randf() * 4
		G.drops.append(d)
	var n_res = (2 if randf() < 0.25 or e.T.get("metal", false) else 1) * (5 if e.shiny else 1)
	for i in n_res:
		var d = S.Drop.new()
		d.kind = "res"; d.type = e.type; d.x = e.x; d.y = e.y - 8; d.vx = randf_range(-50, 50); d.vy = randf_range(-220, -150)
		d.surf_y = e.surf.y; d.x0 = e.surf.x0 + 4; d.x1 = e.surf.x1 - 4
		G.drops.append(d)
	var xm = exp_scale(e.lv)
	var gained = roundi(maxf(1, roundf(e.exp_val * xm)) * (5 if e.shiny else 1))
	if e.shiny:
		G.player.P.cheer_q = true
		G.banner("Shiny defeated!", "%s · 5× rewards" % e.T.name)
		var cols = [Color.WHITE, Color("#fff6b0"), Color("#ff9ecf"), Color("#9fe6ff")]
		for i in 24:
			G.parts.append(S.Part.new(e.x, e.y - 10, randf_range(-120, 120), randf_range(-220, -60), randf_range(0.5, 1), cols[i % 4], 300, 2))
	G.gain_exp(gained)
	var mult = "" if xm == 1 else (" ×" + String.num(xm, 2).rstrip("0").rstrip("."))
	G.float_text(e.x, e.y - e.h - 16, "+%d EXP%s" % [gained, mult], "exp")
	G.CH().kills += 1
	G.style_add(40 if e.T.get("metal", false) else 16, "kill")
	G.save_dirty = true
