extends RefCounted
## Rock's controls, moves and physics — a line-by-line port of the prototype's updatePlayer().
##   ← →  move (double-tap to run)    Space  jump / double jump    ↑  rope, door, portal
##   Z  attack (chain it)   X  heavy (in the air: Meteor Drop)   C  dodge   Shift  block/parry
##   ↓  slide out of a run, otherwise lie prone   H / J  potions

const S := preload("res://scripts/state.gd")
const CHAIN := ["slash", "rising", "thrust", "spin"]
const AIR_CHAIN := ["air", "air2", "air3"]
const AIR_LIFT_MAX := 9
const POT_MAX := 3
const POT_RECHARGE := 25.0
const WHOOSH := {"slash": 1.0, "rising": 1.2, "thrust": 1.35, "spin": 0.9, "whirl": 0.85, "aegis": 0.8, "air": 1.1, "air2": 1.25, "air3": 1.0}

var G   # the game node
var P: S.Player
var moves: Dictionary


func _init(game) -> void:
	G = game
	P = game.P
	moves = game.D.moves
	moves.stab = {"anim": "proneStab", "hits": [1], "box": [4, 56, -14, 2], "dmg": 0.9, "kb": 60, "up": -170, "style": 14, "lunge": 0, "cancel": 2, "prone": true}


func anim_info(a: String) -> Dictionary:
	return Assets.hero.anims.get(a, Assets.hero.anims.idle)


func frame_of(a: String, t: float, loop: bool) -> int:
	var A = anim_info(a)
	var n = int(A.frames)
	var f = int(floor(t * A.fps))
	return f % n if loop else mini(f, n - 1)


func set_anim(a: String) -> void:
	if P.anim != a:
		P.anim = a
		P.anim_t = 0.0


func is_low() -> bool:
	return P.state == "prone" or P.state == "slide" or (P.state == "attack" and P.move != null and P.move.get("prone", false))


func box() -> Dictionary:
	if is_low():
		return G.hbox(P.x - 12, P.x + 12, P.y - 13, P.y)
	return G.hbox(P.x - 7, P.x + 7, P.y - 40, P.y)


func on_surface():
	for s in G.surfaces:
		if P.x >= s.x0 - 2 and P.x <= s.x1 + 2 and absf(P.y - s.y) < 1:
			return s
	return null


func start_move(id: String) -> void:
	var mv: Dictionary = moves[id]
	P.state = "attack"; P.move = mv; P.move_id = id; P.move_t = 0.0; P.last_frame = -1
	P.hit_set.clear(); P.queued = false; P.queued_heavy = false
	set_anim(mv.anim)
	if mv.get("heavy", false):
		Sfx.play("whoosh_heavy", 1.0, 1.0)
	else:
		Sfx.play("whoosh", 1.0, WHOOSH.get(id, 1.0))
	if not mv.get("air", false):
		P.vx = P.face * mv.get("lunge", 0)


func start_climb(r: Dictionary, from_top: bool) -> void:
	P.state = "climb"; P.rope = r; P.x = r.x; P.vx = 0; P.vy = 0; P.grounded = false; P.surf = null; P.jumps = 0
	if from_top:
		P.y += 4
	set_anim("climb")
	Sfx.play("rope")


func climb_off(dir: int) -> void:
	P.last_jump_t = G.game_time; P.state = "move"; P.rope = null; P.vy = -240; P.vx = dir * 120; P.face = dir; P.jumps = 1
	Sfx.play("jump")


func air_lift() -> bool:
	P.air_atk += 1
	return P.air_atk <= AIR_LIFT_MAX


func start_plunge() -> void:
	P.plunge_hits = 0; P.state = "plunge"; P.plunge_phase = "start"; P.plunge_t = 0.0; P.plunge_y0 = P.y
	P.hit_set.clear(); set_anim("plungeStart"); P.vx *= 0.3; P.vy = -90
	Sfx.play("plunge_start")


func plunge_impact() -> void:
	var fall = maxf(0, P.y - P.plunge_y0)
	var R = 34 + fall * 0.14
	var mult = 1.3 + fall * 0.0045
	P.plunge_phase = "land"; P.plunge_t = 0.0; set_anim("plungeLand")
	G.shake = minf(9, 4 + fall * 0.02); G.hitstop = 0.07; Sfx.play("slam"); G.dust(P.x, P.y, 14)
	for i in 24:
		var a = i / 24.0 * PI
		G.parts.append(S.Part.new(P.x, P.y - 2, cos(a) * R * 3, -sin(a) * 60, 0.35, Color("#fff4c8") if i % 2 else Color.WHITE, 0, 2))
	var hit = G.mobs.filter(func(e): return e.state != "dead" and absf(e.y - P.y) < 24 and absf(e.x - P.x) < R)
	hit.sort_custom(func(a, b): return absf(a.x - P.x) < absf(b.x - P.x))
	for e in hit.slice(0, 2):
		G.mob_ctl.damage(e, {"dmg": mult, "kb": 160, "up": -240, "style": 24, "anim": "plunge", "both": true, "heavy": true})


