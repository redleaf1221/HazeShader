#version 330 compatibility

// Distant Horizons water. Same as dh_terrain: DH LODs are coloured via
// gl_Color and projected with DH's projection.

out vec4 glcolor;
out float dist;

uniform mat4 dhProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

void main() {
    vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    dist = length(position.xyz);
    gl_Position = dhProjection * gbufferModelView * position;

    glcolor = gl_Color;
}
