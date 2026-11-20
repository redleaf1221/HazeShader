#version 330 compatibility

uniform sampler2D gtexture;

uniform vec4 entityColor;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
    // Translucent terrain (water, glass, ice): never alpha-discard, keep the
    // alpha so the fixed-function blending stays intact.
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);

    color = albedo;
    lightmapData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}