func land_fx(k: float) -> void:
	if G.M.get("indoor", false):
		return
	if G.world.snow_cover > 0.3:
		for i in int(10 + k * 10):
			var s = 1 if i % 2 else -1
			G.parts.append(S.Part.new(P.x + s * randf_range(2, 8), P.y - 1, s * randf_range(30, 90) * k, -randf_range(40, 120) * k, randf_range(0.4, 0.8), Color("#f4f8ff") if i % 3 else Color("#dde8f8"), 260, 1 if i % 4 else 2))
		Sfx.play("step_snow", 1.4)
	elif G.world.rain > 0.4:
		for i in int(8 + k * 8):
			var s = 1 if i % 2 else -1
			G.parts.append(S.Part.new(P.x + s * randf_range(1, 6), P.y - 1, s * randf_range(20, 70), -randf_range(80, 170) * k, randf_range(0.3, 0.55), Color("#bfe0ff") if i % 3 else Color.WHITE, 700, 1, P.y))
		Sfx.play("step_wet", 1.4)


func step(heavy: bool) -> void:
	var x = P.x - P.face * 3
	var y = P.y
	if G.world.snow_cover > 0.3:
		for i in 3:
			G.parts.append(S.Part.new(x, y - 1, randf_range(-25, 25), randf_range(-40, -15), 0.4, Color("#f4f8ff"), 200, 1))
	elif G.world.rain > 0.4:
		for i in 4:
			G.parts.append(S.Part.new(x, y - 1, randf_range(-40, 40), randf_range(-70, -30), 0.3, Color("#bfe0ff"), 400, 1))
	elif heavy:
		G.parts.append(S.Part.new(x, y - 1, -P.face * randf_range(10, 25), randf_range(-12, -4), 0.35, Color("#efe6cf"), 0, 2))
	var surf = "grass"
	if G.world.snow_cover > 0.3:
		surf = "snow"
	elif G.world.rain > 0.4:
		surf = "wet"
	elif P.surf != null and G.M.has("pond") and P.surf.y == G.M.floorY and P.x > G.M.pond.x0 - 60 and P.x < G.M.pond.x0 + 12:
		surf = "wood"
	Sfx.step(heavy, surf)


func use_potion(k: String) -> void:
	var p: Dictionary = P.pots[k]
	if P.state == "dead":
		return
	if p.n <= 0:
		G.float_text(P.x, P.y - 56, "Empty — recharging", "call")
		return
	if k == "hp":
		if P.hp >= G.PS.hp:
			G.float_text(P.x, P.y - 56, "Already at full health", "call")
			return
		var h = roundi(G.PS.hp * 0.4)
		P.hp = minf(G.PS.hp, P.hp + h)
		G.float_text(P.x, P.y - 52, "+%d" % h, "exp")
		P.regen_boost = 3.0
	else:
		if P.en >= G.PS.enMax:
			G.float_text(P.x, P.y - 56, "Energy is full", "call")
			return
		var r = roundi(G.PS.enMax * 0.6)
		P.en = minf(G.PS.enMax, P.en + r)
		G.float_text(P.x, P.y - 52, "+%d EN" % r, "call")
	p.n -= 1
	Sfx.play("potion")
	for i in 14:
		G.parts.append(S.Part.new(P.x + randf_range(-10, 10), P.y - randf_range(0, 40), 0, -randf_range(20, 60), 0.6, Color("#ff6a7a") if k == "hp" else Color("#7ad8ff"), 0, 1))


# ------------------------------------------------------------------ damage taken

func def_mul(lv: float) -> float:
	var K = 30 + 4.5 * lv
	return 1 - minf(0.75, G.PS.def / (G.PS.def + K))


