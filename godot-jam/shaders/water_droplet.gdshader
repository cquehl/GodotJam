shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.2, 0.5, 1.0, 0.85);
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.3;
uniform float rim_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float trail_length : hint_range(0.0, 2.0) = 0.8;
uniform float ripple_speed : hint_range(0.0, 5.0) = 2.0;
uniform float ripple_scale : hint_range(0.0, 20.0) = 8.0;
uniform float flow_speed : hint_range(0.0, 10.0) = 4.0;
uniform float flow_intensity : hint_range(0.0, 1.0) = 0.3;

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
        // Bottom half - create animated trail
        float trail_factor = (0.5 - vertical_factor) * 2.0; // 0 to 1
        trail_factor = pow(trail_factor, 1.5); // Sharpen the trail

        // Animated flow - create waves running down the trail
        float flow_time = TIME * flow_speed;
        float wave_phase = trail_factor * 8.0 - flow_time; // Wave traveling down
        float flow_wave = sin(wave_phase) * 0.5 + 0.5; // 0 to 1

        // Secondary slower wave for more complex motion
        float slow_wave = sin(trail_factor * 4.0 - flow_time * 0.5) * 0.5 + 0.5;

        // Combine waves and apply to trail length
        float animated_length = trail_length * (1.0 + flow_wave * flow_intensity * 0.5);

        // Side-to-side sway using horizontal noise
        float horizontal_offset = length(vec2(pos.x, pos.z));
        float sway = sin(flow_time * 1.5 + trail_factor * 6.28) * flow_intensity * 0.15;

        // Apply stretching with animation
        pos.y -= trail_factor * animated_length;

        // Animated pinching - varies with the flow wave
        float pinch_amount = 0.3 + slow_wave * flow_intensity * 0.2;
        pos.x *= (1.0 - trail_factor * pinch_amount);
        pos.z *= (1.0 - trail_factor * pinch_amount);

        // Add subtle sway to trail
        if (horizontal_offset > 0.01) {
            vec2 sway_dir = normalize(vec2(pos.x, pos.z));
            pos.x += sway_dir.x * sway * trail_factor;
            pos.z += sway_dir.y * sway * trail_factor;
        }
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

    // Flowing highlights down the trail (vertical flow visualization)
    float flow_time = TIME * flow_speed;
    float vertical_pos = UV.y; // 0 at top, 1 at bottom

    // Create flowing bands of light moving down
    float flow_band = sin((vertical_pos * 12.0 - flow_time * 2.0)) * 0.5 + 0.5;
    flow_band = pow(flow_band, 4.0); // Sharpen the bands

    // Secondary subtle flow
    float flow_secondary = sin((vertical_pos * 6.0 - flow_time * 1.5 + 1.5)) * 0.5 + 0.5;
    flow_secondary = pow(flow_secondary, 3.0);

    // Combine flow effects
    float flow_highlight = (flow_band * 0.3 + flow_secondary * 0.15) * flow_intensity;

    // Apply ripples to normal for water surface distortion
    vec3 ripple_normal = NORMAL;
    ripple_normal.x += ripples;
    ripple_normal = normalize(ripple_normal);

    // Refraction-like effect
    vec3 refracted_color = base_color + vec3(ripples * refraction_strength);

    // Add flow highlights to the base color
    refracted_color += vec3(0.6, 0.8, 1.0) * flow_highlight;

    // Specular highlights (water shine)
    float spec = pow(max(dot(ripple_normal, VIEW), 0.0), 32.0);
    vec3 specular = vec3(1.0) * spec * 0.8;

    // Combine all effects
    vec3 final_color = refracted_color + rim_color + specular;

    // Emission for subtle glow with flow
    EMISSION = base_color * 0.3 + vec3(0.4, 0.6, 1.0) * flow_highlight * 0.5;

    ALBEDO = final_color;
    ALPHA = water_color.a;
    METALLIC = 0.1;
    ROUGHNESS = 0.1;
    SPECULAR = 0.8;
}
