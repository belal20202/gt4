shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float map_size = 512.0;
uniform float hscale = 1.0;
uniform float hoff = 0.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / map_size;
	vec2 cuv = clamp(uv, vec2(0.0), vec2(1.0));
	float th = texture(height_tex, cuv * hscale + vec2(hoff)).r;
	float depth = max(-0.35 - th, 0.0);
	float outside = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
	vec2 p = wpos.xz;
	float t = TIME;
	vec2 w1 = vec2(sin(p.x * 0.8 + t * 1.1), cos(p.y * 0.9 + t * 0.9));
	vec2 w2 = vec2(sin(p.x * 2.3 - t * 1.7 + p.y), cos(p.y * 2.1 + t * 1.4 - p.x));
	NORMAL = normalize(NORMAL + vec3(w1.x * 0.05 + w2.x * 0.03, 0.0, w1.y * 0.05 + w2.y * 0.03));
	vec3 shallow = vec3(0.20, 0.62, 0.60);
	vec3 deep = vec3(0.02, 0.14, 0.27);
	float k = smoothstep(0.0, 4.5, depth);
	vec3 col = mix(shallow, deep, k);
	float foam = (1.0 - smoothstep(0.0, 0.6, depth)) * (0.65 + 0.35 * sin(p.x * 3.0 + p.y * 2.0 + t * 2.0));
	col = mix(col, vec3(0.92, 0.96, 0.96), clamp(foam, 0.0, 1.0) * 0.8);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.65, 0.8, 0.9), fres * 0.45);
	float fv = texture(fog_tex, cuv).r;
	float fo = mix(fv, 0.45, smoothstep(0.0, 0.08, outside));
	ALBEDO = col * mix(0.03, 1.0, fo);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = clamp(0.38 + k * 0.58 + foam * 0.4, 0.0, 0.96);
}
