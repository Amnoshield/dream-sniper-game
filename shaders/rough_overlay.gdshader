shader_type spatial;

uniform bool active = true;
uniform float scale = 1.0;
uniform sampler3D rough_noise_texture;

void fragment() {
	// Called for every pixel the material is visible on.
	if (!active){
		discard;
	}
	
	vec3 original_color = COLOR.xyz;
	vec3 wrld_vertex = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 position = wrld_vertex/vec3(scale);
	vec4 noise = texture(rough_noise_texture, position);
	//vec3 new_color = mix(original_color, noise.xyz, 0);
	//COLOR = mix(COLOR, noise, foam_ammount);
	ALBEDO = noise.rgb;
	ALPHA = noise.a;
}
