// common.glsl — shared math helpers.
// No uniforms, no options and no pipeline constants live here, so this file
// can be #included from any stage.

// Apply a matrix to a point, then divide by w (clip/NDC -> view/player space).
vec3 projectAndDivide(mat4 m, vec3 p) {
    vec4 h = m * vec4(p, 1.0);
    return h.xyz / h.w;
}

// Rotate a view-space direction into world/player space (+Y up).
vec3 viewToWorldDirection(mat4 modelViewInverse, vec3 viewDir) {
    return normalize(mat3(modelViewInverse) * viewDir);
}

// sRGB <-> linear. Scene albedos arrive gamma-encoded; all lighting is done
// in linear space and re-encoded at the very end.
vec3 toLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 toSrgb(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

// Perceptual luminance.
float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// ACES filmic tonemap approximation (Narkowicz 2015), maps HDR -> [0, 1].
vec3 tonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}
