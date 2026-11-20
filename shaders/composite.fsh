#version 330 compatibility

// ---- User options ---------------------------------------------------------
#define HAZE_DENSITY 1.0 // [0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.5 2.0] Haze (smog) density
#define HAZE_WEATHER // Boost haze density while it is raining or thundering

// ---- Buffer formats --------------------------------------------------------
/*
const int colortex0Format = RGBA16F;
const int colortex2Format = RGBA16;
*/

uniform sampler2D colortex0; // scene colour (sRGB: albedo for deferred, lit for fallback)
uniform sampler2D colortex1; // lightmap (r = block light, g = sky light)
uniform sampler2D colortex2; // encoded world-space normal (a > 0.5 = deferred)
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float rainStrength;
uniform float thunderStrength;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/shadows.glsl"

const vec3 BLOCKLIGHT_COLOR = vec3(1.0, 0.6, 0.25);
const vec3 AMBIENT_BASE     = vec3(0.02);

// Sky-space sun/moon half-size (radians). The bodies are square and fixed in
// the sky (world-aligned), roughly this angular size.
const float SUN_SQUARE_HALF  = 0.028;
const float MOON_SQUARE_HALF = 0.025;

// Square celestial body, fixed in the sky (world-aligned). The square is
// measured in a local orthonormal tangent basis at the body's sky position
// (one axis horizontal, one pointing "up" in the sky), NOT in azimuth x
// elevation — azimuth compresses by cos(elevation) near the zenith, which
// would squash the square into a vanishing vertical strip overhead.
vec3 squareBody(vec3 viewDir, vec3 bodyDir, vec3 spectrum, float angularHalfSize, float haze, float factor, float intensity) {
    // Horizontal axis perpendicular to the body's direction.
    vec3 right = cross(vec3(0.0, 1.0, 0.0), bodyDir);
    float rightLen = length(right);
    right = rightLen > 0.0005 ? right / rightLen : vec3(1.0, 0.0, 0.0);
    // "Up in the sky" axis, completing the orthonormal basis.
    vec3 vert = cross(bodyDir, right);

    // Angular offset of the view ray in this tangent plane (~ radians for
    // small offsets), identical scale on both axes -> a true square.
    float u = dot(viewDir, right);
    float v = dot(viewDir, vert);

    float halfSize = angularHalfSize * (1.0 - 0.15 * haze);
    float edge = max(abs(u), abs(v));
    float disk = 1.0 - smoothstep(halfSize * 0.85, halfSize, edge);

    vec3 light = directLight(spectrum, haze, bodyDir.y) * factor;
    return light * disk * intensity;
}