func hurt(src, dmg: float) -> void:
	if P.state == "dead":
		return
	if P.state == "dash" or P.iframes > 0:
		if P.state == "dash" and not P.dodged.has(src):
			P.dodged[src] = true
			perfect_dodge()
		return
	var from_front = signf(src.x - P.x) == P.face or absf(src.x - P.x) < 4
	if P.state == "block" and from_front:
		if G.game_time - P.block_t < 0.2:   # a well-timed guard is a parry
			Sfx.play("parry"); G.slowmo = 0.4; G.hitstop = 0.08; G.shake = 4; G.style_add(45, "parry"); G.combo_hit()
			src.state = "hurt"; src.stun = 1.4; src.vx = P.face * 200; src.vy = -200; src.juggle = 0.4; src.flash = 0.15
			G.float_text(P.x, P.y - 52, "Parry!", "call"); G.sparks(P.x + P.face * 12, P.y - 26, Color("#8ff0ff"), 14)
			return
		var chip = maxi(1, roundi(dmg * 0.15))
		P.hp -= chip
		Sfx.play("block"); G.float_text(P.x, P.y - 48, str(chip), "hurt")
		P.vx = -P.face * 90; G.sparks(P.x + P.face * 10, P.y - 24, Color.WHITE, 6)
		if P.hp <= 0:
			die()
		return
	var ecrit = randf() < 0.12
	var d = maxi(1, roundi(dmg * (1.5 if ecrit else 1.0) * def_mul(src.lv) * randf_range(0.9, 1.1)))
	P.hp -= d
	P.last_hurt = G.game_time
	G.float_text(P.x, P.y - 48, ("%d!" % d) if ecrit else str(d), "hurt")
	Sfx.play("hurt"); G.vignette = 1.0; G.shake = 4 if ecrit else 2
	if P.state == "climb" and not ecrit:   # ordinary hits don't shake you off a rope, critical ones do
		P.iframes = 0.8; P.flash = 0.1
		if P.hp <= 0:
			die()
		return
	if ecrit and P.state == "climb":
		G.float_text(P.x, P.y - 58, "Knocked off!", "call")
	if G.style.hits:
		G.end_combo(true)
	G.style.pts *= 0.4
	G.style.rank = G.rank_of(G.style.pts)
	P.state = "hurt"; P.hurt_t = 0.0; P.iframes = 1.1
	var away = signf(P.x - src.x)
	P.vx = (away if away != 0 else -P.face) * 130.0
	P.vy = -150; P.grounded = false; P.surf = null; P.rope = null
	if P.hp <= 0:
		die()


func die() -> void:
	P.hp = 0; P.state = "dead"; P.dead_t = 0.0; set_anim("down")
	var lost = floori(G.CH().exp * 0.1)
	G.CH().exp -= lost
	G.banner("Knocked out!", ("Lost %d EXP. Back to the start in a moment." % lost) if lost else "Back to the start in a moment.")


func perfect_dodge() -> void:
	G.slowmo = 0.45; G.style_add(40, "dodge"); G.combo_hit()
	G.float_text(P.x, P.y - 52, "Perfect dodge!", "call")
	Sfx.play("dodge_perfect")


# ------------------------------------------------------------------ the big update

