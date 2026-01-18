shader_type sky;

uniform vec3 space_color : source_color = vec3(0.01, 0.01, 0.025);
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 10.0) = 3.0;

// Simple 2D hash for stable stars
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
    vec3 dir = normalize(EYEDIR);

    // Convert 3D direction to 2D spherical coords - prevents streaking
    vec2 uv = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0)) * 2.0);

    // Dark space background
    vec3 color = space_color;

    // Layer 1: Bright stars
    vec2 grid = floor(uv * 50.0);
    vec2 f = fract(uv * 50.0);

    float r = hash(grid);
    if (r < star_density * 0.08) {
        vec2 star_pos = vec2(hash(grid + vec2(1.0, 0.0)), hash(grid + vec2(0.0, 1.0)));
        float dist = length(f - star_pos);

        // Clean circular point stars
        float star_size = 0.06 + hash(grid + vec2(5.0, 5.0)) * 0.04;
        float star = smoothstep(star_size, 0.0, dist);

        // Gentle twinkle
        float twinkle = 0.85 + 0.15 * sin(TIME * 1.2 + r * 6.28);

        // Subtle color variation
        vec3 star_color = vec3(1.0);
        if (r < 0.015) star_color = vec3(1.0, 0.85, 0.7); // Warm
        else if (r < 0.03) star_color = vec3(0.85, 0.92, 1.0); // Cool blue

        color += star * star_brightness * twinkle * star_color;
    }

    // Layer 2: Dimmer background stars
    vec2 grid2 = floor(uv * 100.0);
    vec2 f2 = fract(uv * 100.0);
    float r2 = hash(grid2 + vec2(77.0, 33.0));
    if (r2 < star_density * 0.12) {
        vec2 star_pos2 = vec2(hash(grid2 + vec2(2.0, 0.0)), hash(grid2 + vec2(0.0, 2.0)));
        float dist2 = length(f2 - star_pos2);
        float star2 = smoothstep(0.04, 0.0, dist2);
        color += star2 * star_brightness * 0.35;
    }

    COLOR = color;
}
