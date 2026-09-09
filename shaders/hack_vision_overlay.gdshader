shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float effect_strength = 0.0;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 resolution = vec2(textureSize(screen_texture, 0));
	vec2 centered = (SCREEN_UV - vec2(0.5)) * vec2(resolution.x / resolution.y, 1.0);
	float distance_from_viewer = length(centered);
	float peripheral = smoothstep(0.18, 0.72, distance_from_viewer) * effect_strength;
	float block_size = mix(1.0, 13.0, peripheral);
	vec2 coarse_uv = (floor(SCREEN_UV * resolution / block_size) + 0.5) * block_size / resolution;
	vec3 scene = texture(screen_texture, coarse_uv).rgb;
	vec2 cell = floor(SCREEN_UV * resolution / vec2(8.0, 5.0));
	float grain = hash21(cell + floor(TIME * 17.0));
	float scanline = step(0.84, fract(SCREEN_UV.y * resolution.y / 7.0 + TIME * 4.0));
	float broken_strip = step(0.90, hash21(vec2(floor(SCREEN_UV.y * resolution.y / 16.0), floor(TIME * 5.0))));
	float noise = (grain * 0.72 + scanline * 0.54 + broken_strip * 0.34) * peripheral;
	vec3 blue_noise = vec3(0.05, 0.34, 1.0) * noise + vec3(0.25, 0.08, 0.72) * noise * grain;
	COLOR = vec4(scene + blue_noise, 1.0);
}
