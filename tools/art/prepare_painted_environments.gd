extends SceneTree
const ROOT := "res://art/painted/"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if args.size() else ROOT + "sources/"
	var manifest := {}
	DirAccess.make_dir_recursive_absolute(ROOT + "environments")
	for key in ["hollow", "ridge", "crimson"]:
		for role in ["backdrop", "tile"]:
			var im := Image.load_from_file(source.path_join("env_"+key+"_"+role+".png"))
			if im == null:
				push_error("Missing environment source " + key + "/" + role)
				quit(1)
				return
			if role == "tile":
				im.convert(Image.FORMAT_RGBA8)
				for y in im.get_height():
					for x in im.get_width():
						var pixel := im.get_pixel(x,y)
						if pixel.a < 0.08:
							pixel.a = 0
							im.set_pixel(x,y,pixel)
				im = im.get_region(im.get_used_rect())
				im.resize(512,168,Image.INTERPOLATE_LANCZOS)
			else:
				im.resize(1536,864,Image.INTERPOLATE_LANCZOS)
			var result := im.save_webp(ROOT+"environments/"+key+"_"+role+".webp",true,0.92)
			if result != OK:
				push_error("Environment export failed " + key + "/" + role)
				quit(1)
				return
		var id: String = "crimson1" if key == "crimson" else key
		manifest[id] = {"backdrop":"environments/"+key+"_backdrop.webp","tile":"environments/"+key+"_tile.webp","tile_width":128,"ground_offset":7,"soil":{"hollow":"#26392e","ridge":"#66513a","crimson":"#39242f"}[key]}
		print("Prepared painted region ",id)
	var output := FileAccess.open(ROOT + "environments.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	quit()
