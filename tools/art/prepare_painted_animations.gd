extends SceneTree
const ROOT := "res://art/painted/"
const BATCH := [
	{"file":"rock_locomotion", "kind":"hero", "xs":[0,319,635,950,1254], "ys":[0,340,660,940,1254], "rows":[
		{"name":"idle", "heights":[44,44,44,44]},
		{"name":"walk", "heights":[44,44,44,44]},
		{"name":"run", "heights":[43,40,43,40]},
		{"name":"jump", "heights":[34,36,40,44]}]},
	{"file":"rock_combat", "kind":"hero", "xs":[0,384,768,1210,1536], "ys":[0,275,560,785,1024], "rows":[
		{"name":"slash", "heights":[48,45,43,42]},
		{"name":"heavy", "heights":[58,50,46,36]},
		{"name":"dash", "heights":[36,29,31,40]},
		{"name":"block", "heights":[44,44,44,44]}]},
	{"file":"green_slime_cycles", "kind":"slime", "xs":[0,320,640,950,1254], "ys":[0,320,650,950,1254], "rows":[
		{"name":"idle", "heights":[22,24,22,20]},
		{"name":"hop", "heights":[12,32,24,12]},
		{"name":"hurt", "heights":[22,16,20,22]},
		{"name":"dead", "heights":[12,8,5,2]}]}
]

func _initialize() -> void:
	var manifest := {"version":1,"hero":{},"slime":{}}
	for sheet in BATCH:
		var image := Image.load_from_file(ROOT + "sources/" + sheet.file + ".png")
		if image == null:
			push_error("Missing animation source: " + sheet.file)
			quit(1)
			return
		var frame_w := 336 if sheet.kind == "hero" else 176
		var frame_h := 304 if sheet.kind == "hero" else 144
		var foot := Vector2i(160,264) if sheet.kind == "hero" else Vector2i(88,132)
		for row in 4:
			var spec: Dictionary = sheet.rows[row]
			var strip := Image.create_empty(frame_w * 4, frame_h, false, Image.FORMAT_RGBA8)
			var regions := []
			for column in 4:
				var x0: int = sheet.xs[column]
				var y0: int = sheet.ys[row]
				var x1: int = sheet.xs[column + 1]
				var y1: int = sheet.ys[row + 1]
				var cell := image.get_region(Rect2i(x0,y0,x1-x0,y1-y0))
				cell.convert(Image.FORMAT_RGBA8)
				# Remove nearly transparent fringe before deriving the bounds and foot anchor.
				for y in cell.get_height():
					for x in cell.get_width():
						var pixel := cell.get_pixel(x,y)
						if pixel.a < 0.08:
							pixel.a = 0
							cell.set_pixel(x,y,pixel)
				var bounds := cell.get_used_rect()
				if bounds.size.x < 4 or bounds.size.y < 2:
					push_error("Empty animation cell: %s %d %d" % [sheet.file,row,column])
					quit(1)
					return
				# Use the lowest solid portion of the sprite as the ground anchor.
				var sum_x := 0.0
				var weight := 0.0
				var bottom_band := maxi(2, roundi(bounds.size.y * 0.08))
				for y in range(bounds.end.y - bottom_band, bounds.end.y):
					for x in range(bounds.position.x, bounds.end.x):
						var alpha := cell.get_pixel(x,y).a
						if alpha > 0.35:
							sum_x += x * alpha
							weight += alpha
				var anchor_x: float = sum_x / weight if weight > 0 else bounds.get_center().x
				var cropped := cell.get_region(bounds)
				var ratio: float = minf(float(spec.heights[column]) * 4 / bounds.size.y, float(frame_w - 12) / bounds.size.x)
				var width := maxi(1, roundi(bounds.size.x * ratio))
				var height := maxi(1, roundi(bounds.size.y * ratio))
				cropped.resize(width,height,Image.INTERPOLATE_LANCZOS)
				var dx := clampi(foot.x - roundi((anchor_x - bounds.position.x) * ratio), 0, frame_w - width)
				var dy := foot.y - height
				strip.blend_rect(cropped,Rect2i(0,0,width,height),Vector2i(column*frame_w+dx,dy))
				regions.append([x0+bounds.position.x,y0+bounds.position.y,bounds.size.x,bounds.size.y])
			var folder: String = "rock" if sheet.kind == "hero" else "green"
			DirAccess.make_dir_recursive_absolute(ROOT + "animations/" + folder)
			var relative: String = "animations/" + folder + "/" + spec.name + ".webp"
			var result := strip.save_webp(ROOT + relative,true,0.9)
			if result != OK:
				push_error("Could not save " + relative)
				quit(1)
				return
			var fps: float = 6 if spec.name == "idle" else (10 if spec.name == "walk" else 12)
			manifest[sheet.kind][spec.name] = {"path":relative,"frames":4,"fps":fps,"width":frame_w,"height":frame_h,"scale":4,"foot":[foot.x,foot.y],"source":sheet.file,"regions":regions}
			print("Prepared ",relative)
	var output := FileAccess.open(ROOT + "animations.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	quit()




