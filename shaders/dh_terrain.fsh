#version 330 compatibility

in vec4 glcolor;
in float dist;

uniform float far;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    // Discard the DH overdraw region, where vanilla terrain already renders,
    // so DH never overlaps the loaded chunks.
    if (dist <= far - 28.0) discard;

    // Pre-baked LOD colour; the composite pass applies the haze fog to it.
    color = glcolor;
}
