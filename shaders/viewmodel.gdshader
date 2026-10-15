shader_type spatial;
// The first-person gun. It is drawn at its real size and place but with its
// depth squeezed into the nearest sliver of the depth range, so it always
// sits in front of the world and never clips into a wall you stand against.
// Godot 4.3+ uses reverse Z: the near plane is depth 1, so "nearest" means
// pulling clip-space z toward w. The gun keeps its own depth order inside
// that sliver, so its parts still hide each other correctly.

uniform vec3 albedo : source_color = vec3(0.12, 0.13, 0.18);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.55;
uniform float metallic = 0.3;

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.z, POSITION.w, 0.995);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission * emission_energy;
}
