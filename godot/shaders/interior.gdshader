shader_type spatial;
render_mode cull_back;
// «Квартира за окном»: interior mapping. Стекло — плоский квад с UV 0..1,
// за ним рисуется комната глубиной room_depth. Цвет вершины кодирует вариацию:
// r — случайное зерно комнаты, g — горит свет (0/1), b — оттенок штор.

uniform float room_depth = 2.2;
uniform vec3 light_color : source_color = vec3(1.0, 0.78, 0.5);

varying vec3 v_tangent_view;
varying vec4 v_col;

float hash(float n) { return fract(sin(n) * 43758.5453); }

vec3 palette_wall(float s) {
	int i = int(floor(s * 6.0));
	if (i == 0) return vec3(0.78, 0.7, 0.52);  // бежевые обои
	if (i == 1) return vec3(0.55, 0.66, 0.52); // зелёные
	if (i == 2) return vec3(0.6, 0.66, 0.78);  // голубые
	if (i == 3) return vec3(0.8, 0.62, 0.55);  // розоватые
	if (i == 4) return vec3(0.82, 0.8, 0.7);   // светлые
	return vec3(0.7, 0.6, 0.45);               // охра
}

vec3 wallpaper(vec2 p, float s) {
	vec3 base = palette_wall(s);
	float stripes = smoothstep(0.4, 0.5, abs(fract(p.x * 6.0 + s * 3.0) - 0.5));
	vec2 q = fract(p * vec2(6.0, 8.0)) - 0.5;
	float dots = 1.0 - smoothstep(0.08, 0.12, length(q));
	float kind = hash(s * 17.0);
	float pat = kind < 0.5 ? stripes : dots;
	return base * (0.92 + 0.12 * pat);
}

vec3 carpet(vec2 p, float s) {
	// Ковёр на стене: бордово-красный с орнаментом и каймой
	vec3 red = mix(vec3(0.5, 0.08, 0.1), vec3(0.35, 0.12, 0.25), hash(s * 5.0));
	vec2 c = abs(p - 0.5);
	float border = step(0.42, max(c.x, c.y));
	float rhomb = step(abs(fract((c.x + c.y) * 4.0) - 0.5), 0.12);
	float center = 1.0 - step(0.18, c.x + c.y);
	vec3 col = red;
	col = mix(col, vec3(0.85, 0.7, 0.35), rhomb * 0.6);
	col = mix(col, vec3(0.1, 0.12, 0.3), center * 0.8);
	col = mix(col, vec3(0.15, 0.05, 0.05), border);
	return col;
}

void vertex() {
	v_col = COLOR;
	vec3 view_dir = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz - VERTEX;
	// в пространство квада: TANGENT — вдоль U, BINORMAL — вдоль V, NORMAL — наружу
	v_tangent_view = vec3(dot(view_dir, TANGENT), dot(view_dir, BINORMAL), dot(view_dir, NORMAL));
}

