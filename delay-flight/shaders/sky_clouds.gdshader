shader_type sky;
// Небо: градиент, солнце с ореолом, кучевые облака с самозатенением и «серебряной каймой»,
// перистые полосы, дымка у горизонта. Облака плывут по ветру.

uniform vec3 sky_top : source_color = vec3(0.17, 0.36, 0.74);
uniform vec3 sky_mid : source_color = vec3(0.36, 0.58, 0.88);
uniform vec3 sky_horizon : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.42, 0.47, 0.5);
uniform float cover : hint_range(0.0, 1.0) = 0.56;
uniform float cloud_scale = 1.15;
uniform float wind = 0.0045;
uniform float cirrus_amount : hint_range(0.0, 1.0) = 0.45;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = m * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

float dens(vec2 uv) {
	float base = fbm(uv);
	float detail = fbm(uv * 3.1 + 7.3) * 0.28;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.32, base + detail * (base));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float sun_dot = max(dot(dir, sun), 0.0);

	vec3 col;
	if (h >= 0.0) {
		col = mix(sky_horizon, sky_mid, smoothstep(0.0, 0.25, h));
		col = mix(col, sky_top, smoothstep(0.2, 0.9, h));
	} else {
		col = mix(sky_horizon, ground_color, smoothstep(0.0, 0.25, -h));
	}
	// ореол и диск солнца
	col += LIGHT0_COLOR * (pow(sun_dot, 8.0) * 0.12 + pow(sun_dot, 140.0) * 0.55);
	col += LIGHT0_COLOR * smoothstep(0.9995, 0.9999, sun_dot) * 6.0;

	if (h > 0.0) {
		vec2 drift = vec2(TIME * wind, TIME * wind * 0.35);
		// кучевые на низком ярусе
		float inv = 1.0 / (h + 0.09);
		vec2 uv = dir.xz * inv * cloud_scale + drift;
		float d = dens(uv);
		// самозатенение: плотность в сторону солнца
		vec2 sun_off = normalize(sun.xz + vec2(0.0001)) * 0.07;
		float d_sun = dens(uv + sun_off);
		float d_sun2 = dens(uv + sun_off * 2.6);
		float shade = clamp((d_sun + d_sun2 * 0.7) * 0.8 - d * 0.1, 0.0, 1.0);
		vec3 lit = vec3(1.0, 0.985, 0.95) * (1.0 + 0.25 * sun_dot);
		vec3 dark = vec3(0.52, 0.6, 0.74);
		vec3 ccol = mix(lit, dark, shade * 0.85);
		// серебряная кайма на тонких краях
		float edge = d * (1.0 - smoothstep(0.0, 0.5, d));
		ccol += vec3(1.0, 0.95, 0.85) * edge * 1.1 * pow(sun_dot, 3.0);
		float fade = smoothstep(0.0, 0.2, h);
		col = mix(col, ccol, d * fade);
		// перистые: вытянутые, тонкие
		vec2 cuv = vec2(dir.x * 0.6, dir.z * 2.4) * (1.0 / (h + 0.25)) * 1.4 + drift * 0.6 + 3.0;
		float ci = smoothstep(0.55, 0.9, fbm(cuv * 1.6)) * cirrus_amount * smoothstep(0.08, 0.35, h) * (1.0 - d * 0.7);
		col = mix(col, vec3(1.0, 0.99, 0.97), ci * 0.55);
		// дымка у горизонта
		col = mix(col, sky_horizon, smoothstep(0.22, 0.0, h) * 0.65);
	}
	COLOR = col;
}