void main() {
    vec3 albedo = texture(colortex0, texcoord).rgb;
    float depth = texture(depthtex0, texcoord).r;

    // Haze density = base setting, boosted by rain/thunder.
    float haze = HAZE_DENSITY;
    #ifdef HAZE_WEATHER
        haze += rainStrength * 0.6 + thunderStrength * 1.2;
    #endif
    haze = clamp(haze, 0.0, 3.0);

    // World-space sun/moon directions.
    vec3 sunDir  = viewToWorldDirection(gbufferModelViewInverse, normalize(sunPosition));
    vec3 moonDir = viewToWorldDirection(gbufferModelViewInverse, normalize(moonPosition));

    float dayFactor   = smoothstep(-0.10, 0.15, sunDir.y);
    float nightFactor = smoothstep(-0.10, 0.15, moonDir.y);

    // View-space ray through this pixel (valid for sky and geometry).
    vec2 ndc = texcoord * 2.0 - 1.0;
    // depthtex stores gl_FragCoord.z in [0, 1], NOT NDC z. Converting only
    // x/y to NDC while leaving z in screen space reconstructs points at the
    // wrong distance along the view ray (roughly twice as far on typical
    // projection matrices), which makes a surface sample its own displaced
    // position in the shadow map.
    // NO, No mapping, this is new verison using GL_ZERO_TO_ONE
    float ndcDepth = depth;
    vec3 viewDir = normalize((gbufferProjectionInverse * vec4(ndc, 1.0, 1.0)).xyz);
    vec3 worldDir = viewToWorldDirection(gbufferModelViewInverse, viewDir);

    // ---- Sky vs geometry, with Distant Horizons -----------------------------
    // DH terrain writes its depth to dhDepthTex0 (vanilla depth stays 1.0),
    // so a pixel is sky only when BOTH depth buffers are at the far plane.
    #ifdef DISTANT_HORIZONS
        float dhDepth = texture(dhDepthTex0, texcoord).r;
        bool isSky = depth >= 1.0 && dhDepth >= 1.0;
    #else
        bool isSky = depth >= 1.0;
    #endif

    if (isSky) {
        vec3 sky = skyColor(worldDir, sunDir, moonDir, haze, dayFactor, nightFactor);
        sky += squareBody(worldDir, sunDir,  SOLAR_SPECTRUM, SUN_SQUARE_HALF,  haze, dayFactor,   2.5);
        sky += squareBody(worldDir, moonDir, MOON_SPECTRUM,  MOON_SQUARE_HALF, haze, nightFactor, 8.0);
        color = vec4(sky, 1.0);
        return;
    }

    // ---- Geometry ----------------------------------------------------------
    vec3 linearAlbedo = toLinear(albedo);
    vec2 lightmap = texture(colortex1, texcoord).rg;
    vec4 encodedNormal = texture(colortex2, texcoord);
    vec3 normal = normalize(encodedNormal.rgb * 2.0 - 1.0);

    vec3 viewPos;
    #ifdef DISTANT_HORIZONS
        if (depth >= 1.0) {
            // DH terrain (vanilla depth is far, DH depth is not).
            viewPos = projectAndDivide(dhProjectionInverse, vec3(ndc, dhDepth));
        } else {
            viewPos = projectAndDivide(gbufferProjectionInverse, vec3(ndc, ndcDepth));
        }
    #else
        viewPos = projectAndDivide(gbufferProjectionInverse, vec3(ndc, ndcDepth));
    #endif
    float dist = length(viewPos);

    vec3 lit;
    if (encodedNormal.a > 0.5) {
        // Deferred-lit geometry (everything our gbuffers programs wrote).
        vec3 sunLight  = directLight(SOLAR_SPECTRUM, haze, sunDir.y)  * dayFactor;
        vec3 moonLight = directLight(MOON_SPECTRUM,  haze, moonDir.y) * nightFactor;

        vec3 ambient = ambientLight(sunDir, moonDir, haze, dayFactor, nightFactor);

        float ndlSun  = clamp(dot(normal, sunDir), 0.0, 1.0);
        float ndlMoon = clamp(dot(normal, moonDir), 0.0, 1.0);

        vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 shadowView = (shadowModelView * vec4(playerPos, 1.0)).xyz;
        vec4 shadowClip = shadowProjection * vec4(shadowView, 1.0);
        float shadow = getSoftShadow(shadowClip);

        // Haze fills in shadows: the shadow contrast scales with how much of
        // the direct beam survives over a typical shadow-casting distance, so
        // heavy haze produces soft, weak shadows and even lighting.
        float shadowStrength = clamp(hazeTransmittance(haze, 10.0).g, 0.25, 1.0);
        float softShadow = mix(1.0, shadow, shadowStrength);

        float skyExposure = lightmap.g;

        vec3 direct     = (sunLight * ndlSun + moonLight * ndlMoon) * softShadow * skyExposure;
        vec3 skyLight   = ambient * skyExposure;
        vec3 blockLight = lightmap.r * BLOCKLIGHT_COLOR;

        lit = linearAlbedo * (AMBIENT_BASE + blockLight + skyLight + direct);
    } else {
        // Geometry rendered by a vanilla fallback shader (beacon beams, block
        // outlines, armour glint, world border, Distant Horizons LODs, ...).
        // Its colour is already lit, so we only linearise it and fog it below.
        lit = linearAlbedo;
    }

    // Aerial perspective: distant objects fade into the airlight (the diffuse
    // haze colour in this direction — no sun glow or disk, so the sun stays
    // occluded). The object accumulates less airlight than the sky behind it,
    // so it ends up as a darker silhouette.
    vec3 transmittance = hazeTransmittance(haze, dist);
    vec3 airlight = airlightColor(worldDir, sunDir, moonDir, haze, dayFactor, nightFactor);
    vec3 result = lit * transmittance + airlight * (vec3(1.0) - transmittance);

    color = vec4(result, 1.0);
}
