shader_type spatial;
// The muzzle flash: additive, unlit, and depth-squeezed like the gun
// (viewmodel.gdshader) so it is never cut off by a wall in front of it.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.4);
uniform float strength = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.z, POSITION.w, 0.995);
}

void fragment() {
	// A soft disc on a quad: bright core, falling off to the edge.
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	ALBEDO = color * strength * a * a * 4.0;
}
