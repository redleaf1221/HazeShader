#version 330 compatibility

// Shadow pipeline constants are declared here (in a directly-scanned fragment
// shader) so Iris reliably picks them up even if it does not expand #include
// directives when scanning. They are also declared in lib/shadows.glsl for
// use inside composite.fsh; the values are identical.
const int shadowMapResolution = 2048;
const float shadowDistance = 200.0;
const float shadowDistanceRenderMul = 1.0;
const bool shadowtex0Nearest = true;

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 color;

void main() {
    color = texture(gtexture, texcoord) * glcolor;
    if (color.a < 0.1) {
        discard;
    }
}
