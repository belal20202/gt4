shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// أرضية صحراوية واقعية: رمل بدرجات متفاوتة، كثبان ناعمة، تموجات رياح، تربة صلبة داكنة، وحبيبات دقيقة.
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 512.0;
uniform int detail = 2;   // 0 منخفض، 1 متوسط، 2 عالٍ
varying vec3 wpos;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.2;
}
// ارتفاع الكثبان الوهمي (للإضاءة فقط، لا يغيّر شكل الأرض المستوية)
float dune(vec2 p) {
	return vnoise(p * 0.035) * 3.2 + vnoise(p * 0.09 + 5.0) * 1.2;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 base = COLOR.rgb;
	float big = vnoise(p * 0.02);
	float n1 = fbm(p * 0.07);
	float n3 = vnoise(p * 1.7);
	float n4 = vnoise(p * 9.0);

	// تدرجات لونية واسعة: مناطق رمل فاتحة وأخرى أغمق
	vec3 c = base * (0.80 + 0.30 * big + 0.16 * n1);
	// تربة صلبة داكنة (تشققات وجفاف) على بقع واسعة
	float pan = smoothstep(0.56, 0.74, fbm(p * 0.028 + 7.0));
	c = mix(c, c * vec3(0.80, 0.70, 0.56), pan * 0.6);
	// حبيبات الرمل
	c *= 0.93 + 0.10 * n3 + 0.05 * (n4 - 0.5);

	// تموجات الرياح على الألوان الرملية فقط
	float sandness = smoothstep(0.55, 0.78, base.r) * smoothstep(0.42, 0.58, base.g);
	float dir = dot(p, vec2(0.86, 0.5));
	float ph = dir * 2.6 + big * 11.0 + n1 * 4.0;
	float rip = sin(ph);
	c *= 1.0 - 0.07 * sandness * (rip * 0.5 + 0.5);

	// المنحدرات الشديدة (جوانب الجسور): طبقات صخرية
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float strata = sin(wpos.y * 3.0 + n1 * 2.5) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.52, 0.41, 0.31), vec3(0.66, 0.53, 0.40), strata) * (0.78 + 0.4 * n3);
	c = mix(c, rock, smoothstep(0.2, 0.5, slope));

	// رمل مبلل قرب خط الماء
	float wet = 1.0 - smoothstep(-0.1, 0.55, wpos.y);
	c = mix(c, c * vec3(0.6, 0.56, 0.48), wet);

	// إضاءة الكثبان والتموجات عبر اضطراب الاتجاه (الأرض نفسها مستوية)
	vec3 bump = vec3(0.0);
	if (detail >= 1) {
		float e = 0.6;
		float h0 = dune(p);
		float gx = dune(p + vec2(e, 0.0)) - h0;
		float gz = dune(p + vec2(0.0, e)) - h0;
		bump += vec3(-gx, 0.0, -gz) * 0.55;
		float rc = cos(ph) * 0.05 * sandness;
		bump += vec3(-rc * 0.86, 0.0, -rc * 0.5);
	}
	if (detail >= 2) {
		float h1 = fbm(p * 1.1);
		float hx = fbm((p + vec2(0.18, 0.0)) * 1.1) - h1;
		float hz = fbm((p + vec2(0.0, 0.18)) * 1.1) - h1;
		bump += vec3(-hx, 0.0, -hz) * (1.2 + slope * 2.5);
	}
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);

	float v = texture(fog_tex, p / map_size).r;
	c *= mix(0.05, 1.0, v);
	ALBEDO = c;
	ROUGHNESS = mix(0.96, 0.7, wet);
	SPECULAR = 0.25;
}