void fragment() {
	float seed = v_col.r;
	float lit = v_col.g;
	vec3 rd = normalize(-v_tangent_view);  // луч внутрь комнаты (z < 0)
	vec3 ro = vec3(UV.x, 1.0 - UV.y, 0.0);
	// Комната шире и выше окна: окно в середине наружной стены
	vec3 bmin = vec3(-0.75, -0.55, -room_depth);
	vec3 bmax = vec3(1.75, 1.35, 0.0);
	vec3 inv = 1.0 / rd;
	float tx = rd.x > 0.0 ? (bmax.x - ro.x) * inv.x : (bmin.x - ro.x) * inv.x;
	float ty = rd.y > 0.0 ? (bmax.y - ro.y) * inv.y : (bmin.y - ro.y) * inv.y;
	float tz = (bmin.z - ro.z) * inv.z;
	float t = min(min(tx, ty), tz);
	vec3 hit = ro + rd * t;
	vec3 q = (hit - bmin) / (bmax - bmin);  // 0..1 внутри комнаты
	vec3 col;
	float shade = 1.0;
	float furn = hash(seed * 31.0);
	if (t == tz) {
		// Задняя стена: обои, ковёр или «стенка», диван
		vec2 p = q.xy;
		col = wallpaper(p * vec2(2.0, 1.4), seed);
		vec2 cr = (p - vec2(0.3, 0.42)) / vec2(0.4, 0.35);
		if (furn < 0.5 && cr.x > 0.0 && cr.x < 1.0 && cr.y > 0.0 && cr.y < 1.0) col = carpet(cr, seed);
		if (furn >= 0.5 && p.y < 0.72 && p.x > 0.08 && p.x < 0.7) {
			// «Стенка»: полированный шкаф с секциями и стеклянной витриной
			float cell = fract(p.x * 6.0);
			col = vec3(0.3, 0.17, 0.09) * (0.85 + 0.15 * step(0.5, cell));
			if (p.y > 0.4 && p.y < 0.6 && cell > 0.1 && cell < 0.9) col = vec3(0.55, 0.52, 0.45) * (0.8 + 0.4 * step(0.6, fract(p.x * 30.0)));
			if (abs(cell - 0.5) > 0.47) col *= 0.6;
		}
		if (furn < 0.5 && p.y < 0.3 && p.x > 0.22 && p.x < 0.78) {
			col = mix(vec3(0.35, 0.3, 0.45), vec3(0.45, 0.35, 0.25), hash(seed * 7.0)); // диван
			if (p.y > 0.2) col *= 1.15;
			if (p.y < 0.05) col *= 0.5;
		}
		// Телевизор на тумбе справа
		if (furn >= 0.5 && p.x > 0.76 && p.x < 0.93) {
			if (p.y < 0.22) col = vec3(0.35, 0.22, 0.12);
			else if (p.y < 0.4) col = (p.x > 0.78 && p.x < 0.91 && p.y > 0.24 && p.y < 0.38) ? vec3(0.15, 0.2, 0.25) + lit * vec3(0.1, 0.15, 0.25) : vec3(0.12);
		}
		shade = 0.85;
	} else if (t == ty) {
		if (rd.y < 0.0) {
			// Пол: паркет и половик
			vec2 p = vec2(q.x, q.z) * vec2(10.0, 6.0);
			float plank = step(0.5, fract(p.x + floor(p.y) * 0.5));
			col = mix(vec3(0.42, 0.26, 0.14), vec3(0.5, 0.32, 0.18), plank);
			if (abs(q.x - 0.5) < 0.25 && q.z > 0.25 && q.z < 0.75) col = mix(vec3(0.5, 0.18, 0.15), vec3(0.2, 0.3, 0.45), hash(seed * 3.0));
			shade = 0.7;
		} else {
			// Потолок с люстрой
			col = vec3(0.86, 0.85, 0.8);
			float d = length(vec2(q.x - 0.5, q.z - 0.5) * vec2(2.5, room_depth));
			col += (1.0 - smoothstep(0.08, 0.22, d)) * light_color * 2.5 * lit;
			shade = 0.95;
		}
	} else {
		vec2 p = vec2(q.z, q.y);
		col = wallpaper(p * vec2(1.6, 1.4), seed) * 0.9;
		// Картина или полка на боковой стене
		vec2 pc = abs(p - vec2(0.45, 0.6));
		if (hash(seed * 41.0 + step(0.0, rd.x)) < 0.5 && pc.x < 0.14 && pc.y < 0.1) col = pc.x > 0.12 || pc.y > 0.08 ? vec3(0.5, 0.35, 0.15) : vec3(0.35, 0.45, 0.3);
		shade = 0.75;
	}
	// Свет в комнате: от люстры сверху, затухание вглубь
	float depth_fade = mix(1.0, 0.6, 1.0 - q.z);
	vec3 lit_col = col * light_color * 1.25 * shade * depth_fade;
	vec3 dark_col = col * vec3(0.55, 0.55, 0.6) * shade * depth_fade;
	vec3 room = mix(dark_col, lit_col, lit);
	// Тюль и шторы по краям окна
	float curtain_w = 0.12 + 0.1 * hash(seed * 13.0);
	float side = min(UV.x, 1.0 - UV.x);
	vec3 curtain = mix(vec3(0.6, 0.35, 0.3), vec3(0.4, 0.5, 0.35), v_col.b) * (lit > 0.5 ? 1.0 : 0.55);
	float folds = 0.85 + 0.15 * sin(UV.x * 120.0);
	if (side < curtain_w) room = curtain * folds;
	float tulle = 0.1 * (0.7 + 0.3 * sin(UV.x * 300.0)) * step(0.5, hash(seed * 23.0));
	room = mix(room, vec3(0.9, 0.9, 0.85) * (lit > 0.5 ? 1.0 : 0.6), tulle * step(curtain_w, side));
	// Стекло: лёгкий отражённый блик по Френелю
	float fres = pow(1.0 - clamp(normalize(v_tangent_view).z, 0.0, 1.0), 3.0);
	ALBEDO = vec3(0.0);
	EMISSION = room;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.15 + fres * 0.35;
}
