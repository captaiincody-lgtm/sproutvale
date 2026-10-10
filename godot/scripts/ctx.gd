extends RefCounted
## A small stand-in for the browser's 2D canvas API, drawing through a Godot CanvasItem.
## The prototype painted its effects, furniture, bosses and story scenes with canvas calls
## (fillRect, arc, fill, stroke, gradients…). Keeping the same calls here lets that drawing code
## be ported line for line. Colours may be given as CSS strings ("#ffd35a", "rgba(255,0,0,0.5)").

var ci: CanvasItem
var _fill: Variant = Color.WHITE        # Color or Grad
var _stroke: Variant = Color.BLACK
var lineWidth := 1.0
var globalAlpha := 1.0
var textAlign := "left"
var textBaseline := "alphabetic"
var globalCompositeOperation := "source-over"
var lineDashOffset := 0.0
var lineJoin := "miter"
var imageSmoothingEnabled := false
var tint := Color.WHITE                 # multiplied into every image drawn (not part of Canvas2D: a Lunar monster's glow)
var xf := Transform2D.IDENTITY          # the current transform, relative to `base`
var base := Transform2D.IDENTITY        # what setTransform resets to
var _font_size := 8.0
var _font_px := true
var _font_str := "8px px"
var _dash: Array = []
var _clip = null                        # Rect2 in base space, from clip() on a rect path
var _stack: Array = []
var _paths: Array = []                  # [{pts: PackedVector2Array (base space), closed: bool}]
var _sent := Transform2D(Vector2(INF, 0), Vector2.ZERO, Vector2.ZERO)

static var _css_cache := {}
static var _font_cache := {}

var fillStyle:
	set(v):
		_fill = css(v) if v is String else v
	get:
		return _fill

var strokeStyle:
	set(v):
		_stroke = css(v) if v is String else v
	get:
		return _stroke

var font:
	set(v):
		_font_str = v
		if not _font_cache.has(v):
			var m = RegEx.create_from_string("([0-9.]+)px").search(v)
			_font_cache[v] = [float(m.get_string(1)) if m else 8.0, v.find("Press Start") >= 0 or v.find("monospace") >= 0]
		_font_size = _font_cache[v][0]
		_font_px = _font_cache[v][1]
	get:
		return _font_str


func _init(item: CanvasItem = null) -> void:
	ci = item


## Point the context at a CanvasItem for this frame and reset its state.
func begin(item: CanvasItem, base_xf := Transform2D.IDENTITY) -> void:
	ci = item
	base = base_xf
	xf = Transform2D.IDENTITY
	_stack.clear()
	_paths.clear()
	globalAlpha = 1.0
	tint = Color.WHITE
	lineWidth = 1.0
	_fill = Color.WHITE
	_stroke = Color.BLACK
	textAlign = "left"
	textBaseline = "alphabetic"
	globalCompositeOperation = "source-over"
	_dash = []
	_clip = null
	_sent = Transform2D(Vector2(INF, 0), Vector2.ZERO, Vector2.ZERO)


# ------------------------------------------------------------------ colours

static func css(s: String) -> Color:
	if _css_cache.has(s):
		return _css_cache[s]
	var c = Color.WHITE
	var t = s.strip_edges()
	if t.begins_with("#"):
		c = Color.html(t)
	elif t.begins_with("rgb"):
		var inner = t.substr(t.find("(") + 1)
		inner = inner.substr(0, inner.find(")"))
		var p = inner.split(",")
		c = Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, float(p[3]) if p.size() > 3 else 1.0)
	elif t == "transparent":
		c = Color(0, 0, 0, 0)
	else:
		c = Color.from_string(t, Color.WHITE)
	if _css_cache.size() < 4000:
		_css_cache[s] = c
	return c


class Grad:
	var radial = false
	var p0 = Vector2.ZERO
	var p1 = Vector2.ZERO
	var r0 = 0.0
	var r1 = 0.0
	var stops: Array = []      # [[offset, Color]], sorted

	func addColorStop(o: float, c) -> void:
		stops.append([clampf(o, 0, 1), Ctx_css(c)])
		stops.sort_custom(func(a, b): return a[0] < b[0])

	static func Ctx_css(c) -> Color:
		return (load("res://scripts/ctx.gd").css(c)) if c is String else c

	func at(t: float) -> Color:
		if stops.is_empty():
			return Color(0, 0, 0, 0)
		if t <= stops[0][0]:
			return stops[0][1]
		for i in range(1, stops.size()):
			if t <= stops[i][0]:
				var a = stops[i - 1]
				var b = stops[i]
				var span: float = b[0] - a[0]
				return a[1] if span <= 0.00001 else (a[1] as Color).lerp(b[1], (t - a[0]) / span)
		return stops[-1][1]


