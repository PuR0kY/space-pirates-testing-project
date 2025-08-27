extends Node

var path: String = ProjectSettings.get_setting("shader_globals/noise").value
var amplitude: float = ProjectSettings.get_setting("shader_globals/amplitude").value
var image: Image = (load(path) as NoiseTexture2D).noise.get_image(1024, 1024)
var size: int = image.get_width()

func get_height(x,z):
	return image.get_pixel(fposmod(x, size),fposmod(z, size)).r * amplitude
