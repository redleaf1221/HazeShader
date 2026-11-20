// shadows.glsl — minimal orthographic shadow mapping with percentage-closer
// filtering. No shadow-space distortion: the pack keeps the mapping simple
// because heavy haze softens shadows anyway.

const int shadowMapResolution = 2048;
const float shadowDistance = 200.0;
const float shadowDistanceRenderMul = 1.0;
const bool shadowtex0Nearest = true;

const float SHADOW_BIAS = 0.001;

// Return 1.0 (lit) if the shadow-screen position is outside the map or the
// fragment is in front of the nearest occluder, 0.0 (shadowed) otherwise.
float sampleShadow(vec3 shadowScreenPos) {
    if (shadowScreenPos.x < 0.0 || shadowScreenPos.x > 1.0 ||
        shadowScreenPos.y < 0.0 || shadowScreenPos.y > 1.0 ||
        shadowScreenPos.z < 0.0 || shadowScreenPos.z > 1.0) {
        return 1.0;
    }
    float mapDepth = texture(shadowtex0, shadowScreenPos.xy).r;
    return step(shadowScreenPos.z - SHADOW_BIAS, mapDepth);
}

// Percentage-closer filtering over a (2*N+1)^2 box.
float getSoftShadow(vec4 shadowClipPos) {
    const int N = 2;
    float sum = 0.0;
    int count = 0;
    for (int x = -N; x <= N; x++) {
        for (int y = -N; y <= N; y++) {
            vec2 offset = vec2(float(x), float(y)) * (1.5 / float(shadowMapResolution));
            vec4 c = shadowClipPos;
            c.xy += offset;
            vec3 ndc = c.xyz / c.w;
            // fix depth mapping
            vec3 screenPos = vec3(ndc.xy * 0.5 + 0.5, ndc.z);
            sum += sampleShadow(screenPos);
            count++;
        }
    }
    return sum / float(count);
}
