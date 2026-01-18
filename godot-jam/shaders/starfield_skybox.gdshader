shader_type sky;

uniform vec3 nebula_color_1 : source_color = vec3(0.1, 0.05, 0.3);
uniform vec3 nebula_color_2 : source_color = vec3(0.3, 0.1, 0.5);
uniform vec3 nebula_color_3 : source_color = vec3(0.05, 0.1, 0.3);
uniform float nebula_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.5;
uniform float large_star_density : hint_range(0.0, 0.1) = 0.02;
uniform vec3 star_color_tint : source_color = vec3(0.9, 0.95, 1.0);
uniform float rotation_speed : hint_range(0.0, 0.5) = 0.02;
uniform float galaxy_density : hint_range(0.0, 0.1) = 0.015;
uniform float galaxy_brightness : hint_range(0.0, 2.0) = 0.8;
uniform bool enable_twinkle : hint_default = true;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 2.0;

// Hash function for pseudo-random values
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

// 3D noise function
float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash(i);
    float n100 = hash(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash(i + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, f.x);
    float x10 = mix(n010, n110, f.x);
    float x01 = mix(n001, n101, f.x);
    float x11 = mix(n011, n111, f.x);

    float y0 = mix(x00, x10, f.y);
    float y1 = mix(x01, x11, f.y);

    return mix(y0, y1, f.z);
}

// Fractal Brownian Motion for nebula
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++) {
        value += amplitude * noise3d(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Generate stars with various sizes and optional twinkling
float stars(vec3 p, float density, float size, float twinkle) {
    vec3 cell = floor(p);
    vec3 fract_p = fract(p);

    float star = 0.0;

    // Check neighboring cells for stars
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 cell_pos = cell + neighbor;

                float rand = hash(cell_pos);

                if (rand < density) {
                    // Star position within cell
                    vec3 star_pos = neighbor + vec3(
                        hash(cell_pos + vec3(1.0, 2.0, 3.0)),
                        hash(cell_pos + vec3(4.0, 5.0, 6.0)),
                        hash(cell_pos + vec3(7.0, 8.0, 9.0))
                    );

                    float dist = length(fract_p - star_pos);
                    float star_size = size * (0.5 + hash(cell_pos + vec3(10.0, 11.0, 12.0)) * 0.5);

                    // Twinkling effect
                    float brightness = 1.0;
                    if (enable_twinkle) {
                        float phase = hash(cell_pos + vec3(13.0, 14.0, 15.0)) * 6.28318;
                        brightness = 0.7 + 0.3 * sin(twinkle + phase);
                    }

                    star = max(star, brightness * (1.0 - smoothstep(0.0, star_size, dist)));
                }
            }
        }
    }

    return star;
}

// Generate distant galaxies
float galaxy(vec3 p, float density) {
    vec3 cell = floor(p);
    vec3 fract_p = fract(p);

    float galaxy_glow = 0.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 cell_pos = cell + neighbor;

                float rand = hash(cell_pos);

                if (rand < density) {
                    // Galaxy position
                    vec3 galaxy_pos = neighbor + vec3(
                        hash(cell_pos + vec3(20.0, 21.0, 22.0)),
                        hash(cell_pos + vec3(23.0, 24.0, 25.0)),
                        hash(cell_pos + vec3(26.0, 27.0, 28.0))
                    );

                    vec3 offset = fract_p - galaxy_pos;
                    float dist = length(offset);

                    // Spiral pattern for galaxy
                    float angle = atan(offset.y, offset.x);
                    float spiral = sin(angle * 3.0 - dist * 10.0) * 0.5 + 0.5;

                    // Galaxy core and arms
                    float core = exp(-dist * 20.0);
                    float arms = exp(-dist * 8.0) * spiral * 0.6;

                    galaxy_glow = max(galaxy_glow, core + arms);
                }
            }
        }
    }

    return galaxy_glow;
}

void sky() {
    // Rotate the sky slowly over time
    float time = TIME * rotation_speed;
    float c = cos(time);
    float s = sin(time);
    mat3 rot = mat3(
        vec3(c, 0.0, s),
        vec3(0.0, 1.0, 0.0),
        vec3(-s, 0.0, c)
    );

    vec3 dir = rot * EYEDIR;

    // Base dark space color
    vec3 base_color = vec3(0.01, 0.01, 0.02);

    // Nebula layers with different scales and colors
    float nebula1 = fbm(dir * 2.0);
    float nebula2 = fbm(dir * 3.0 + vec3(5.0, 5.0, 5.0));
    float nebula3 = fbm(dir * 1.5 + vec3(10.0, 10.0, 10.0));

    // Combine nebulae with different colors
    vec3 nebula = nebula_color_1 * nebula1 * 0.4;
    nebula += nebula_color_2 * nebula2 * 0.3;
    nebula += nebula_color_3 * nebula3 * 0.3;

    // Apply nebula intensity
    nebula *= nebula_intensity;

    // Twinkle time
    float twinkle_time = TIME * twinkle_speed;

    // Add multiple star layers with twinkling
    float star_layer_1 = stars(dir * 30.0, star_density * 0.01, 0.02, twinkle_time);
    float star_layer_2 = stars(dir * 20.0, star_density * 0.008, 0.03, twinkle_time * 1.3);
    float star_layer_3 = stars(dir * 15.0, large_star_density, 0.04, twinkle_time * 0.7);

    // Combine star layers with brightness
    float all_stars = star_layer_1 + star_layer_2 * 1.2 + star_layer_3 * 1.5;

    // Add color variation to stars
    vec3 star_color = vec3(1.0) * all_stars * star_brightness;

    // Some stars have slight color tints
    float color_variation = hash(floor(dir * 30.0));
    if (color_variation > 0.9) {
        star_color *= vec3(1.0, 0.9, 0.8); // Warm stars
    } else if (color_variation > 0.8) {
        star_color *= vec3(0.9, 0.95, 1.1); // Cool stars
    }

    star_color *= star_color_tint;

    // Add distant galaxies
    float galaxy_layer = galaxy(dir * 5.0, galaxy_density);
    vec3 galaxy_color = vec3(0.8, 0.7, 1.0) * galaxy_layer * galaxy_brightness;

    // Combine everything
    vec3 final_color = base_color + nebula + star_color + galaxy_color;

    // Add subtle brightness to upper hemisphere
    float horizon_glow = max(0.0, dir.y) * 0.05;
    final_color += vec3(0.05, 0.05, 0.1) * horizon_glow;

    COLOR = final_color;
}
