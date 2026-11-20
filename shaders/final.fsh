#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

#include "/lib/common.glsl"

layout(location = 0) out vec4 color;

void main() {
    vec3 hdr = texture(colortex0, texcoord).rgb;
    vec3 mapped = tonemap(hdr);
    color = vec4(toSrgb(mapped), 1.0);
}
