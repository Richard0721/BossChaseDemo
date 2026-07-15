shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_texture : hint_default_black, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float rotor_speed = 13.0;
uniform float rotor_start_height = 0.00345;
uniform float emission_strength = 1.4;


void vertex() {
	float rotates = step(rotor_start_height, VERTEX.z);
	float angle = TIME * rotor_speed * rotates;
	float cosine = cos(angle);
	float sine = sin(angle);
	mat2 rotation_matrix = mat2(vec2(cosine, sine), vec2(-sine, cosine));
	VERTEX.xy = rotation_matrix * VERTEX.xy;
	NORMAL.xy = rotation_matrix * NORMAL.xy;
	TANGENT.xy = rotation_matrix * TANGENT.xy;
}


void fragment() {
	vec4 base_color = texture(albedo_texture, UV);
	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
	METALLIC = texture(metallic_texture, UV).r;
	ROUGHNESS = texture(roughness_texture, UV).r;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	EMISSION = texture(emission_texture, UV).rgb * emission_strength;
}
