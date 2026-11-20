#version 330 compatibility

// Distant Horizons terrain. DH LODs carry their colour in gl_Color (no texture
// atlas lookup), so we only need the position (projected with DH's own
// projection) and the colour. The composite pass fogs the result.

out vec4 glcolor;
out float dist;

uniform mat4 dhProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

void main() {
    // Normalise the LOD vertex through player space (handles the LOD chunk
    // offsets), then project with DH's projection so the depth lands in
    // dhDepthTex0 under the correct projection.
    vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    dist = length(position.xyz);
    gl_Position = dhProjection * gbufferModelView * position;

    glcolor = gl_Color;
}
