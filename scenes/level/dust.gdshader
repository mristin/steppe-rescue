// Draw a puff of dust kicked up by a galloping horse (see GallopDust), seen
// from above: a billowing cloud of fine steppe soil with soft, wispy edges,
// lit from the top left, so that its lumps have a sunny and a shaded side.
// As it ages, it swells, loosens into wisps and fades. The particles give
// each puff its own seed (its rotation) and its age, so that no two puffs
// look alike, and the color ramp its opacity.
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 shadow_color : source_color = vec4(0.55, 0.43, 0.30, 1.0);
uniform vec4 dust_color : source_color = vec4(0.86, 0.77, 0.62, 1.0);
uniform vec4 light_color : source_color = vec4(0.99, 0.96, 0.88, 1.0);

// The shadow which the cloud casts on the ground, to the bottom right.
uniform vec4 ground_shadow : source_color = vec4(0.25, 0.17, 0.08, 0.38);

// How dense the middle of a puff is; the grit-like small puffs are denser.
uniform float density = 1.0;

varying float seed;
varying float age;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amplitude = 0.5;
    mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
    for (int i = 0; i < 4; i++) {
        sum += amplitude * noise(p);
        p = turn * p * 2.03 + 17.1;
        amplitude *= 0.5;
    }
    return sum;
}

// The density of the dust at the point of the puff (its middle at 0, its
// edge at 1), billowing by the noise, warped so that it curls.
float cloud(vec2 c, vec2 offset) {
    vec2 p = c * 1.15 + offset;
    vec2 warp = vec2(fbm(p + 3.1), fbm(p - 5.7));
    float n = fbm(p + warp * (1.2 + age));
    // NOTE (mristin):
    // The round body of the puff, which the noise eats away at the edge, and,
    // as the puff ages, inside, too, into wisps.
    float body = 1.0 - smoothstep(0.1, 0.92, length(c) * (1.08 - 0.2 * age));
    return clamp(body * (0.45 + n) - (0.15 + 0.4 * age) * (1.0 - n), 0.0, 1.0);
}

void vertex() {
    // NOTE (mristin):
    // The particles keep their rotation in x and their age (0 to 1) in y.
    seed = INSTANCE_CUSTOM.x;
    age = INSTANCE_CUSTOM.y;
}

void fragment() {
    vec2 c = UV * 2.0 - 1.0;
    vec2 offset = vec2(seed * 3.7, seed * 2.3) + vec2(age * 0.6, -age * 0.4);
    // NOTE (mristin):
    // The particle is turned by its seed; turn the screen's directions (the
    // light from the top left, the shadow to the bottom right) into its frame.
    vec2 to_light = normalize(vec2(-0.6, -0.8));
    to_light = vec2(
        to_light.x * cos(-seed) - to_light.y * sin(-seed),
        to_light.x * sin(-seed) + to_light.y * cos(-seed)
    );
    float d = cloud(c, offset);
    float cast = cloud(c + to_light * 0.22, offset);
    if (d <= 0.001 && cast <= 0.001) {
        discard;
    }
    // NOTE (mristin):
    // A lump is lit where the dust thins towards the light, and shaded where
    // it thickens.
    float toward = cloud(c + to_light * 0.1, offset);
    float lit = clamp(0.5 + (d - toward) * 3.0, 0.0, 1.0);
    vec3 color = mix(shadow_color.rgb, dust_color.rgb, smoothstep(0.0, 0.5, lit));
    color = mix(color, light_color.rgb, smoothstep(0.5, 1.0, lit));
    // NOTE (mristin):
    // The thin edges let the light through and look paler.
    color = mix(color, light_color.rgb, (1.0 - smoothstep(0.0, 0.3, d)) * 0.3);
    float alpha = smoothstep(0.0, 0.45, d * density);
    float shade = smoothstep(0.0, 0.5, cast) * ground_shadow.a;
    // NOTE (mristin):
    // The cloud over its own shadow on the ground.
    float total = alpha + shade * (1.0 - alpha);
    vec3 mixed = (color * alpha + ground_shadow.rgb * shade * (1.0 - alpha)) / max(total, 0.001);
    COLOR = vec4(mixed, total * COLOR.a);
}
