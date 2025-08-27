extends Node
var amplitude: float = 18.0
var path: String = ProjectSettings.get_setting("shader_globals/noise").value
var image: Image = (load(path) as NoiseTexture2D).noise.get_image(512, 512)
var size: int = image.get_width()

func get_height(x,z):
	return image.get_pixel(fposmod(x, size),fposmod(z, size)).r * amplitude
