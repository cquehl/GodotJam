shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 electric_color : source_color = vec4(0.2, 1.0, 0.3, 0.8);
uniform vec4 core_color : source_color = vec4(0.8, 1.0, 0.9, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.5;

void fragment() {
    float time = TIME * pulse_speed;
    float pulse = sin(time) * 0.3 + 0.7;

    // Fresnel for edge glow
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);

    vec3 base_color = electric_color.rgb;
    base_color += electric_color.rgb * fresnel * 0.5;

    vec3 emission_color = electric_color.rgb * glow_intensity * pulse;
    emission_color += vec3(0.2, 1.0, 0.4) * fresnel * 1.5;

    ALBEDO = base_color;
    EMISSION = emission_color;
    ALPHA = electric_color.a;
    METALLIC = 0.2;
    ROUGHNESS = 0.3;
    SPECULAR = 0.6;
}
