class_name ArtLibrary
extends RefCounted
## Cover and label art comes from a folder the launcher watches, so pictures
## can be dropped on the device with a file manager and picked here — no file
## browser, no storage permission dance.
##
## Looked for in, first match wins:
##   /storage/emulated/0/Shelves/art   (Android, where you would put them)
##   user://art                        (works everywhere, including desktop)

const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]

static var _cache: Dictionary = {}


static func folders() -> Array[String]:
	var out: Array[String] = []
	if OS.get_name() == "Android":
		out.append("/storage/emulated/0/Shelves/art")
	out.append(ProjectSettings.globalize_path("user://art"))
	return out


## Every image found, as {path, name}.
static func images() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for folder in folders():
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.get_extension().to_lower() in EXTENSIONS:
				out.append({"path": folder.path_join(file), "name": file.get_basename()})
			file = dir.get_next()
		dir.list_dir_end()
	out.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	return out


## Makes the folder, so there is somewhere obvious to put files.
static func ensure_folder() -> String:
	var path := ProjectSettings.globalize_path("user://art")
	DirAccess.make_dir_recursive_absolute(path)
	return path


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("art: cannot load %s" % path)
		return null
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_cache[path] = tex
	return tex
