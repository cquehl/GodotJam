shader_type canvas_item;

uniform vec3 orb_color : source_color = vec3(0.2, 0.4, 1.0);
uniform vec3 light_dir = vec3(-0.2, 0.8, 0.5);  // From above-left
uniform float ambient = 0.15;
uniform float specular_strength = 0.6;
uniform float specular_power = 32.0;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);

    // Discard pixels outside the circle
    if (dist > 1.0) {
        discard;
    }

    // Calculate sphere normal (z comes from sphere equation)
    float z = sqrt(1.0 - dist * dist);
    vec3 normal = normalize(vec3(uv.x, -uv.y, z));

    // Normalize light direction
    vec3 light = normalize(light_dir);

    // Diffuse lighting
    float diff = max(dot(normal, light), 0.0);

    // Specular lighting (Blinn-Phong)
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_dir = normalize(light + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), specular_power) * specular_strength;

    // Combine lighting
    vec3 color = orb_color * (ambient + diff) + vec3(spec);

    // Soft edge antialiasing
    float edge = 1.0 - smoothstep(0.95, 1.0, dist);

    COLOR = vec4(color, edge);
}
