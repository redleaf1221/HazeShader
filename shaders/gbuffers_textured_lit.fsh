#version 330 compatibility

uniform sampler2D gtexture;

uniform vec4 entityColor;
uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
    vec4 albedo = texture(gtexture, texcoord) * glcolor;
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);

    if (albedo.a < alphaTestRef) {
        discard;
    }

    color = albedo;
    // Alpha is forced to 1 so these buffers are written (not blended) even
    // for translucent geometry.
    lightmapData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}
