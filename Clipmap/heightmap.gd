extends Node
var path: Dictionary = ProjectSettings.get_setting("shader_globals/noise")
var amplitude: float = 8.0
var image: Image = load(path["value"]).get_image()
var size: int = image.get_width()

func get_height(x,z):
	return image.get_pixel(fposmod(x, size),fposmod(z, size)).r * amplitude
