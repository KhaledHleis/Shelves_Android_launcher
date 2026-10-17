class_name IconColors
extends RefCounted
## Pulls a vivid colour and a dark companion out of an app icon.
##
## Used for the default cover tint and for the background gradient, so an app
## looks right with no setup at all. v0.4 lets the user override both.

static var _cache: Dictionary = {}


## Returns [vivid, deep].
static func pair(tex: Texture2D, key: String = "") -> Array:
	if not key.is_empty() and _cache.has(key):
		return _cache[key]
	var result := [Style.ACCENT, Style.BG_MID]
	if tex != null:
		var img := tex.get_image()
		if img != null:
			result = _extract(img)
	if not key.is_empty():
		_cache[key] = result
	return result


static func _extract(src: Image) -> Array:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)

	var best := Color(0, 0, 0)
	var best_score := -1.0
	var sum := Vector3.ZERO
	var count := 0

	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			if c.a < 0.45:
				continue
			count += 1
			sum += Vector3(c.r, c.g, c.b)
			# favour saturated, mid-bright pixels over white or near-black ones
			var score: float = c.s * (1.0 - absf(c.v - 0.7))
			if score > best_score:
				best_score = score
				best = c

	if count == 0:
		return [Style.ACCENT, Style.BG_MID]

	var avg := Color(sum.x / count, sum.y / count, sum.z / count)
	var vivid := best
	if vivid.s < 0.12:
		# a grey icon: lean on the average rather than a random grey pixel
		vivid = avg
	vivid = Color.from_hsv(vivid.h, clampf(vivid.s, 0.35, 0.95), clampf(vivid.v, 0.55, 1.0))
	var deep := Color.from_hsv(fposmod(vivid.h + 0.04, 1.0), clampf(vivid.s * 0.9, 0.3, 0.9), 0.22)
	return [vivid, deep]
