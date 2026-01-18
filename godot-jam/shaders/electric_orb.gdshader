shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 electric_color : source_color = vec4(0.2, 1.0, 0.3, 0.8);
uniform vec4 core_color : source_color = vec4(0.8, 1.0, 0.9, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float arc_density : hint_range(0.0, 20.0) = 12.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.5;
uniform float energy_flow_speed : hint_range(0.0, 5.0) = 2.0;

// Improved noise function
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n = hash(i);
    float n1 = hash(i + vec3(1.0, 0.0, 0.0));
    float n2 = hash(i + vec3(0.0, 1.0, 0.0));
    float n3 = hash(i + vec3(0.0, 0.0, 1.0));
    float n4 = hash(i + vec3(1.0, 1.0, 0.0));
    float n5 = hash(i + vec3(1.0, 0.0, 1.0));
    float n6 = hash(i + vec3(0.0, 1.0, 1.0));
    float n7 = hash(i + vec3(1.0, 1.0, 1.0));

    float x1 = mix(n, n1, f.x);
    float x2 = mix(n2, n4, f.x);
    float x3 = mix(n3, n5, f.x);
    float x4 = mix(n6, n7, f.x);

    float y1 = mix(x1, x2, f.y);
    float y2 = mix(x3, x4, f.y);

    return mix(y1, y2, f.z);
}

// Fractal noise for electric arcs
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise3d(p);
        p *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

void fragment() {
    // Time-based animation
    float time = TIME * pulse_speed;

    // Pulsing energy core
    float pulse = sin(time) * 0.3 + 0.7; // 0.4 to 1.0

    // Electric arcs using fractal noise
    vec3 arc_pos = VERTEX * arc_density + vec3(0.0, TIME * energy_flow_speed, 0.0);
    float arc_pattern = fbm(arc_pos);

    // Secondary fast-moving arcs
    vec3 arc_pos2 = VERTEX * arc_density * 1.5 - vec3(TIME * energy_flow_speed * 1.5, 0.0, 0.0);
    float arc_pattern2 = fbm(arc_pos2);

    // Combine arc patterns
    float arcs = arc_pattern * 0.6 + arc_pattern2 * 0.4;

    // Create sharp electric bolts from noise
    arcs = pow(arcs, 3.0) * 2.0;
    arcs = smoothstep(0.3, 0.7, arcs);

    // Distance from center for core glow
    float dist_from_center = length(VERTEX);
    float core_glow = 1.0 - smoothstep(0.0, 0.3, dist_from_center);
    core_glow = pow(core_glow, 2.0);

    // Fresnel for edge glow
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);

    // Mix colors based on effects
    vec3 base_color = mix(electric_color.rgb, core_color.rgb, core_glow);

    // Add electric arc highlights
    vec3 arc_color = vec3(0.5, 1.0, 0.6) * arcs;
    base_color += arc_color * 0.8;

    // Add fresnel glow
    base_color += electric_color.rgb * fresnel * 0.5;

    // Animated emission with pulse
    vec3 emission_color = electric_color.rgb * glow_intensity * pulse;
    emission_color += core_color.rgb * core_glow * 1.5;
    emission_color += arc_color * 2.0; // Make arcs really bright

    ALBEDO = base_color;
    EMISSION = emission_color;
    ALPHA = electric_color.a;
    METALLIC = 0.2;
    ROUGHNESS = 0.3;
    SPECULAR = 0.6;

    // Add rim lighting
    EMISSION += vec3(0.2, 1.0, 0.4) * fresnel * 1.5;
}
