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

	# Bucket the pixels into a handful of representative colours, keeping how
	# much of the icon each one covers.
	var buckets: Dictionary = {}
	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			if c.a < 0.45:
				continue
			var key := "%d_%d_%d" % [int(c.h * 12.0), int(c.s * 3.0), int(c.v * 4.0)]
			if buckets.has(key):
				var entry: Array = buckets[key]
				entry[0] += 1
				entry[1] += Vector3(c.r, c.g, c.b)
			else:
				buckets[key] = [1, Vector3(c.r, c.g, c.b)]
	if buckets.is_empty():
		return [Style.ACCENT, Style.BG_MID]

	var candidates: Array = []
	for key in buckets:
		var entry: Array = buckets[key]
		var count: int = entry[0]
		var sum: Vector3 = entry[1]
		candidates.append({
			"color": Color(sum.x / count, sum.y / count, sum.z / count),
			"weight": float(count) / 256.0,
		})
	candidates.sort_custom(func(a, b): return a["weight"] > b["weight"])
	if candidates.size() > 10:
		candidates = candidates.slice(0, 10)

	# Score every pair: a background wants two colours that are clearly
	# different from each other and both present in the art. Hue distance and
	# lightness distance carry it; coverage only breaks ties, which is why the
	# two most common colours — often two shades of the same thing — lose.
	var best_a: Color = candidates[0]["color"]
	var best_b: Color = candidates[0]["color"].darkened(0.7)
	var best_score := -1.0
	for i in candidates.size():
		for j in range(i + 1, candidates.size()):
			var ca: Color = candidates[i]["color"]
			var cb: Color = candidates[j]["color"]
			var hue_gap: float = absf(ca.h - cb.h)
			hue_gap = minf(hue_gap, 1.0 - hue_gap) * 2.0        # 0..1
			var value_gap: float = absf(ca.v - cb.v)
			var sat: float = (ca.s + cb.s) * 0.5
			var coverage: float = candidates[i]["weight"] + candidates[j]["weight"]
			var score: float = hue_gap * 1.1 + value_gap * 1.3 + sat * 0.5 + coverage * 0.35
			if score > best_score:
				best_score = score
				# The lighter one leads; the darker becomes the deep end.
				if ca.v >= cb.v:
					best_a = ca
					best_b = cb
				else:
					best_a = cb
					best_b = ca

	# A single-colour icon still needs two ends to the gradient.
	if absf(best_a.v - best_b.v) < 0.12 and absf(best_a.h - best_b.h) < 0.05:
		best_b = Color.from_hsv(fposmod(best_a.h + 0.5, 1.0),
			clampf(best_a.s, 0.3, 0.9), 0.22)

	var vivid := Color.from_hsv(best_a.h, clampf(best_a.s, 0.35, 0.95),
		clampf(best_a.v, 0.55, 1.0))
	var deep := Color.from_hsv(best_b.h, clampf(best_b.s, 0.25, 0.9),
		clampf(best_b.v * 0.45, 0.10, 0.32))
	return [vivid, deep]