func update(dt: float) -> void:
	var K: Dictionary = G.keys
	var pressed: Dictionary = G.pressed
	var PS: Dictionary = G.PS
	var M: Dictionary = G.M
	# potions recharge one at a time
	for k in ["hp", "sp"]:
		var pt: Dictionary = P.pots[k]
		if pt.n < POT_MAX:
			pt.t += dt
			if pt.t >= POT_RECHARGE:
				pt.t = 0.0; pt.n += 1
		else:
			pt.t = 0.0
	if pressed.get("pot_hp"):
		use_potion("hp")
	if pressed.get("pot_sp"):
		use_potion("sp")
	if P.regen_boost > 0:
		P.regen_boost -= dt
		P.hp = minf(PS.hp, P.hp + PS.hp * 0.035 * dt)
	var aspd: float = PS.aspd
	P.iframes -= dt; P.touch_cd -= dt; P.drop_t -= dt; P.flash -= dt; P.land_t -= dt
	var left: bool = K.get("left", false)
	var right: bool = K.get("right", false)
	var up: bool = K.get("up", false)
	var down: bool = K.get("down", false)
	var dir_in = (1 if right else 0) - (1 if left else 0)
	if dir_in and P.grounded:
		P.run_t += dt
	elif not dir_in:
		P.run_t = 0
	for i in range(G.speed_lines.size() - 1, -1, -1):
		var l = G.speed_lines[i]
		l.t += dt; l.x += l.vx * dt
		if l.t > l.life:
			G.speed_lines.remove_at(i)
	if P.state == "dead":
		P.dead_t += dt; P.anim_t += dt
		if P.dead_t > 2.6:
			G.recalc_stats(); P.hp = PS.hp; P.iframes = 1.5
			G.load_map(G.map_id)
		return
	# --- input buffering: slightly early presses still count (jump 0.14s, attacks 0.22s), plus a coyote window
	var now: float = G.game_time
	var B: Dictionary = P.buf
	if pressed.get("jump"): B.jump = now
	if pressed.get("atk"): B.atk = now
	if pressed.get("heavy"): B.heavy = now
	if pressed.get("dash"): B.dash = now
	if P.grounded or P.state == "climb" or G.in_water():
		P.coyote = now; P.air_atk = 0
	var buffered = func(k: String, w: float) -> bool: return B.get(k) != null and now - B[k] <= w
	var use = func(k: String) -> void: B[k] = null
	if G.dbl_tap != "":
		if dir_in:
			P.run_t = 1
		G.dbl_tap = ""
	var wet: bool = G.in_water()
	var r_near = G.rope_at()
	var at_rope_top: bool = r_near != null and P.grounded and absf(P.y - r_near.y0) < 2
	var climbable: bool = r_near != null and not at_rope_top
	# ↑ is contextual: portal > note > rope > climb-off > jump (a jump from ↑ waits 60ms in case Z follows for a rising slash)
	if pressed.get("up"):
		var pt = G.portal_at() if P.grounded else null
		var nt = G.note_at() if P.grounded else null
		if nt != null:
			G.thought = {"text": nt.text, "t": 0.0}
			Sfx.play("note")
		elif pt != null:
			G.travel(pt)
		elif P.state == "climb":
			if dir_in:
				climb_off(dir_in)
		elif climbable and P.state in ["move", "dash", "crouch"]:
			start_climb(r_near, false)
		else:
			B.up_jump = now
	if P.state == "climb" and up and dir_in and (pressed.get("left") or pressed.get("right")):
		climb_off(dir_in)
	if up and climbable and P.state == "move" and not P.grounded and now - P.last_jump_t > 0.25:
		start_climb(r_near, false)   # grab ropes mid-air by holding ↑
	var rising_intent = up
	if B.get("up_jump") != null:
		if buffered.call("atk", 0.1):
			B.up_jump = null; rising_intent = true
		elif now - B.up_jump >= 0.06:
			B.jump = B.up_jump; B.up_jump = null
	var can_act: bool = P.state in ["move", "block", "crouch"] or (P.state == "dash" and P.dash_t > 0.16) \
		or (P.state == "attack" and frame_of(P.anim, P.move_t * aspd, false) >= P.move.cancel)
	var can_cancel = P.state != "hurt" and P.state != "dead"
	if down and P.grounded and P.state in ["move", "crouch"] and at_rope_top and not buffered.call("jump", 0.14):
		start_climb(r_near, true)
	# jumping / swimming
	if buffered.call("jump", 0.14) and can_cancel:
		if wet and P.state != "climb":
			use.call("jump")
			var Wp: Dictionary = M.pond
			var head_out: bool = P.y - 36 < Wp.surface + 2
			var near_bank: bool = P.x < Wp.x0 + 24 or P.x > Wp.x1 - 24
			if head_out and (near_bank or P.y < Wp.surface + 16):
				P.vy = -340; P.grounded = false; P.surf = null; P.state = "move"; G.splash(P.x, 0.8); Sfx.play("jump")
			else:
				P.vy = -235; P.grounded = false; P.surf = null; P.state = "move"; Sfx.play("swim")
				for i in 3:
					G.parts.append(S.Part.new(P.x + P.face * 8, P.y - 30, randf_range(-10, 10), randf_range(-40, -20), 0.6, Color(220 / 255.0, 240 / 255.0, 1, 0.8), -20, 1))
		elif P.state == "climb":
			if dir_in:
				use.call("jump"); climb_off(dir_in)
		elif (P.grounded or P.state == "crouch") and down and P.surf != null and not P.surf.floor:
			use.call("jump"); P.drop_t = 0.28; P.grounded = false; P.surf = null; P.vy = 40; P.state = "move"   # drop through a platform
		elif P.grounded or (now - P.coyote < 0.1 and P.jumps == 0 and P.vy >= 0):
			use.call("jump")
			var from_slide = P.state == "slide"
			P.vy = -335; P.last_jump_t = now; P.grounded = false; P.surf = null; P.jumps = 1; P.state = "move"
			if from_slide:
				P.vx *= 1.15
			Sfx.play("jump"); G.dust(P.x, P.y, 4)
		elif P.jumps < 2 and P.state != "plunge":
			use.call("jump"); P.jumps = 2; P.vy = -240
			P.face = dir_in if dir_in else P.face
			P.vx = P.face * 215.0; P.state = "move"; set_anim("flip"); Sfx.play("djump"); G.style_add(4, "flash")
	# dodge
	if buffered.call("dash", 0.12) and can_cancel and P.state != "climb" and P.state != "plunge" and (P.grounded or P.air_dash == 0):
		use.call("dash")
		if not P.grounded:
			P.air_dash = 1
		P.state = "dash"; P.dash_t = 0.0
		P.face = dir_in if dir_in else P.face
		P.vx = P.face * 320.0
		if not P.grounded:
			P.vy = minf(P.vy, -40)
		P.iframes = 0.26; P.dodged.clear(); set_anim("dash"); Sfx.play("dodge")
	# attacks (↑ held turns the opener into a rising slash / rising cut)
	if buffered.call("atk", 0.22) and (P.state == "prone" or (P.state == "attack" and P.move_id == "stab" and frame_of(P.anim, P.move_t * aspd, false) >= 2)):
		use.call("atk")
		if dir_in:
			P.face = dir_in
		start_move("stab")
	if buffered.call("atk", 0.22) and not P.state in ["climb", "hurt", "plunge"] and (P.state != "dash" or P.dash_t > 0.16):
		if not P.grounded and not wet:
			if P.state == "attack" and P.move_id in AIR_CHAIN:
				P.queued = true; use.call("atk")
			elif P.state != "attack":
				use.call("atk")
				if dir_in:
					P.face = dir_in
				start_move("air2" if rising_intent else "air")
				if air_lift():
					P.vy = minf(P.vy, -60)
		elif P.state == "attack" and P.move_id in CHAIN:
			P.queued = true; use.call("atk")
		elif can_act and (P.grounded or wet):
			use.call("atk"); B.up_jump = null
			if dir_in:
				P.face = dir_in
			var pause = now - P.chain_end_t
			if rising_intent:
				start_move("rising")
			elif P.last_chain == 1 and pause > 0.25 and pause < 1.0:
				start_move("whirl"); G.style_add(18, "pause")
			else:
				start_move("slash")
	if buffered.call("heavy", 0.2) and not P.state in ["climb", "hurt", "plunge"]:
		if not P.grounded and not wet and P.state != "dash":
			use.call("heavy"); start_plunge()
		elif P.grounded and P.state == "attack" and P.move_id in CHAIN and CHAIN.find(P.move_id) <= 2:
			use.call("heavy"); P.queued_heavy = true
		elif P.grounded and can_act:
			use.call("heavy")
			if dir_in:
				P.face = dir_in
			start_move("heavy")
	# ↓: slide out of a run, otherwise lie prone; Shift is a standing guard
	if down and P.grounded and not wet and not at_rope_top and P.state == "move":
		if absf(P.vx) > 95:
			P.state = "slide"; P.slide_t = 0.0; P.vx = P.face * maxf(250, absf(P.vx) + 90); P.hit_set.clear(); set_anim("slide"); Sfx.play("slide")
		else:
			P.state = "prone"; set_anim("prone"); Sfx.play("guard")
	if P.state == "prone" and not down:
		P.state = "move"; set_anim("idle")
	if K.get("block", false) and P.grounded and P.state == "move" and not wet:
		P.state = "block"; P.block_t = now; set_anim("block"); Sfx.play("guard")
	if not K.get("block", false) and P.state == "block":
		P.state = "move"

	# --- state updates
	var run = P.run_t > 0.28
	match P.state:
		"move":
			if G.in_water():
				P.vx = G.damp(P.vx, dir_in * 115 * PS.spd, 7, dt)
				if dir_in:
					P.face = dir_in
			elif P.grounded:
				P.vx = G.damp(P.vx, dir_in * (125 if run else 72) * PS.spd, 18, dt)
				if dir_in:
					P.face = dir_in
			elif dir_in:
				P.vx = G.damp(P.vx, dir_in * maxf(absf(P.vx), 90), 4, dt)
		"block":
			P.vx = G.damp(P.vx, 0, 16, dt)
		"prone":
			if dir_in:
				P.face = dir_in
			P.vx = G.damp(P.vx, dir_in * 34 * PS.spd, 12, dt)
			set_anim("crawl" if dir_in else "prone")
			if dir_in:
				var ph = frame_of("crawl", P.anim_t, true) / 4
				if ph != P.crawl_ph:
					P.crawl_ph = ph; Sfx.step(false, "grass")
		"slide":
			P.slide_t += dt
			P.vx *= exp(-dt * 2.6)
			if int(floor(P.slide_t * 30)) % 2 == 0:
				G.parts.append(S.Part.new(P.x - P.face * 6, P.y - 1, -P.face * randf_range(10, 30), randf_range(-20, -5), 0.3, Color("#f4f8ff") if G.world.snow_cover > 0.3 else Color("#efe6cf"), 0, 2))
			var bx: Dictionary = G.hbox(P.x - 10 + P.face * 6, P.x + 10 + P.face * 6, P.y - 14, P.y)
			if not P.hit_set.has("slide"):
				for e in G.mobs:
					if e.state != "dead" and G.overlap(bx, G.mob_ctl.box(e)):
						P.hit_set["slide"] = true
						G.mob_ctl.damage(e, {"dmg": 0.6, "kb": 60, "up": -200, "style": 16, "anim": "slide"})
						break
			if P.slide_t > 0.46 or absf(P.vx) < 60:
				P.state = "prone" if down else "move"
				if P.state == "prone":
					set_anim("prone")
		"dash":
			P.dash_t += dt
			P.vx *= exp(-dt * 4)
			if not P.grounded:
				P.vy = minf(P.vy, 60)
			if P.dash_t > 0.3:
				P.state = "move"
		"cheer":
			P.vx = G.damp(P.vx, 0, 12, dt)
			P.cheer_t += dt
			if P.cheer_t > 1.1 or dir_in or K.get("jump") or K.get("atk") or K.get("heavy") or K.get("dash"):
				P.state = "move"
		"hurt":
			P.hurt_t += dt
			P.vx = G.damp(P.vx, 0, 3, dt)
			if P.hurt_t > 0.4 and P.grounded:
				P.state = "move"
		"climb":
			var r: Dictionary = P.rope
			P.x = r.x; P.vx = 0
			var v = (-1 if up else 0) + (1 if down else 0)
			P.y += v * 80 * dt
			P.anim_t += dt if v else 0.0
			if v:
				var ph = frame_of("climb", P.anim_t, true) / 2
				if ph != P.climb_ph:
					P.climb_ph = ph; Sfx.play("rope", 1.0, randf_range(0.9, 1.15))
			if P.y <= r.y0:
				var s = _surface_at(r.y0)
				if s != null:
					P.y = s.y; P.state = "move"; P.grounded = true; P.surf = s; P.rope = null; P.jumps = 0
				else:
					P.y = r.y0
			if P.y >= r.y1:
				P.y = r.y1
				var s = _surface_at(r.y1)
				P.state = "move"; P.rope = null
				if s != null:
					P.grounded = true; P.surf = s
		"plunge":
			P.plunge_t += dt
			P.vx = G.damp(P.vx, 0, 10, dt)
			if P.plunge_phase == "start" and P.plunge_t > 0.14:
				P.plunge_phase = "dive"; set_anim("plunge"); P.vy = 580; Sfx.play("swing_heavy")
			if P.plunge_phase == "dive":
				P.vy = 580
				var bx: Dictionary = G.hbox(P.x - 11, P.x + 11, P.y - 26, P.y + 10)
				for e in G.mobs:
					if P.plunge_hits < 2 and e.state != "dead" and not P.hit_set.has(e.id) and G.overlap(bx, G.mob_ctl.box(e)):
						P.hit_set[e.id] = true; P.plunge_hits += 1
						G.mob_ctl.damage(e, {"dmg": 0.8, "kb": 40, "up": 160, "style": 12, "anim": "plunge", "both": true})
				if G.parts.size() < 400:
					G.parts.append(S.Part.new(P.x + randf_range(-3, 3), P.y - 30, 0, -60, 0.18, Color("#bff3ff"), 0, 1))
			if P.plunge_phase == "land" and P.plunge_t > 0.42:
				P.state = "move"
		"attack":
			_update_attack(dt, dir_in, down, aspd)

	_physics(dt, M)
	_choose_anim(dt)
	# regen out of combat, energy over time
	if G.game_time - P.last_hurt > 4 and P.hp < PS.hp:
		P.hp = minf(PS.hp, P.hp + PS.hp * 0.02 * dt)
	var raining: bool = G.world.rain > 0.3 and not M.get("indoor", false)
	P.wet = clampf(P.wet + (1.0 if G.in_water() else (dt * 0.5 if raining else -dt / 25)), 0, 1)
	if P.wet > 0.15 and randf() < dt * 14 * P.wet:
		G.parts.append(S.Part.new(P.x + randf_range(-8, 8), P.y - 44 + randf_range(0, 30), P.vx * 0.2, randf_range(10, 30), 0.45, Color(170 / 255.0, 215 / 255.0, 1, 0.9), 500, 1))
	P.en = minf(PS.enMax, P.en + PS.enRegen * dt)


