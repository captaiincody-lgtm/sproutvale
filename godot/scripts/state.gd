extends RefCounted
## Plain data holders for the things that move around the world.


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
	var state := "move"          # move, block, prone, slide, dash, cheer, hurt, climb, plunge, attack, dead
	var anim := "idle"
	var anim_t := 0.0
	var jumps := 0
	var air_dash := 0
	var air_atk := 0
	var move = null              # the MOVES entry being performed
	var move_id := ""
	var move_t := 0.0
	var last_frame := -1
	var hit_set := {}
	var queued := false
	var queued_heavy := false
	var drop_t := 0.0
	var rope = null              # {x, y0, y1} while climbing
	var run_t := 0.0
	var idle_t := 0.0
	var wind_v := 0.0
	var step_ph := -1
	var crawl_ph := -1
	var climb_ph := -1
	var iframes := 0.0
	var block_t := -9.0
	var hurt_t := 0.0
	var dead_t := 0.0
	var dash_t := 0.0
	var slide_t := 0.0
	var cheer_t := 0.0
	var cheer_q := false
	var flash := 0.0
	var touch_cd := 0.0
	var land_t := 0.0
	var dodged := {}
	var buf := {}                # input buffer: action → time pressed
	var coyote := -9.0
	var last_jump_t := -9.0
	var last_chain := -1
	var chain_end_t := -9.0
	var plunge_t := 0.0
	var plunge_phase := ""
	var plunge_y0 := 0.0
	var plunge_hits := 0
	var regen_boost := 0.0
	var last_hurt := -9.0
	var wet := 0.0
	var pots := {"hp": {"n": 3, "t": 0.0}, "sp": {"n": 3, "t": 0.0}}


class Mob:
	var id := 0
	var type := ""
	var T: Dictionary            # its SLIME_TYPES entry
	var lv := 1
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var surf: Dictionary
	var face := 1
	var state := "idle"          # idle, chase, flee, retreat, wind, lunge, charge, spin, shell, recover, hurt, dead
	var t := 0.0
	var hp := 1.0
	var max_hp := 1.0
	var atk := 1.0
	var def := 0.0
	var exp_val := 1.0
	var aggro := false
	var bang := 0.0
	var hop_cd := 0.0
	var atk_cd := 1.0
	var flash := 0.0
	var sq := 0.0
	var dead_t := 0.0
	var spawn_t := 0.0
	var hit_done := false
	var hit_t := 0.0
	var stun := 0.0
	var show_bar := 0.0
	var juggle := 0.0
	var w := 18.0
	var h := 16.0
	var walk := 0.0
	var pause := false
	var shiny := false


class Drop:
	var kind := "coin"           # coin or res (a monster's material)
	var type := ""
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var val := 1
	var t := 0.0
	var surf_y := 0.0
	var x0 := 0.0
	var x1 := 0.0
	var spin := 0.0


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
	var floor_y := INF

	func _init(px := 0.0, py := 0.0, pvx := 0.0, pvy := 0.0, plife := 0.5, pcol := Color.WHITE, pg := 0.0, psz := 1.0, pfloor := INF, pt := 0.0) -> void:
		x = px; y = py; vx = pvx; vy = pvy; life = plife; col = pcol; g = pg; sz = psz; floor_y = pfloor; t = pt


class Floater:
	var x := 0.0
	var y := 0.0
	var text := ""
	var kind := "dmg"
	var t := 0.0
	var life := 0.9