func createLinearGradient(x0: float, y0: float, x1: float, y1: float) -> Grad:
	var g = Grad.new()
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	return g


func createRadialGradient(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float) -> Grad:
	var g = Grad.new()
	g.radial = true
	g.p0 = Vector2(x0, y0)
	g.p1 = Vector2(x1, y1)
	g.r0 = r0
	g.r1 = r1
	return g


func _a(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * globalAlpha)


# ------------------------------------------------------------------ state and transforms

func save() -> void:
	_stack.append([xf, _fill, _stroke, lineWidth, globalAlpha, _font_str, textAlign, textBaseline, globalCompositeOperation, _dash, _clip, lineJoin])


func restore() -> void:
	if _stack.is_empty():
		return
	var s: Array = _stack.pop_back()
	xf = s[0]; _fill = s[1]; _stroke = s[2]; lineWidth = s[3]; globalAlpha = s[4]; font = s[5]
	textAlign = s[6]; textBaseline = s[7]; globalCompositeOperation = s[8]; _dash = s[9]; _clip = s[10]; lineJoin = s[11]


func translate(x: float, y: float) -> void:
	xf = xf * Transform2D(0.0, Vector2(x, y))


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func scale(sx: float, sy: float) -> void:
	xf = xf * Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2.ZERO)


func setTransform(a: float, b: float, c: float, d: float, e: float, f: float) -> void:
	xf = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(e, f))


func resetTransform() -> void:
	xf = Transform2D.IDENTITY


func setLineDash(d: Array) -> void:
	_dash = d.duplicate()


func _use(m: Transform2D) -> void:
	if m != _sent:
		ci.draw_set_transform_matrix(base * m)
		_sent = m


## how much the current transform scales lengths (for line widths and curve detail)
func _k() -> float:
	return sqrt(absf(xf.determinant()))


# ------------------------------------------------------------------ paths (kept in transformed space)

func beginPath() -> void:
	_paths.clear()


func _cur() -> Dictionary:
	if _paths.is_empty() or _paths[-1].closed:
		var start = PackedVector2Array()
		if not _paths.is_empty() and _paths[-1].closed and _paths[-1].pts.size() > 0:
			start.append(_paths[-1].pts[0])
		_paths.append({"pts": start, "closed": false})
	return _paths[-1]


func moveTo(x: float, y: float) -> void:
	_paths.append({"pts": PackedVector2Array([xf * Vector2(x, y)]), "closed": false})


func lineTo(x: float, y: float) -> void:
	_cur().pts.append(xf * Vector2(x, y))


func closePath() -> void:
	if not _paths.is_empty():
		_paths[-1].closed = true


func rect(x: float, y: float, w: float, h: float) -> void:
	_paths.append({"pts": PackedVector2Array([xf * Vector2(x, y), xf * Vector2(x + w, y), xf * Vector2(x + w, y + h), xf * Vector2(x, y + h)]), "closed": true})


func roundRect(x: float, y: float, w: float, h: float, r: float = 0.0) -> void:
	r = minf(r, minf(absf(w), absf(h)) / 2)
	moveTo(x + r, y)
	arc(x + w - r, y + r, r, -PI / 2, 0)
	arc(x + w - r, y + h - r, r, 0, PI / 2)
	arc(x + r, y + h - r, r, PI / 2, PI)
	arc(x + r, y + r, r, PI, PI * 1.5)
	closePath()


func arc(cx: float, cy: float, r: float, a0: float, a1: float, ccw := false) -> void:
	ellipse(cx, cy, r, r, 0.0, a0, a1, ccw)


