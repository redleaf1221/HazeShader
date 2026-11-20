#version 330 compatibility

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord  = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);

    glcolor = gl_Color;

    // Model -> view -> world/player space normal (world space avoids the
    // 8-bit quantisation flicker when the normal is stored per-axis).
    normal = gl_NormalMatrix * gl_Normal;
    normal = mat3(gbufferModelViewInverse) * normal;
}
