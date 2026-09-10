shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float effect_strength = 0.0;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 resolution = vec2(textureSize(screen_texture, 0));
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;

	// Continuous blue interference is composed of fine static and broken
	// horizontal streaks, rather than a radial gradient around the player.
	float noise_time = floor(TIME * 5.0);
	vec2 static_cell = floor(SCREEN_UV * resolution / vec2(4.0, 2.0));
	float grain = hash21(static_cell + vec2(noise_time * 7.0, noise_time * 13.0));
	float row = floor(SCREEN_UV.y * resolution.y / 24.0);
	float segment = floor(SCREEN_UV.x * resolution.x / 96.0);
	// Every 24px row participates. Each row independently chooses which
	// horizontal 96px segments become low-resolution on this time slice.
	float streak_segment = step(0.40, hash21(vec2(segment, row + noise_time * 3.17)));
	float streak = streak_segment;
	// The blue streaks themselves are the only low-resolution regions.
	float streak_block_size = 24.0;
	vec2 streak_uv = (floor(SCREEN_UV * resolution / streak_block_size) + 0.5) * streak_block_size / resolution;
	vec3 pixelated_streak_scene = texture(screen_texture, streak_uv).rgb;
	scene = mix(scene, pixelated_streak_scene, streak * effect_strength);
	// Keep the blue tint present, but make the resolution loss the dominant
	// obstruction rather than an additive blue wash.
	float noise = (grain * 0.045 + streak * (0.16 + 0.08 * grain)) * effect_strength;
	vec3 blue_noise = vec3(0.05, 0.28, 0.82) * noise + vec3(0.15, 0.04, 0.46) * noise * grain;
	COLOR = vec4(scene + blue_noise, 1.0);
}
