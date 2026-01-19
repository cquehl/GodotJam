shader_type spatial;
// SIMPLIFIED VERSION - removed depth_prepass_alpha and fresnel for WebGL performance
// Original render mode: blend_mix, depth_prepass_alpha, cull_back;
render_mode blend_mix, cull_back;

// Metaball-style bright blue droplet
uniform vec3 deep_color : source_color = vec3(0.0, 0.3, 1.0);
uniform vec3 mid_color : source_color = vec3(0.1, 0.5, 1.0);
uniform vec3 rim_color : source_color = vec3(0.3, 0.8, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 1.5;
uniform float rim_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float inner_glow : hint_range(0.0, 2.0) = 0.8;
uniform float tail_length : hint_range(0.0, 3.0) = 3.0;
uniform float tail_width : hint_range(0.0, 1.0) = 0.14;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

varying float tail_factor;
varying vec3 local_pos;

void vertex() {
    vec3 pos = VERTEX;
    local_pos = pos;

    float behind = max(0.0, -pos.z);
    tail_factor = behind;

    if (pos.z < 0.0) {
        pos.z -= behind * tail_length;
        float taper = 1.0 - (behind * tail_width);
        pos.x *= max(0.1, taper);
        pos.y *= max(0.1, taper);
    }

    VERTEX = pos;
}

void fragment() {
    // SIMPLIFIED: Basic color gradient without expensive fresnel
    // Tail fades to lighter blue
    float tail_blend = smoothstep(0.0, 0.8, tail_factor);
    vec3 base_color = mix(mid_color, mid_color * 1.2, tail_blend);

    // Simple view-based shading (cheaper than fresnel)
    float shade = max(dot(NORMAL, VIEW), 0.0);
    base_color = mix(deep_color, base_color, shade);

    ALBEDO = base_color;
    EMISSION = base_color * 0.2 * opacity;
    ALPHA = 0.9 * opacity;
    METALLIC = 0.0;
    ROUGHNESS = 0.4;
    SPECULAR = 0.5;
}

/*
// ============ ORIGINAL METABALL FRAGMENT (commented for easy restore) ============
void fragment() {
    // Fresnel for rim lighting - key to the metaball look
    float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);

    // Smooth gradient from deep center to bright rim
    vec3 base_color = mix(deep_color, mid_color, fresnel * 0.5);
    vec3 rim = rim_color * fresnel * rim_intensity;

    // Subtle inner glow based on view angle
    float center_glow = pow(max(dot(NORMAL, VIEW), 0.0), 2.0);
    vec3 inner = mid_color * center_glow * inner_glow * 0.3;

    // Tail fades to lighter blue
    float tail_blend = smoothstep(0.0, 0.8, tail_factor);
    base_color = mix(base_color, mid_color * 1.2, tail_blend);

    vec3 final_color = base_color + rim + inner;

    // Alpha: solid body, fade in tail, modulated by opacity uniform
    float alpha = mix(0.95, 0.4, tail_blend) * opacity;

    ALBEDO = final_color;
    EMISSION = final_color * 0.3 * opacity; // Bright glow fades with opacity
    ALPHA = alpha;
    METALLIC = 0.0;
    ROUGHNESS = 0.4;
    SPECULAR = 0.5;
}
// ============ END ORIGINAL ============
*/
