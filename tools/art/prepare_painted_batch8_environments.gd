extends SceneTree
const ROOT := "res://art/painted/"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if args.size() else ROOT + "sources/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"environments.json"))
	for key in ["pond","bone"]:
		for role in (["backdrop","tile"] if key == "pond" else ["backdrop"]):
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
			if im.save_webp(ROOT+"environments/"+key+"_"+role+".webp",true,0.92) != OK:
				push_error("Environment export failed")
				quit(1)
				return
	manifest.pond = {"backdrop":"environments/pond_backdrop.webp","tile":"environments/pond_tile.webp","tile_width":128,"ground_offset":7,"soil":"#344a3b"}
	manifest.crimson2 = {"backdrop":"environments/bone_backdrop.webp","tile":"environments/crimson_tile.webp","tile_width":128,"ground_offset":7,"soil":"#39242f"}
	var output := FileAccess.open(ROOT+"environments.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	print("Prepared Willow Pond and Bone Hollow environments")
	quit()
