#version 330 compatibility

in vec4 glcolor;
in float dist;

uniform float far;
uniform sampler2D depthtex1;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    // Occlusion: DH water is translucent and rendered after opaque geometry,
    // and its depth test only sees the DH depth buffer. Manually discard it
    // wherever opaque geometry (blocks, terrain, the player) is in front so it
    // never shows through them.
    float opaqueDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    if (opaqueDepth < 1.0) discard;

    // Discard the DH overdraw region (vanilla water already renders there).
    if (dist <= far - 28.0) discard;

    color = glcolor;
}
