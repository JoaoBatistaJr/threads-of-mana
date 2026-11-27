shader_type spatial;

uniform float tile_size = 6.0;
uniform float rock_tile_size = 8.0;
uniform float rock_slope_start = 0.18;
uniform float rock_slope_end = 0.38;
uniform vec3 rock_tint : source_color = vec3(0.5, 0.5, 0.52);
uniform float variation : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_layers;
varying vec3 v_tint;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v / 0.875;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_layers = CUSTOM0;
	v_tint = COLOR.rgb;
}

void fragment() {
	vec2 uv = v_world_pos.xz;
	float grass = v_layers.r;
	float sand = v_layers.g;
	float snow = v_layers.b;
	float mud = v_layers.a;
	float sum = grass + sand + snow + mud;
	float rest = clamp(1.0 - sum, 0.0, 1.0);

	float p_grass = mix(fbm(uv / tile_size * 2.0), vnoise(uv * 3.0), 0.35);
	float p_sand = vnoise(vec2(uv.x * 1.2, uv.y * 0.35) + fbm(uv * 0.15) * 3.0);
	float p_snow = fbm(uv * 0.35);
	float p_mud = fbm(uv * 0.9 + 7.0);
	float pattern = (p_grass * grass + p_sand * sand + p_snow * snow + p_mud * mud) / max(sum, 0.001);

	float shade = 1.0 + (pattern - 0.5) * variation * (1.0 - 0.6 * snow);
	vec3 ground = v_tint * shade;
	ground *= mix(1.0, 0.75, mud);

	vec3 n = normalize(v_world_normal);
	float slope = 1.0 - n.y;
	float rock_w = clamp(rest + smoothstep(rock_slope_start, rock_slope_end, slope), 0.0, 1.0);

	vec3 w3 = pow(abs(n), vec3(4.0));
	w3 /= (w3.x + w3.y + w3.z);
	float rn = fbm(v_world_pos.zy / rock_tile_size * 2.0) * w3.x
		+ fbm(v_world_pos.xz / rock_tile_size * 2.0) * w3.y
		+ fbm(v_world_pos.xy / rock_tile_size * 2.0) * w3.z;
	float strata = 0.5 + 0.5 * sin(v_world_pos.y * 2.5 + rn * 3.0);
	vec3 rock = rock_tint * (0.75 + 0.5 * rn) * (0.92 + 0.16 * strata);

	ALBEDO = mix(ground, rock, rock_w);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}