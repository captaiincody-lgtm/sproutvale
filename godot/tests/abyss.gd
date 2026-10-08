extends Node
## Scripted run through the Abyss: the Dreamer's Gate, the five Abyss maps and their monsters, the water,
## the Abyss debuff and the other ailments, The Dreamer's attacks and death, the Dream Key, the bubble,
## the Dreambox's Abyssal Devour skill, and the menus that list the new things. Saves screenshots.
## Run:  godot --path godot res://tests/abyss.tscn -- <output dir>
## (needs a display or a virtual one such as xvfb-run)

var game
var out_dir := "user://abyss"
var t := 0.0
var shots := 0
var steps: Array = []
var busy := false
var keepAlive := true   # top the hero's health up every frame (god mode would stop grabs and bites)


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abyss_save.json"))
	game = load("res://main.tscn").instantiate()
	game.set("SAVE_PATH_OVERRIDE", "user://abyss_save.json")
	add_child(game)
	game.save = game.loadSave()
	game.save.settings.weather = "sunny"
	game.save.trophies = {"croc": 1, "warlord": 1}
	var at = [0.6]
	var add = func(dt, what, arg = null):
		at[0] += dt
		steps.append([at[0], what, arg])
	add.call(0.0, "pick", "rock")
	add.call(0.2, "tap", KEY_ENTER)
	add.call(1.2, "tap", KEY_ENTER)
	add.call(0.1, "tap", KEY_ENTER)
	add.call(0.5, "skip")
	add.call(1.0, "exp", 6000000)
	# the gate behind the Warlord's throne
	add.call(0.1, "warp", "crimson5")
	add.call(2.0, "togate", "abyss1")
	add.call(0.4, "shot", "dreamers_gate")
	add.call(0.1, "tap", KEY_UP)
	# Map 1: the shore, the black water, the toads and gulls
	add.call(2.2, "shot", "abyss1")
	add.call(0.1, "near", "toad")
	add.call(1.4, "shot", "toad")
	add.call(0.1, "near", "seagull")
	add.call(1.6, "shot", "seagull")
	add.call(0.1, "poop")
	add.call(0.6, "shot", "dropping")
	add.call(0.1, "dive", 0)
	add.call(0.5, "shot", "sinking1")
	add.call(0.8, "shot", "sinking2")
	add.call(2.0, "shot", "abyss_drain")
	add.call(0.1, "portal")
	add.call(0.5, "shot", "abyss1_portal")
	# Map 2: all underwater
	add.call(0.1, "warp", "abyss2")
	add.call(2.0, "shot", "abyss2")
	add.call(0.1, "near", "bass")
	add.call(1.2, "shot", "bass")
	add.call(0.1, "near", "crab")
	add.call(1.2, "shot", "crab")
	add.call(0.1, "build", 60)
	add.call(0.3, "shot", "buildup")
	add.call(0.1, "go", 1700)
	add.call(1.0, "shot", "abyss2_deep")
	# Map 3: ruins and runes
	add.call(0.1, "warp", "abyss3")
	add.call(2.0, "shot", "abyss3")
	add.call(0.1, "near", "shark")
	add.call(1.2, "shot", "shark")
	add.call(0.1, "near", "squid")
	add.call(1.2, "shot", "squid")
	add.call(0.1, "ailments")
	add.call(0.4, "shot", "inked_confused")
	add.call(0.1, "go", 1000)
	add.call(0.6, "shot", "abyss3_mid")
	add.call(0.1, "under")
	add.call(0.4, "shot", "under_idle")
	add.call(0.1, "down", true)
	add.call(0.5, "shot", "under_prone")
	add.call(0.1, "right", true)
	add.call(0.6, "shot", "under_crawl")
	add.call(0.1, "down", false)
	add.call(0.5, "shot", "under_run")
	add.call(0.1, "right", false)
	add.call(0.1, "float")
	add.call(0.1, "tap", KEY_X)
	add.call(0.4, "shot", "under_plunge")
	add.call(0.6, "under")
	add.call(0.1, "float")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "shot", "under_air_attack")
	# Map 4: the black plateau
	add.call(0.1, "warp", "abyss4")
	add.call(2.0, "shot", "abyss4")
	add.call(0.1, "near", "orca")
	add.call(1.2, "shot", "orca")
	add.call(0.1, "tumble")
	add.call(0.3, "shot", "tumble_spin")
	add.call(1.0, "shot", "tumble_settle")
	add.call(0.1, "near", "octopus")
	add.call(1.0, "shot", "octopus")
	add.call(0.1, "octograb")
	add.call(0.35, "shot", "octo_lift")
	add.call(0.4, "shot", "octo_slam")
	add.call(0.6, "shot", "octo_fling")
	add.call(0.1, "elite")
	add.call(1.0, "shot", "elite")
	add.call(0.1, "go", 1760)
	add.call(0.5, "shot", "boss_sign")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "map")
	add.call(0.5, "shot", "world_map")
	add.call(0.1, "tap", KEY_TAB)
	# Map 5: The Dreamer
	add.call(0.3, "warp", "abyss5")
	add.call(1.6, "shot", "dreamer_rise")
	add.call(2.6, "shot", "dreamer")
	add.call(0.1, "act", "whips")
	add.call(0.5, "shot", "whips_tell")
	add.call(0.6, "shot", "whips")
	add.call(1.6, "act", "gaze")
	add.call(0.7, "shot", "gaze_glow")
	add.call(0.5, "shot", "gaze_flash")
	add.call(1.0, "calm")
	add.call(0.1, "act", "laser")
	add.call(0.6, "shot", "laser_charge")
	add.call(0.6, "shot", "laser_sweep")
	add.call(0.5, "shot", "laser_steam")
	add.call(1.0, "calm")
	add.call(0.1, "act", "grab")
	add.call(0.8, "shot", "tent_grab")
	add.call(0.8, "shot", "tent_slam")
	add.call(1.5, "calm")
	add.call(0.1, "act", "suck")
	add.call(1.2, "shot", "suck")
	add.call(1.0, "shot", "eaten")
	add.call(2.4, "shot", "spat_out")
	add.call(1.5, "calm")
	add.call(0.1, "hit")
	add.call(0.2, "shot", "hit_eye")
	add.call(0.1, "killboss")
	add.call(0.5, "shot", "gurgle")
	add.call(1.6, "shot", "dialog1")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(1.2, "shot", "dialog2")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(1.0, "shot", "key_drop")
	add.call(0.1, "tokey")
	add.call(0.6, "shot", "key_got")
	add.call(2.6, "shot", "bubble_gate")
	add.call(0.1, "tobox")
	add.call(0.5, "shot", "dreambox_shaking")
	add.call(2.2, "shot", "dreambox_open")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.2, "farm")
	add.call(2.6, "shot", "dreambox_skill")
	add.call(0.1, "tap", KEY_Z)
	add.call(0.3, "tap", KEY_Z)
	add.call(0.4, "summon")
	add.call(2.0, "shot", "resummon")
	add.call(0.1, "killboss")
	add.call(2.4, "shot", "refight_sinks")
	# the bubble
	add.call(0.2, "togate", "bubble")
	add.call(0.1, "tap", KEY_UP)
	add.call(2.2, "shot", "bubble")
	add.call(0.1, "walk", 1.6)
	add.call(1.8, "shot", "bubble_walk")
	# the Dreambox skill
	add.call(0.1, "warp", "abyss2")
	add.call(2.0, "skill", "devour")
	add.call(0.4, "shot", "devour_bite")
	add.call(0.8, "shot", "devour_chew")
	add.call(1.0, "shot", "devour_spit")
	# menus (with a few Abyss monsters "defeated" and cards owned, to see their entries and card art)
	add.call(0.1, "cards")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "tab", "bestiary")
	add.call(0.1, "scroll", 4200)
	add.call(0.4, "shot", "bestiary_abyss")
	add.call(0.1, "scroll", 4000)
	add.call(0.4, "shot", "bestiary_dreamer")
	add.call(0.1, "tab", "inv")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "inv_key")
	add.call(0.1, "tab", "char")
	add.call(0.1, "scroll", 2000)
	add.call(0.3, "shot", "char_treasures")
	add.call(0.1, "tab", "skills")
	add.call(0.1, "scroll", 3000)
	add.call(0.3, "shot", "skills_boss")
	add.call(0.1, "tab", "quests")
	add.call(0.3, "shot", "quests")
	add.call(0.1, "tab", "map")
	add.call(0.4, "shot", "world_map_all")
	add.call(0.1, "tap", KEY_TAB)
	add.call(0.2, "warp", "trophy")
	add.call(1.6, "go", 200)
	add.call(0.4, "shot", "trophy_stand")
	add.call(0.1, "go", 1500)
	add.call(0.6, "shot", "trophy_cards")
	add.call(0.1, "reload")
	add.call(0.2, "quit")