func _surface_at(y: float):
	for q in G.surfaces:
		if absf(q.y - y) < 2 and P.x >= q.x0 and P.x <= q.x1:
			return q
	return null


func _update_attack(dt: float, dir_in: int, down: bool, aspd: float) -> void:
	var mv: Dictionary = P.move
	P.move_t += dt
	var f = frame_of(mv.anim, P.move_t * aspd, false)
	var n = int(anim_info(mv.anim).frames)
	if P.grounded:
		P.vx = G.damp(P.vx, 0, 9, dt)
	if mv.get("air", false) and not P.grounded and P.air_atk <= AIR_LIFT_MAX:
		P.vy = minf(P.vy, 40)
	if f != P.last_frame:
		P.last_frame = f
		if mv.hits.has(float(f)) or mv.hits.has(f):
			var b: Array = mv.box
			var bx: Dictionary = G.hbox(P.x + b[0], P.x + b[1], P.y + b[2], P.y + b[3]) if P.face > 0 else G.hbox(P.x - b[1], P.x - b[0], P.y + b[2], P.y + b[3])
			var best = null
			var bd = 1e9
			for e in G.mobs:
				if e.state == "dead" or not G.overlap(bx, G.mob_ctl.box(e)):
					continue
				var d = absf(e.x - P.x) + absf(e.y - P.y) * 0.5
				if d < bd:
					bd = d; best = e
			if best != null:
				G.mob_ctl.damage(best, mv)
				P.en = minf(G.PS.enMax, P.en + G.PS.enHit)   # plain hits refuel energy
			if mv.get("heavy", false):
				G.dust(P.x + P.face * 26, P.y, 10); Sfx.play("slam"); G.shake = maxf(G.shake, 4)
	if f >= mv.cancel and P.queued_heavy:
		if dir_in:
			P.face = dir_in
		start_move("aegis")
		return
	if f >= mv.cancel and P.queued:
		var list = AIR_CHAIN if P.move_id in AIR_CHAIN else CHAIN
		var i = list.find(P.move_id)
		if (i >= 0 and i < list.size() - 1) or list == CHAIN:
			if dir_in:
				P.face = dir_in
			start_move(list[(i + 1) % list.size()])
			if list == AIR_CHAIN:
				P.vy = minf(P.vy, -90)
			return
		P.queued = false
	if P.move_t * aspd * anim_info(mv.anim).fps >= n:
		P.state = "prone" if mv.get("prone", false) and down else "move"
		if P.state == "prone":
			set_anim("prone")
		P.last_chain = CHAIN.find(P.move_id)
		P.chain_end_t = G.game_time


