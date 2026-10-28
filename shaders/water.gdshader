shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// ماء واقعي: أمواج متعددة الاتجاهات، تدرج عمق من الفيروزي للأزرق الداكن، رغوة على الشاطئ، انعكاس السماء.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float map_size = 512.0;
uniform float hscale = 1.0;
uniform float hoff = 0.0;
uniform float water_y = 0.0;
uniform int detail = 2;   // 0 منخفض، 1 متوسط، 2 عالٍ
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// ميل سطح الماء (d h / d x , d h / d z) من مجموع موجات جيبية
vec2 wave_slope(vec2 p, float t) {
	vec2 g = vec2(0.0);
	vec2 d1 = vec2(0.86, 0.5);
	vec2 d2 = vec2(-0.5, 0.87);
	vec2 d3 = vec2(0.3, -0.95);
	g += d1 * cos(dot(d1, p) * 0.45 + t * 0.9) * 0.075;
	g += d2 * cos(dot(d2, p) * 0.8 + t * 1.2) * 0.05;
	g += d3 * cos(dot(d3, p) * 1.7 + t * 1.6) * 0.035;
	if (detail >= 1) {
		vec2 d4 = vec2(-0.95, -0.3);
		g += d4 * cos(dot(d4, p) * 3.1 + t * 2.2) * 0.025;
	}
	if (detail >= 2) {
		float e = 0.12;
		vec2 q = p * 2.4 + vec2(t * 0.35, -t * 0.25);
		float n0 = vnoise(q);
		g += vec2(vnoise(q + vec2(e, 0.0)) - n0, vnoise(q + vec2(0.0, e)) - n0) * 0.22;
	}
	return g;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / map_size;
	vec2 cuv = clamp(uv, vec2(0.0), vec2(1.0));
	float th = texture(height_tex, cuv * hscale + vec2(hoff)).r;
	float outside = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
	float depth = max(water_y - th, 0.0);
	depth = max(depth, 6.0 * smoothstep(0.0, 0.03, outside));
	vec2 p = wpos.xz;
	float t = TIME;

	// الأمواج (تخفّ قرب الشاطئ الضحل)
	vec2 sl = wave_slope(p, t);
	float calm = smoothstep(0.0, 0.5, depth);
	sl *= mix(0.35, 1.0, calm);
	vec3 nw = normalize(vec3(-sl.x, 1.0, -sl.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// ألوان العمق
	vec3 shallow = vec3(0.20, 0.62, 0.58);
	vec3 mid = vec3(0.05, 0.36, 0.46);
	vec3 deep = vec3(0.01, 0.13, 0.28);
	vec3 col = mix(shallow, mid, smoothstep(0.0, 1.8, depth));
	col = mix(col, deep, smoothstep(1.4, 5.5, depth));
	// ظل الأمواج: قمم أفتح وقيعان أغمق
	col *= 0.92 + 0.16 * (sl.x + sl.y) * 2.5 + 0.04;

	// رغوة الشاطئ: خطوط تتحرك بالتناوب مع تموج الحافة
	float edge = 1.0 - smoothstep(0.0, 0.7, depth);
	float fn = vnoise(p * 1.6 + vec2(t * 0.3, -t * 0.2));
	float lap = 0.5 + 0.5 * sin(depth * 9.0 - t * 1.7 + fn * 4.0);
	float foam = edge * smoothstep(0.25, 0.8, fn * 0.7 + lap * 0.5);
	foam += (1.0 - smoothstep(0.0, 0.12, depth)) * 0.55;
	col = mix(col, vec3(0.94, 0.97, 0.97), clamp(foam, 0.0, 1.0) * 0.85);

	// فرنل: انعكاس لون السماء عند الزوايا المائلة
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, vec3(0.62, 0.78, 0.92), fres * 0.55);

	float fv = texture(fog_tex, cuv).r;
	float fo = mix(fv, 0.5, smoothstep(0.0, 0.06, outside));
	ALBEDO = col * mix(0.03, 1.0, fo);
	ROUGHNESS = mix(0.04, 0.35, clamp(foam, 0.0, 1.0));
	METALLIC = 0.0;
	SPECULAR = 0.85;
	ALPHA = clamp(0.34 + 0.6 * smoothstep(0.0, 1.5, depth) + foam * 0.45, 0.0, 0.97);
}