func ellipse(cx: float, cy: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw := false) -> void:
	var span: float
	if not ccw:
		span = a1 - a0
		if span >= TAU:
			span = TAU
		else:
			span = fposmod(span, TAU)
			if span == 0.0 and a1 != a0:
				span = TAU
	else:
		span = a0 - a1
		if span >= TAU:
			span = TAU
		else:
			span = fposmod(span, TAU)
			if span == 0.0 and a1 != a0:
				span = TAU
		span = -span
	var rr = maxf(absf(rx), absf(ry)) * _k()
	var n = clampi(ceili(absf(span) * maxf(rr, 1.0) / 3.0), 3, 64)
	var c = _cur()
	var rm = Transform2D(rot, Vector2(cx, cy))
	for i in n + 1:
		var a: float = a0 + span * i / n
		c.pts.append(xf * (rm * Vector2(cos(a) * rx, sin(a) * ry)))


func quadraticCurveTo(cpx: float, cpy: float, x: float, y: float) -> void:
	var c = _cur()
	var p0: Vector2 = c.pts[-1] if c.pts.size() else xf * Vector2(cpx, cpy)
	var p1 = xf * Vector2(cpx, cpy)
	var p2 = xf * Vector2(x, y)
	var n = clampi(ceili((p0.distance_to(p1) + p1.distance_to(p2)) / 4.0), 4, 24)
	for i in range(1, n + 1):
		var t = float(i) / n
		c.pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))