func _physics(dt: float, M: Dictionary) -> void:
	if P.state == "climb":
		return
	var wet_now: bool = G.in_water()
	if P.state == "plunge" and P.plunge_phase == "dive":
		pass
	elif wet_now:
		P.vy = minf(80, P.vy + G.GRAV * 0.22 * dt)
		P.vy *= exp(-dt * 1.8)
	else:
		var g = 1.0
		if P.state == "attack" and P.move.get("air", false):
			g = 0.35
		elif P.state == "plunge":
			g = 0.2
		P.vy = minf(G.MAXFALL, P.vy + G.GRAV * dt * g)
	var prev_y = P.y
	P.x += P.vx * dt
	P.y += P.vy * dt
	P.x = clampf(P.x, 24, M.w - 24)   # the floor ends 20px from each edge: stop at the border
	if M.has("pond"):
		var W: Dictionary = M.pond
		if P.y > M.floorY + 1 and P.x > W.x0 - 8 and P.x < W.x1 + 8:
			P.x = clampf(P.x, W.x0 + 7, W.x1 - 7)   # the banks are walls below ground level
		if (prev_y - 4 < W.surface) != (P.y - 4 < W.surface) and P.x > W.x0 and P.x < W.x1:
			var into: bool = P.y - 4 >= W.surface
			var force = minf(1.6, absf(P.vy) / 180 + 0.3)
			G.splash(P.x, force * (2.0 if P.state == "plunge" else 1.0))
			if into and P.state == "plunge":
				P.state = "move"; P.vy = 90
			if into:
				P.vy *= 0.35; P.jumps = 1; P.air_dash = 0
	if P.grounded:
		var s = on_surface()
		if s == null or P.x < P.surf.x0 - 2 or P.x > P.surf.x1 + 2:
			var s2 = null
			for q in G.surfaces:
				if P.x >= q.x0 and P.x <= q.x1 and absf(P.y - q.y) < 1:
					s2 = q
					break
			if s2 != null:
				P.surf = s2
			else:
				P.grounded = false; P.surf = null
		else:
			P.y = P.surf.y; P.vy = 0
	if not P.grounded and P.vy >= 0:
		for s in G.surfaces:
			if P.x < s.x0 - 2 or P.x > s.x1 + 2:
				continue
			if prev_y <= s.y + 0.5 and P.y >= s.y and (s.floor or P.drop_t <= 0):
				if P.state == "plunge":
					P.y = s.y; P.grounded = true; P.surf = s; P.vy = 0; plunge_impact()
					break
				P.y = s.y; P.grounded = true; P.surf = s
				if P.vy > 140:
					land_fx(minf(1.5, P.vy / 300))
				if P.vy > 260:
					P.land_t = 0.22; G.dust(P.x, P.y, 5); Sfx.play("land")
					if P.state == "move":
						set_anim("land")
				else:
					step(true)
				P.vy = 0; P.jumps = 0; P.air_dash = 0
				if P.state == "attack" and P.move.get("air", false):
					P.state = "move"
				break
	if P.y > M.h + 50:
		P.x = M.start; P.y = M.floorY; P.vy = 0


