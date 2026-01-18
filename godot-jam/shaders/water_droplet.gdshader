shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.2, 0.5, 1.0, 0.85);
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.3;
uniform float rim_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float trail_length : hint_range(0.0, 2.0) = 0.8;
uniform float ripple_speed : hint_range(0.0, 5.0) = 2.0;
uniform float ripple_scale : hint_range(0.0, 20.0) = 8.0;

// Noise function for ripples
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
    // Create teardrop shape by stretching bottom vertices
    vec3 pos = VERTEX;
    float vertical_factor = (pos.y + 0.5); // -0.5 to 0.5 -> 0 to 1

    if (vertical_factor < 0.5) {
        // Bottom half - create trail
        float trail_factor = (0.5 - vertical_factor) * 2.0; // 0 to 1
        trail_factor = pow(trail_factor, 1.5); // Sharpen the trail

        // Pull bottom vertices down and inward
        pos.y -= trail_factor * trail_length;
        pos.x *= (1.0 - trail_factor * 0.3);
        pos.z *= (1.0 - trail_factor * 0.3);
    }

    VERTEX = pos;
}

void fragment() {
    // Base water color
    vec3 base_color = water_color.rgb;

    // Fresnel effect for rim lighting (water droplet edge shine)
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    vec3 rim_color = vec3(0.8, 0.9, 1.0) * fresnel * rim_intensity;

    // Animated ripples on surface
    float time = TIME * ripple_speed;
    vec2 ripple_uv = UV * ripple_scale;
    float ripples = noise(ripple_uv + vec2(time * 0.3, time * 0.2));
    ripples += noise(ripple_uv * 2.0 - vec2(time * 0.5, time * 0.3)) * 0.5;
    ripples = ripples * 0.1 - 0.05; // Small perturbation

    // Apply ripples to normal for water surface distortion
    vec3 ripple_normal = NORMAL;
    ripple_normal.x += ripples;
    ripple_normal = normalize(ripple_normal);

    // Refraction-like effect
    vec3 refracted_color = base_color + vec3(ripples * refraction_strength);

    // Specular highlights (water shine)
    float spec = pow(max(dot(ripple_normal, VIEW), 0.0), 32.0);
    vec3 specular = vec3(1.0) * spec * 0.8;

    // Combine all effects
    vec3 final_color = refracted_color + rim_color + specular;

    // Emission for subtle glow
    EMISSION = base_color * 0.3;

    ALBEDO = final_color;
    ALPHA = water_color.a;
    METALLIC = 0.1;
    ROUGHNESS = 0.1;
    SPECULAR = 0.8;
}