func bezierCurveTo(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	var c = _cur()
	var p0: Vector2 = c.pts[-1] if c.pts.size() else xf * Vector2(c1x, c1y)
	var p1 = xf * Vector2(c1x, c1y)
	var p2 = xf * Vector2(c2x, c2y)
	var p3 = xf * Vector2(x, y)
	var n = clampi(ceili((p0.distance_to(p1) + p1.distance_to(p2) + p2.distance_to(p3)) / 4.0), 6, 40)
	for i in range(1, n + 1):
		var t = float(i) / n
		c.pts.append(p0.bezier_interpolate(p1, p2, p3, t))


func clip() -> void:
	# only rectangular clips are supported (the summoner's TV screen); they limit fillRect
	if _paths.size() and _paths[-1].pts.size() == 4:
		var p: PackedVector2Array = _paths[-1].pts
		var r = Rect2(p[0], Vector2.ZERO)
		for q in p:
			r = r.expand(q)
		_clip = r


static func _clean(pts: PackedVector2Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[-1].distance_squared_to(p) > 0.0001:
			out.append(p)
	if out.size() > 2 and out[0].distance_squared_to(out[-1]) < 0.0001:
		out.remove_at(out.size() - 1)
	return out


func _tri(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var idx = Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		for i in range(1, pts.size() - 1):
			idx.append_array([0, i, i + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


func fill() -> void:
	_use(Transform2D.IDENTITY)
	for sp in _paths:
		var pts = _clean(sp.pts)
		if pts.size() < 3:
			continue
		if _fill is Grad and _fill.radial:
			_radial_fill(_fill, pts)
			continue
		var cols = PackedColorArray()
		cols.resize(pts.size())
		if _fill is Grad:
			for i in pts.size():
				cols[i] = _a(_grad_at(_fill, pts[i]))
		else:
			cols.fill(_a(_fill))
		_tri(pts, cols)


func stroke() -> void:
	_use(Transform2D.IDENTITY)
	var col: Color = _a(_stroke if _stroke is Color else (_stroke as Grad).at(0.5))
	var w = lineWidth * _k()
	for sp in _paths:
		var pts: PackedVector2Array = sp.pts.duplicate()
		if sp.closed and pts.size() > 1:
			pts.append(pts[0])
		if pts.size() < 2:
			continue
		if _dash.size() >= 2:
			_dashed(pts, col, w)
		else:
			ci.draw_polyline(pts, col, w, false)


func _dashed(pts: PackedVector2Array, col: Color, w: float) -> void:
	var k = _k()
	var on: float = _dash[0] * k
	var off: float = _dash[1] * k
	var period = on + off
	var pos = fposmod(-lineDashOffset * k, period)
	for i in pts.size() - 1:
		var a = pts[i]
		var b = pts[i + 1]
		var L = a.distance_to(b)
		var d = 0.0
		while d < L:
			var ph = fposmod(pos + d, period)
			var step = (on - ph) if ph < on else (period - ph)
			var e = minf(L, d + step)
			if ph < on:
				ci.draw_line(a.lerp(b, d / L), a.lerp(b, e / L), col, w)
			d = e + 0.0001
		pos += L


func _grad_at(g: Grad, p: Vector2) -> Color:
	var a = xf * g.p0
	var b = xf * g.p1
	var ab = b - a
	var L2 = ab.length_squared()
	var t = 0.0 if L2 == 0.0 else (p - a).dot(ab) / L2
	return g.at(t)


func _radial_fill(g: Grad, _pts: PackedVector2Array) -> void:
	var c = xf * g.p1
	var k = _k()
	var stops = g.stops
	if stops.is_empty():
		return
	var radii: Array = []
	var cols: Array = []
	if g.r0 > 0:
		radii.append(0.0); cols.append(stops[0][1])
	for s in stops:
		radii.append((g.r0 + (g.r1 - g.r0) * s[0]) * k)
		cols.append(s[1])
	for i in radii.size() - 1:
		_ring(c, radii[i], radii[i + 1], _a(cols[i]), _a(cols[i + 1]))
	var last: Color = cols[-1]
	if last.a > 0.01:   # an opaque outer stop (a vignette): carry it out past the corners
		_ring(c, radii[-1], radii[-1] + 2000.0, _a(last), _a(last))


func _ring(c: Vector2, ra: float, rb: float, ca: Color, cb: Color) -> void:
	if rb <= ra:
		return
	var n = clampi(ceili(rb / 2.0), 16, 64)
	var pts = PackedVector2Array()
	var cols = PackedColorArray()
	var idx = PackedInt32Array()
	for i in n + 1:
		var a = TAU * i / n
		var d = Vector2(cos(a), sin(a))
		pts.append(c + d * ra); cols.append(ca)
		pts.append(c + d * rb); cols.append(cb)
	for i in n:
		var j = i * 2
		idx.append_array([j, j + 1, j + 2, j + 1, j + 3, j + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


# ------------------------------------------------------------------ rectangles

func fillRect(x: float, y: float, w: float, h: float) -> void:
	if w < 0:
		x += w; w = -w
	if h < 0:
		y += h; h = -h
	if w == 0 or h == 0:
		return
	if _fill is Grad or _clip != null or xf.get_rotation() != 0.0:
		var saved = _paths
		_paths = []
		rect(x, y, w, h)
		if _clip != null:
			var r = Rect2(_paths[0].pts[0], Vector2.ZERO)
			for q in _paths[0].pts:
				r = r.expand(q)
			r = r.intersection(_clip)
			if r.size.x <= 0 or r.size.y <= 0:
				_paths = saved
				return
			_paths = [{"pts": PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), "closed": true}]
		if _fill is Grad and not _fill.radial and _clip == null:
			_lin_rect(_fill, x, y, w, h)
		else:
			fill()
		_paths = saved
		return
	_use(xf)
	ci.draw_rect(Rect2(x, y, w, h), _a(_fill))


## a linear gradient over a rectangle, split into bands so every colour stop shows
func _lin_rect(g: Grad, x: float, y: float, w: float, h: float) -> void:
	_use(xf)
	var vertical = absf(g.p1.x - g.p0.x) < 0.001
	var horizontal = absf(g.p1.y - g.p0.y) < 0.001
	if not vertical and not horizontal:
		var pts = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		var cols = PackedColorArray()
		for p in pts:
			var ab = g.p1 - g.p0
			cols.append(_a(g.at((p - g.p0).dot(ab) / maxf(0.0001, ab.length_squared()))))
		ci.draw_polygon(pts, cols)
		return
	var a0: float = g.p0.y if vertical else g.p0.x
	var a1: float = g.p1.y if vertical else g.p1.x
	var lo: float = y if vertical else x
	var hi: float = (y + h) if vertical else (x + w)
	var cuts: Array = [lo, hi]
	for s in g.stops:
		var c: float = a0 + (a1 - a0) * s[0]
		if c > lo and c < hi:
			cuts.append(c)
	cuts.sort()
	for i in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 <= 0.0001:
			continue
		var t0 = (u0 - a0) / (a1 - a0) if a1 != a0 else 0.0
		var t1 = (u1 - a0) / (a1 - a0) if a1 != a0 else 0.0
		# just inside each band, so a hard stop (two stops at one offset) picks the right side
		var c0 = _a(g.at(t0 + (0.00001 if t1 > t0 else -0.00001)))
		var c1 = _a(g.at(t1 - (0.00001 if t1 > t0 else -0.00001)))
		var pts: PackedVector2Array
		var cols: PackedColorArray
		if vertical:
			pts = PackedVector2Array([Vector2(x, u0), Vector2(x + w, u0), Vector2(x + w, u1), Vector2(x, u1)])
			cols = PackedColorArray([c0, c0, c1, c1])
		else:
			pts = PackedVector2Array([Vector2(u0, y), Vector2(u1, y), Vector2(u1, y + h), Vector2(u0, y + h)])
			cols = PackedColorArray([c0, c1, c1, c0])
		ci.draw_polygon(pts, cols)


func strokeRect(x: float, y: float, w: float, h: float) -> void:
	_use(xf)
	ci.draw_rect(Rect2(x, y, w, h).abs(), _a(_stroke if _stroke is Color else Color.WHITE), false, lineWidth)


func clearRect(_x: float, _y: float, _w: float, _h: float) -> void:
	pass


# ------------------------------------------------------------------ text

func _fnt() -> Font:
	return Assets.font if _font_px else Assets.ui_font


func measureText(s: String) -> Dictionary:
	return {"width": _fnt().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_font_size)).x}


func _text_pos(s: String, x: float, y: float) -> Vector2:
	var f = _fnt()
	var sz = int(_font_size)
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	if textAlign == "center":
		x -= w / 2
	elif textAlign == "right" or textAlign == "end":
		x -= w
	var asc = f.get_ascent(sz)
	var desc = f.get_descent(sz)
	if _font_px:   # the pixel font's em box is all ascent; its glyphs sit on the baseline
		asc = _font_size
		desc = 0
	match textBaseline:
		"top", "hanging":
			y += asc
		"middle":
			y += (asc - desc) / 2.0
		"bottom", "ideographic":
			y -= desc
	return Vector2(x, y)


func fillText(s, x: float, y: float, _max_w: float = -1) -> void:
	s = str(s)
	_use(xf)
	var col: Color = _a(_fill if _fill is Color else (_fill as Grad).at(0.5))
	_fnt().draw_string(ci.get_canvas_item(), _text_pos(s, x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_font_size), col)


func strokeText(s, x: float, y: float) -> void:
	s = str(s)
	_use(xf)
	var col: Color = _a(_stroke if _stroke is Color else Color.BLACK)
	_fnt().draw_string_outline(ci.get_canvas_item(), _text_pos(s, x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_font_size), int(maxf(1, lineWidth)), col)


# ------------------------------------------------------------------ images

## drawImage(tex, dx, dy[, dw, dh]); a silhouette is drawn when the composite op is "source-atop"
## right after it (handled by callers with Assets.silhouette instead).
func drawImage(tex: Texture2D, dx: float, dy: float, dw: float = -1, dh: float = -1) -> void:
	if tex == null:
		return
	if dw < 0:
		dw = tex.get_width()
		dh = tex.get_height()
	_use(xf)
	ci.draw_texture_rect(tex, Rect2(dx, dy, dw, dh), false, Color(tint, globalAlpha))


## the nine-argument drawImage: a source rectangle of `tex` into a destination rectangle
func drawImageRegion(tex: Texture2D, sx: float, sy: float, sw: float, sh: float, dx: float, dy: float, dw: float, dh: float) -> void:
	if tex == null:
		return
	_use(xf)
	ci.draw_texture_rect_region(tex, Rect2(dx, dy, dw, dh), Rect2(sx, sy, sw, sh), Color(tint, globalAlpha))


## frame `f` of a horizontal strip of `n` frames
func drawFrame(tex: Texture2D, n: int, f: int, dx: float, dy: float, dw: float, dh: float, mod := Color.WHITE) -> void:
	if tex == null:
		return
	_use(xf)
	var fw = tex.get_width() / float(maxi(1, n))
	ci.draw_texture_rect_region(tex, Rect2(dx, dy, dw, dh), Rect2(fw * clampi(f, 0, n - 1), 0, fw, tex.get_height()), Color(mod.r * tint.r, mod.g * tint.g, mod.b * tint.b, mod.a * globalAlpha))