func _choose_anim(dt: float) -> void:
	var rate = 1.0
	if P.state == "move":
		var sp = absf(P.vx)
		if G.in_water() and (not P.grounded or (P.surf != null and P.surf.water)):
			set_anim("swim"); P.idle_t = 0
		elif not P.grounded:
			if not (P.anim == "flip" and P.anim_t < 0.37):
				set_anim("jump")
			P.idle_t = 0
		elif P.anim == "land" and P.land_t > 0 and sp < 60:
			pass
		elif sp > 95:
			set_anim("run"); rate = sp / 125; P.idle_t = 0
		elif sp > 12:
			set_anim("walk"); rate = maxf(0.6, sp / 70); P.idle_t = 0
		else:
			P.idle_t += dt
			if P.idle_t > 7 and P.anim != "rest":
				set_anim("rest")
			elif P.anim != "rest":
				set_anim("idle")
		if P.grounded and (P.anim == "walk" or P.anim == "run"):
			var n = int(anim_info(P.anim).frames)
			var ph = frame_of(P.anim, P.anim_t, true) / (n / 2)
			if ph != P.step_ph:
				P.step_ph = ph; step(P.anim == "run")
	else:
		P.idle_t = 0
		if P.state == "hurt":
			set_anim("hurt")
	if P.cheer_q and P.grounded and P.state == "move" and not G.in_water():
		P.cheer_q = false; P.state = "cheer"; P.cheer_t = 0.0; set_anim("cheer"); Sfx.play("cheer")
	if P.state != "climb":
		P.anim_t += dt * rate
	# hair and hem stream with the wind (baked variants), plus a gentle sway
	var gt: float = G.game_time
	var sprinting: bool = P.grounded and P.anim == "run" and absf(P.vx) > 110
	var wind_target: float = (1 if P.face > 0 else -1) * G.world.wind * 1.5 + sin(gt * 2.1) * 0.45 * (0.4 + G.world.wind) + sin(gt * 5.3) * 0.15 \
		+ ((1.5 + sin(gt * 17) * 0.9 + sin(gt * 29) * 0.4) if sprinting else 0.0)
	if sprinting and randf() < dt * 34:
		G.speed_lines.append({"x": P.x - P.face * randf_range(10, 22), "y": P.y - randf_range(6, 44), "len": randf_range(10, 26), "vx": -P.face * randf_range(40, 90), "t": 0.0, "life": randf_range(0.18, 0.32)})
	P.wind_v = G.damp(P.wind_v, wind_target, 4, dt)


## which frame of the current animation to show
func frame() -> int:
	var a = P.anim
	if a == "jump":
		return 1 if P.vy < -120 else (2 if P.vy < 80 else 3)
	if a == "climb":
		return frame_of("climb", P.anim_t, true)
	if P.state == "attack":
		return frame_of(a, P.move_t * G.PS.aspd, false)
	return frame_of(a, P.anim_t, anim_info(a).loop)
