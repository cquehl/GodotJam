shader_type canvas_item;

uniform vec3 plane_color : source_color = vec3(0.4, 0.4, 0.45);
uniform vec3 light_dir = vec3(-0.2, 0.8, 0.5);
uniform float ambient = 0.6;

// Shadow uniforms
uniform vec2 orb_pos = vec2(0.0, 0.0);  // Orb position in normalized coords (-1 to 1)
uniform float orb_height = 0.1;          // Height above plane (normalized)
uniform float orb_radius = 0.12;         // Orb radius (normalized)
uniform float shadow_intensity = 0.6;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);

    if (dist > 1.0) {
        discard;
    }

    // Flat plane with simple lighting
    vec3 normal = normalize(vec3(0.0, -0.5, 0.85));
    vec3 light = normalize(light_dir);
    float diff = max(dot(normal, light), 0.0);
    vec3 color = plane_color * (ambient + diff * 0.3);

    // Subtle depth gradient
    color *= 1.0 - uv.y * 0.08;

    // === SHADOW CASTING ===
    // Project shadow based on light direction
    // Light comes from light_dir, so shadow falls opposite in XY
    vec2 light_xy = normalize(light_dir.xy);
    float light_z = max(light_dir.z, 0.1);

    // Shadow offset: higher orb = shadow further from orb
    vec2 shadow_offset = -light_xy * (orb_height / light_z) * 0.5;
    vec2 shadow_center = orb_pos + shadow_offset;

    // Shadow size: higher orb = larger, softer shadow (penumbra effect)
    float height_factor = 1.0 + orb_height * 2.0;
    float shadow_size = orb_radius * height_factor;
    float shadow_softness = 0.02 + orb_height * 0.15;

    // Elliptical shadow (sphere on tilted plane)
    vec2 shadow_uv = (uv - shadow_center) / shadow_size;
    shadow_uv.y *= 0.6;  // Squash vertically for 3/4 view
    float shadow_dist = length(shadow_uv);

    float shadow = 1.0 - smoothstep(1.0 - shadow_softness, 1.0 + shadow_softness, shadow_dist);

    // Fade shadow with height (higher = weaker shadow)
    float shadow_fade = 1.0 / (1.0 + orb_height * 3.0);
    shadow *= shadow_fade;

    color *= 1.0 - shadow * shadow_intensity;

    // Soft edge
    float edge = 1.0 - smoothstep(0.95, 1.0, dist);

    COLOR = vec4(color, edge);
}
