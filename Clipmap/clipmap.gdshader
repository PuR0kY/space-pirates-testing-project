shader_type spatial;

global uniform sampler2D noise;
global uniform sampler2D normalmap;
global uniform float amplitude;
varying vec2 texture_position;

void vertex() {
	vec3 world_vertex = VERTEX + MODEL_MATRIX[3].xyz;
	texture_position = (world_vertex.xz + 0.5)/float(textureSize(noise, 0).x);
	VERTEX.y = texture(noise, texture_position).r * amplitude; // Can be as global too!
}

void fragment() {
	NORMAL_MAP = texture(normalmap, texture_position).rgb;
	ALBEDO = vec3(.25,.20,.20);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