func key(code: int, down: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _boss():
	for e in game.slimes:
		if e.boss:
			return e
	return null


func _mob(type: String):
	for e in game.slimes:
		if e.type == type and e.state != "dead":
			return e
	return null


func _process(delta: float) -> void:
	t += delta
	if keepAlive and game.P != null and game.P.state != "dead" and game.PS is Dictionary and game.PS.has("hp"):
		game.P.hp = maxf(game.P.hp, game.PS.hp * 0.6)
	while not busy and steps.size() and steps[0][0] <= t:
		var s: Array = steps.pop_front()
		match s[1]:
			"shot":
				busy = true
				_shot(s[2])
				break
			"pick":
				game.selClass = s[2]
			"tap":
				key(s[2], true)
				var code = s[2]
				get_tree().create_timer(0.05).timeout.connect(func(): key(code, false))
			"skip":
				if game.intro != null:
					game.introSkip()
			"warp":
				game.Warlord.introDone = true
				game.fadeTo = {"map": s[2]}
			"exp":
				game.gainExp(s[2])
				game.save.settings.god = false
				print("level ", game.CH().level)
			"togate":
				var g = null
				for p in game.M.portals:
					if p.to == s[2]:
						g = p
				print("portal to %s: %s" % [s[2], g != null])
				if g != null:
					game.P.x = g.x
					game.P.y = game.groundAt(g.x)
					game.P.vy = 0
			"portal":
				var g = game.M.portals[-1]
				game.P.x = g.x
				game.P.y = g.get("y", game.groundAt(g.x))
				print("abyss1 portals: ", game.M.portals)
			"near":
				var e = _mob(s[2])
				print("near %s: %s" % [s[2], e != null])
				if e != null:
					e.x = clampf(game.P.x + 70, 40, game.M.w - 40)
					if e.T.habitat in ["shore", "seabed"]:
						e.y = game.groundAt(e.x)
						e.vy = 0
					elif e.T.habitat == "air":
						e.y = game.seaTop() - 60
					else:
						e.y = minf(game.P.y - 10, game.groundAt(e.x) - 8)
					e.homeX = e.x
					e.homeY = e.y
					e.aggro = true
					game.P.face = 1
			"poop":
				var e = _mob("seagull")
				if e != null:
					game.addShot("poop", game.P.x, game.P.y - 60, 0, 40, e)
			"dive":
				var sea = game.M.sea
				game.P.x = sea.x0 + 160
				game.P.y = game.seaTop() + 20
				game.P.vy = 0
				game.applyAbyss()
				print("debuff: abyssT=%.1f" % game.P.abyssT)
			"go":
				game.P.x = s[2]
				game.P.y = game.groundAt(s[2]) - (40 if game.underSea(s[2], game.groundAt(s[2]) - 40) else 0)
				game.P.vy = 0
			"under":
				# stand on the sea floor, well under the surface
				game.P.x = 1000
				game.P.y = game.groundAt(1000)
				game.P.vx = 0; game.P.vy = 0; game.P.state = "move"; game.P.grounded = true
				game.P.hp = game.PS.hp
				print("under: inWater=%s underSea=%s state=%s" % [game.inWater(), game.underSea(game.P.x, game.P.y - 24), game.P.state])
			"down":
				key(KEY_DOWN, s[2])
				if not s[2]:
					print("after prone underwater: state=%s anim=%s" % [game.P.state, game.P.anim])
			"right":
				key(KEY_RIGHT, s[2])
			"float":
				# off the sea floor, so the air moves can fire
				game.P.grounded = false
				game.P.surf = null
				game.P.y -= 54
				game.P.vy = 0
			"build":
				game.abyssBuild(s[2])
				print("buildup %.0f, drain %.2f, hp %d / %d" % [game.P.abyssB, game.P.abyssDrain, game.PS.hp, game.PS.hpFull])
			"ailments":
				game.P.blindT = 5.0
				game.confusePlayer(10.0)
			"tumble":
				var e = _mob("orca")
				game.tumblePlayer(e, 2.0, 1.0)
			"octograb":
				var e = _mob("octopus")
				if e != null:
					game.P.held = null
					game.P.iframes = 0
					e.x = game.P.x + 10
					e.y = game.groundAt(e.x)
					e.face = -1
					e.data.cd2 = 0
					game._setState(e, "grab")
					game.P.held = {"kind": "octo", "e": e, "phase": "lift", "t": 0.0, "y0": game.groundAt(game.P.x)}
			"elite":
				if game.obelisk != null:
					game.obeliskElite(game.obelisk)
				else:
					var o = {"x": game.P.x, "y": game.groundAt(game.P.x)}
					game.obeliskElite(o)
				for e in game.slimes:
					if e.elite:
						print("elite %s at %.0f,%.0f size %.0fx%.0f" % [e.type, e.x, e.y, e.w, e.h])
			"act":
				var b = _boss()
				if b != null:
					game.P.held = null
					game.P.iframes = 0
					game.P.x = b.x - 90
					game.P.y = game.groundAt(game.P.x)
					game.P.face = 1
					b.data.act = ""
					game._startAct(b, s[2])
					print("act ", s[2])
			"calm":
				var b = _boss()
				if b != null:
					b.data.act = ""
					b.data.cd = 99.0
			"hit":
				var b = _boss()
				for e in game.slimes:
					if e.bossPart and e.data.get("kind") == "eye":
						var before = b.hp
						game.P.x = e.x - 20
						game.damageSlime(e, {"dmg": 1.0})
						print("eye hit: boss hp %d -> %d" % [before, b.hp])
						break
			"killboss":
				var b = _boss()
				print("boss: ", b != null)
				if b != null:
					game.P.x = b.x - 120
					game.P.face = 1
					b.data.introT = 99.0
					b.hp = 1
					game.damageSlime(b, {"dmg": 1.0, "id": "test%d" % shots})
					print("boss state after hit: ", b.state)
			"tokey":
				var found = false
				for d in game.drops:
					if d.kind == "key":
						game.P.x = d.x
						game.P.y = game.groundAt(d.x)
						found = true
				print("key on floor: ", found)
			"tobox":
				var found = false
				for d in game.drops:
					if d.kind == "box":
						game.P.x = d.x
						found = true
				print("box on floor: ", found, " dream key: ", game.save.get("keyItems", {}))
			"farm":
				var n = 0
				while game.skillRank("devour") == 0 and n < 3000:
					n += 1
					game.collectBox("dreamer")
					game.openBoxes("dreamer", 1)
				print("boxes until Abyssal Devour: %d, boons: %s, binds: %s" % [n, game.CH().get("boons"), game.CH().binds])
				game.loot.t = 0.0
				game.loot.shown = 0
			"summon":
				game.P.x = game.M.pedestal.x
				game.P.y = game.groundAt(game.P.x)
				key(KEY_UP, true)
				get_tree().create_timer(0.05).timeout.connect(func(): key(KEY_UP, false))
			"walk":
				key(KEY_RIGHT, true)
				get_tree().create_timer(s[2]).timeout.connect(func(): key(KEY_RIGHT, false))
			"skill":
				var near = null
				for e in game.slimes:
					if e.state != "dead" and (near == null or absf(e.x - game.P.x) < absf(near.x - game.P.x)):
						near = e
				if near != null:
					game.P.x = near.x - 60
					game.P.y = near.y + 4
					game.P.face = 1
				game.P.en = 100
				print("useSkill ", s[2], " -> ", game.useSkill(s[2]))
			"cards":
				for k in ["toad", "seagull", "bass", "crab", "shark", "squid", "orca", "octopus"]:
					game.save.bestiary[k] = {"kills": 3, "shiny": 1 if k in ["toad", "orca"] else 0}
				game.save.cards.toad = {"n": true, "sg": true}
				game.save.cards.squid = {"ng": true}
				game.save.cards.orca = {"n": true, "s": true}
				game.save.cards.dreamer = {"n": true, "ng": true}
				game.save.mats.shark = 12
			"tab": game.openTab(s[2])
			"scroll": game.scrollBy("panel", s[2])
			"reload":
				game.persist()
				var sv = game.loadSave()
				print("reloaded: keyItems=%s trophies=%s devour=%s" % [sv.get("keyItems"), sv.trophies, sv.chars.rock.skills.has("devour")])
			"quit":
				print("done; quitting")
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, shots, name])
	shots += 1
	var P = game.P
	var b = _boss()
	print("shot %s map=%s state=%s pos=%.0f,%.0f vy=%.0f hp=%d/%d abyss=%.0f/%.0fs drain=%.2f held=%s mobs=%d boss=%s scene=%s loot=%s" % [name, game.mapId, P.state, P.x, P.y, P.vy, P.hp, game.PS.hp,
		P.abyssB, P.abyssT, P.abyssDrain, P.held.kind if P.held != null else "-", game.slimes.size(), ("%s %d" % [b.data.get("act", ""), b.hp]) if b != null else "-", game.scene != null, game.loot != null])
	busy = false
