class_name LightingNoise
extends RefCounted
## One small tileable noise texture shared by the post and ground shaders (about four soft blobs across): a texture
## read is far cheaper on the GPU than computing noise per pixel, which cost most of the frame on the big map.

const SIZE: int = 256

static var _tex: ImageTexture


static func texture() -> ImageTexture:
	if _tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		n.frequency = 4.0 / SIZE  # about four blobs across
		n.seed = 11
		var img := n.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
		_tex = ImageTexture.create_from_image(img)
	return _tex
