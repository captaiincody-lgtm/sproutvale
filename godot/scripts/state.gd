extends RefCounted
## Plain data holders for the things that move around the world. Field names follow the
## prototype (P.moveT, e.maxHp…) so the ported game code reads the same as the original.


class Player:
	var x := 90.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var hp := 100.0
	var en := 100.0
	var face := 1
	var grounded := true
	var surf = null              # the surface Dictionary we're standing on, or null
	var state := "move"          # move, block, prone, slide, dash, cheer, hurt, knocked, climb, plunge, attack, dead
	var anim := "idle"
	var animT := 0.0
	var jumps := 0
	var airDash := 0
	var airAtk := 0
	var airChain := 0
	var move = null              # the MOVES entry being performed
	var moveId := ""
	var moveT := 0.0
	var lastFrame := -1
	var hitSet := {}
	var queued := false
	var queuedHeavy := false
	var dropT := 0.0
	var rope = null              # {x, y0, y1} while climbing
	var runT := 0.0
	var idleT := 0.0
	var windV := 0.0
	var stepPh := -1
	var crawlPh := -1
	var climbPh := -1
	var breathT := 2.0
	var iframes := 0.0
	var blockT := -9.0
	var hurtT := 0.0
	var deadT := 0.0
	var dashT := 0.0
	var slideT := 0.0
	var cheerT := 0.0
	var cheerQ := false
	var flash := 0.0
	var touchCd := 0.0
	var landT := 0.0
	var flipT := 0.0
	var dodged := {}
	var buf := {}                # input buffer: action → time pressed
	var coyote := -9.0
	var lastJumpT := -9.0
	var lastChain := -1
	var chainEndT := -9.0
	var plungeT := 0.0
	var plungePhase := ""
	var plungeY := 0.0
	var plungeHits := 0
	var regenBoost := 0.0
	var lastHurt := -9.0
	var wet := 0.0
	var pots = null
	var shotCd := 0.0
	var boltCd := 0.0
	var blinkCd := 0.0
	var lastAirShotT := -9.0
	var lastSkillT := -9.0
	var skillLock := 0.0
	var skillTargets = null
	var castAim := ""
	var diveN := 0
	var juggle = null            # the mob we launched, for juggle follow-ups
	var juggleT := 0.0
	var frozen := false
	var grabbed = null           # a mob holding us {e, need, n}
	var poison = null            # {t, dps, tick}
	var bleed = null             # {t, dps, tick}
	var kdT := 0.0
	var kdPhase := ""
	var kdBack := false
	var kdLong := 0.0            # extra time lying on the floor after a bad fall (King Yeti's ceiling throw)
	# the Abyss (Godot-only areas beyond the Warlord's Keep)
	var abyssB := 0.0            # Abyss buildup 0–100; full = the Abyss debuff
	var abyssT := 0.0            # seconds of the Abyss debuff left
	var abyssDrain := 0.0        # share of max HP the Abyss has eaten (up to 0.5)
	var lastBuild := -9.0
	var blindT := 0.0            # Inked: attacks miss more often
	var confuseT := 0.0          # Confused: left and right are swapped
	var tumbleT := 0.0           # knocked off balance: spinning, then floating down
	var tumbleDur := 0.0
	var spin := 0.0
	var spinY := 20.0            # how far above the feet the body turns when it spins (0 = around the feet)
	var held = null              # {e, phase, t…} while a tentacle holds you, or the Dreamer chews on you
	var hurtN := 0               # counts hits that really landed (not dodged, blocked or in god mode)
	# the Attribute Tree
	var shield := 0.0            # energy shield left (soaks up hits before HP)
	var lastStandT := -999.0     # when Last Stand can save you again
	var sureCrit := 0            # Phantom: hits left that are certain to crit
	var critEnT := -9.0          # Lucky Star: last time a crit gave energy back


class Mob:
	var id := 0
	var type := ""
	var T: Dictionary            # its SLIME_TYPES entry (or the boss table)
	var lv := 1
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var surf = null
	var face := 1
	var state := "idle"
	var t := 0.0
	var hp := 1.0
	var maxHp := 1.0
	var atk := 1.0
	var def := 0.0
	var exp := 1.0
	var coinMul := 1.0
	var aggro := false
	var bang := 0.0
	var hopCd := 0.0
	var atkCd := 1.0
	var flash := 0.0
	var sq := 0.0
	var deadT := 0.0
	var spawnT := 0.0
	var hitDone := false
	var hitT := 0.0
	var stun := 0.0
	var showBar := 0.0
	var juggle := 0.0
	var w := 18.0
	var h := 16.0
	var walk := 0.0
	var walkT := 0.0
	var pause := 0.0
	var shiny := false
	var elite := false
	var raid := false
	var noCrit := false
	var target = null
	var move := ""
	var cd := 0.0
	var swished := 0
	var snap := 0
	var jx := 0.0
	var jx0 := 0.0
	var jx1 := 0.0
	var sw := 0.0
	var partner = null
	var homeX := 0.0
	var homeY := 0.0
	var slowT := 0.0
	var burnT := 0.0
	var burnTick := 0.0
	var hurtFlash := 0.0
	# bosses
	var boss := false
	var bossKind := ""
	var act := ""
	var mode := ""
	var enraged := false
	var eyesOut := 0
	var eyeCd := 0.0
	var throwCd := 0.0
	var rainCd := 0.0
	var talkI := 0
	var actN := 0
	var lastAct := ""
	# the warlord's eyes
	var bossEye := false
	var owner = null
	var returning := false
	var life := 0.0
	var dropBlock := false
	var dying := false           # the Warlord on one knee, before he falls
	# the Dreamer's eyes, mouth and tentacles: hits on them hurt the Dreamer
	var bossPart := false
	var partMul := 1.0
	var data := {}               # per-monster AI scratch space for the Abyss monsters

	func clone() -> Mob:
		var m := Mob.new()
		for p in get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				m.set(p.name, get(p.name))
		return m


class Drop:
	var kind := "coin"           # coin, abyss, card or res (a monster's material)
	var type := ""
	var key := ""
	var gold := false
	var shiny := false
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var val := 1
	var t := 0.0
	var surfY := 0.0
	var x0 := 0.0
	var x1 := 0.0
	var spin := 0.0
	var free := false            # dropped in mid-air: lands on whatever platform it falls onto


class Part:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var t := 0.0
	var life := 0.5
	var col := Color.WHITE
	var g := 0.0
	var sz := 1.0
	var floorY := INF

	func _init(px := 0.0, py := 0.0, pvx := 0.0, pvy := 0.0, plife := 0.5, pcol := Color.WHITE, pg := 0.0, psz := 1.0, pfloor := INF) -> void:
		x = px; y = py; vx = pvx; vy = pvy; life = plife; col = pcol; g = pg; sz = psz; floorY = pfloor


class Floater:
	var x := 0.0
	var y := 0.0
	var text := ""
	var kind := "dmg"
	var t := 0.0
	var life := 0.9
