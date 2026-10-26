shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 512.0;
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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	float n1 = fbm(wpos.xz * 0.12);
	float n2 = vnoise(wpos.xz * 2.7);
	float n3 = vnoise(wpos.xz * 11.0);
	vec3 c = COLOR.rgb;
	c *= 0.80 + 0.30 * n1 + 0.10 * (n2 - 0.5) + 0.07 * (n3 - 0.5);
	// تموجات الرمال تظهر على الألوان الرملية فقط
	float sandness = smoothstep(0.62, 0.8, c.r) * smoothstep(0.35, 0.5, c.g);
	float rip = sin((wpos.x * 0.8 + wpos.z * 0.45) * 2.4 + n1 * 7.0) * 0.5 + 0.5;
	c *= 1.0 - 0.08 * sandness * rip;
	// المنحدرات الشديدة: طبقات صخرية
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float strata = sin(wpos.y * 3.0 + n1 * 2.5) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.52, 0.41, 0.31), vec3(0.66, 0.53, 0.40), strata) * (0.78 + 0.4 * n2);
	c = mix(c, rock, smoothstep(0.2, 0.5, slope));
	// رمل مبلل قرب خط الماء
	float wet = 1.0 - smoothstep(-0.1, 0.55, wpos.y);
	c = mix(c, c * vec3(0.6, 0.56, 0.48), wet);
	// تضاريس دقيقة: اضطراب في الاتجاه العمودي لإظهار نتوءات الرمل والصخر
	float e = 0.18;
	float h0 = fbm(wpos.xz * 1.1);
	float hx = fbm((wpos.xz + vec2(e, 0.0)) * 1.1) - h0;
	float hz = fbm((wpos.xz + vec2(0.0, e)) * 1.1) - h0;
	vec3 bump = vec3(-hx, 0.0, -hz) * (1.4 + slope * 2.5);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	float v = texture(fog_tex, wpos.xz / map_size).r;
	c *= mix(0.03, 1.0, v);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.72, wet);
}
